import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../layout/layout_engine.dart';
import '../layout/natural_layout_engine.dart';
import '../layout/scattered_layout_engine.dart';
import '../layout/uniform_layout_engine.dart';
import '../models/canvas_aspect_ratio.dart';
import '../models/collage_settings.dart';
import '../models/crop_transform.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import '../services/photo_picker_service.dart';
import '../services/sample_photos_service.dart';
import '../theme/apple_photos_theme.dart';
import 'apple_photos_crop_viewfinder.dart';
import 'apple_photos_dock.dart';
import 'apple_photos_shelf.dart';
import 'apple_photos_top_bar.dart';
import 'collage_preview.dart';
import 'empty_state_view.dart';
import 'export_dialog.dart';
import 'studio/desktop_inspector.dart';

/// The main application screen designed with the Apple Photos editing app UX.
class CollageScreen extends StatefulWidget {
  const CollageScreen({super.key});

  @override
  State<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends State<CollageScreen> {
  final PhotoPickerService _photoPicker = PhotoPickerService();

  final NaturalLayoutEngine _naturalEngine = const NaturalLayoutEngine();
  final UniformLayoutEngine _uniformEngine = const UniformLayoutEngine();
  final ScatteredLayoutEngine _scatteredEngine = const ScatteredLayoutEngine();

  List<PhotoAsset> _photos = [];
  CollageSettings _settings = const CollageSettings();
  LayoutResult? _layoutResult;
  bool _isLoading = false;

  // Undo and Redo History Stacks
  final List<CollageSettings> _undoStack = [];
  final List<CollageSettings> _redoStack = [];

  // Active Apple Photos bottom tool mode
  ApplePhotosTool _activeTool = ApplePhotosTool.layout;

  @override
  void dispose() {
    for (final p in _photos) {
      p.dispose();
    }
    _settings.backgroundImage?.dispose();
    _settings.borderImage?.dispose();
    super.dispose();
  }

  void _recalculateLayout() {
    if (_photos.isEmpty) {
      setState(() => _layoutResult = null);
      return;
    }

    final targetCanvasSize = CollageLayoutEngine.resolveCanvasSize(_settings, _photos);
    LayoutResult result;

    switch (_settings.layoutMode) {
      case CollageLayoutMode.natural:
        result = _naturalEngine.computeLayout(
          photos: _photos,
          settings: _settings,
          targetCanvasSize: targetCanvasSize,
        );
        break;
      case CollageLayoutMode.uniform:
        result = _uniformEngine.computeLayout(
          photos: _photos,
          settings: _settings,
          targetCanvasSize: targetCanvasSize,
        );
        break;
      case CollageLayoutMode.scattered:
        result = _scatteredEngine.computeLayout(
          photos: _photos,
          settings: _settings,
          targetCanvasSize: targetCanvasSize,
        );
        break;
    }

    setState(() {
      _layoutResult = result;
    });
  }

  /// Pushes the current settings onto the undo stack and applies [newSettings].
  void _updateSettings(CollageSettings newSettings) {
    if (newSettings == _settings) return;
    _undoStack.add(_settings);
    _redoStack.clear();
    setState(() {
      _settings = newSettings;
    });
    _recalculateLayout();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(_settings);
    setState(() {
      _settings = previous;
    });
    _recalculateLayout();
    HapticFeedback.selectionClick();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_settings);
    setState(() {
      _settings = next;
    });
    _recalculateLayout();
    HapticFeedback.selectionClick();
  }

  Future<void> _pickInitialPhotos({bool fromFiles = false}) async {
    setState(() => _isLoading = true);
    try {
      final selected = fromFiles
          ? await _photoPicker.pickPhotosFromFiles(onError: _showFormatError)
          : await _photoPicker.pickPhotosFromLibrary(onError: _showFormatError);
      if (selected.length < 2) {
        if (mounted && selected.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least 2 photos for a collage.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF2C2C2E),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _photos = selected;
        _isLoading = false;
        _undoStack.clear();
        _redoStack.clear();
      });

      _recalculateLayout();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photos: $e')),
        );
      }
    }
  }

  void _showFormatError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill, color: ApplePhotosTheme.appleGold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2E),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _loadSamplePhotos() async {
    setState(() => _isLoading = true);
    try {
      final samples = await SamplePhotosService.generateSamplePhotos();
      setState(() {
        _photos = samples;
        _isLoading = false;
        _undoStack.clear();
        _redoStack.clear();
      });
      _recalculateLayout();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMorePhotos() async {
    final more = await _photoPicker.showPhotoSourcePickerSheet(
      context,
      onError: _showFormatError,
    );
    if (more.isEmpty) return;

    setState(() {
      _photos.addAll(more);
    });

    _recalculateLayout();
  }

  void _removePhoto(String photoId) {
    if (_photos.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A collage requires at least 2 photos.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2C2C2E),
        ),
      );
      return;
    }

    final removed = _photos.firstWhere((p) => p.id == photoId, orElse: () => _photos.first);
    removed.dispose();

    setState(() {
      _photos.removeWhere((p) => p.id == photoId);
    });

    _recalculateLayout();
  }

  void _onLayoutModeChanged(CollageLayoutMode mode) {
    _updateSettings(
      _settings.copyWith(
        layoutMode: mode,
        clearUniformFrameAspectRatio: mode != CollageLayoutMode.uniform,
      ),
    );
  }

  void _onShuffle() {
    _updateSettings(_settings.nextShuffleSeed());
  }

  void _onCanvasRatioChanged(CanvasAspectRatio ratio) {
    _updateSettings(
      _settings.copyWith(
        canvasAspectRatio: ratio,
        clearUniformFrameAspectRatio: true,
      ),
    );
  }

  void _onCanvasOrientationChanged(CanvasOrientation orientation) {
    _updateSettings(
      _settings.copyWith(
        canvasAspectRatio: _settings.canvasAspectRatio.withOrientation(orientation),
        clearUniformFrameAspectRatio: true,
      ),
    );
  }

  void _onUniformRatioChanged(double? ratio) {
    _updateSettings(
      _settings.copyWith(
        uniformFrameAspectRatio: ratio,
        clearUniformFrameAspectRatio: ratio == null,
      ),
    );
  }

  void _onUniformOrientationChanged(CanvasOrientation orientation) {
    _updateSettings(
      _settings.copyWith(uniformFrameOrientation: orientation),
    );
  }

  void _onSpacingChanged(double spacing) {
    _updateSettings(
      _settings.copyWith(spacing: spacing, outerMargin: spacing),
    );
  }

  void _onMarginChanged(double margin) {
    _updateSettings(
      _settings.copyWith(outerMargin: margin),
    );
  }

  void _onBorderWidthChanged(double width) {
    _updateSettings(
      _settings.copyWith(borderWidth: width),
    );
  }

  void _onBorderColorChanged(Color color) {
    _updateSettings(
      _settings.copyWith(borderColor: color, clearBorderImage: true),
    );
  }

  Future<void> _onPickBorderImage() async {
    final borderPhoto = await _photoPicker.showBackgroundPhotoSourcePickerSheet(
      context,
      onError: _showFormatError,
    );
    if (borderPhoto != null) {
      _updateSettings(
        _settings.copyWith(
          borderImage: borderPhoto,
          borderWidth: _settings.borderWidth > 0 ? _settings.borderWidth : 12.0,
        ),
      );
    }
  }

  void _onRemoveBorderImage() {
    _updateSettings(
      _settings.copyWith(clearBorderImage: true),
    );
  }

  void _onBackgroundColorChanged(Color color) {
    _updateSettings(
      _settings.copyWith(backgroundColor: color, clearBackgroundImage: true),
    );
  }

  Future<void> _onPickBackgroundImage() async {
    final bgPhoto = await _photoPicker.showBackgroundPhotoSourcePickerSheet(
      context,
      onError: _showFormatError,
    );
    if (bgPhoto != null) {
      _updateSettings(
        _settings.copyWith(backgroundImage: bgPhoto),
      );
    }
  }

  void _onRemoveBackgroundImage() {
    _updateSettings(
      _settings.copyWith(clearBackgroundImage: true),
    );
  }

  void _onBackgroundBlurChanged(double blur) {
    _updateSettings(
      _settings.copyWith(backgroundBlur: blur),
    );
  }

  Future<void> _openCropViewfinder(PhotoAsset photo, CollageItemPlacement placement) async {
    final frameAspect = placement.rect.width / placement.rect.height;
    final CropTransform? updated = await Navigator.of(context).push<CropTransform>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ApplePhotosCropViewfinder(
          photo: photo,
          frameAspectRatio: frameAspect,
          initialCrop: placement.cropTransform,
        ),
      ),
    );

    if (updated != null) {
      _updateSettings(_settings.withCropTransform(photo.id, updated));
    }
  }

  void _openExportDialog() {
    if (_layoutResult == null || _photos.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ExportDialog(
        layoutResult: _layoutResult!,
        settings: _settings,
        photos: _photos,
      ),
    );
  }

  void _resetCollage() {
    for (final p in _photos) {
      p.dispose();
    }
    setState(() {
      _photos = [];
      _layoutResult = null;
      _settings = const CollageSettings();
      _undoStack.clear();
      _redoStack.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPhotos = _photos.isNotEmpty && _layoutResult != null;
    final photosMap = {for (var p in _photos) p.id: p};

    return Scaffold(
      backgroundColor: ApplePhotosTheme.obsidianBlack,
      body: SafeArea(
        child: hasPhotos
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 768;

                  if (isDesktop) {
                    // Desktop Layout (macOS & Web)
                    return Column(
                      children: [
                        // Top Bar with Undo / Redo
                        ApplePhotosTopBar(
                          settings: _settings,
                          photoCount: _photos.length,
                          canUndo: _undoStack.isNotEmpty,
                          canRedo: _redoStack.isNotEmpty,
                          onUndo: _undo,
                          onRedo: _redo,
                          onStartOver: _resetCollage,
                          onExport: _openExportDialog,
                          onTogglePhotosTool: () {
                            setState(() => _activeTool = ApplePhotosTool.photos);
                          },
                        ),
                        // Workspace with Right Inspector
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRect(
                                  child: CollagePreview(
                                    layoutResult: _layoutResult!,
                                    settings: _settings,
                                    photosById: photosMap,
                                    backgroundUiImage: _settings.backgroundImage?.previewImage,
                                    borderUiImage: _settings.borderImage?.previewImage,
                                    onPhotoTapped: (photo, placement) {
                                      _openCropViewfinder(photo, placement);
                                    },
                                  ),
                                ),
                              ),
                              DesktopInspector(
                                settings: _settings,
                                layoutResult: _layoutResult,
                                photos: _photos,
                                onLayoutModeChanged: _onLayoutModeChanged,
                                onCanvasRatioChanged: _onCanvasRatioChanged,
                                onCanvasOrientationChanged: _onCanvasOrientationChanged,
                                onUniformRatioChanged: _onUniformRatioChanged,
                                onUniformOrientationChanged: _onUniformOrientationChanged,
                                onSpacingChanged: _onSpacingChanged,
                                onMarginChanged: _onMarginChanged,
                                onBorderWidthChanged: _onBorderWidthChanged,
                                onBorderColorChanged: _onBorderColorChanged,
                                onPickBorderImage: _onPickBorderImage,
                                onRemoveBorderImage: _onRemoveBorderImage,
                                onBackgroundColorChanged: _onBackgroundColorChanged,
                                onPickBackgroundImage: _onPickBackgroundImage,
                                onRemoveBackgroundImage: _onRemoveBackgroundImage,
                                onBackgroundBlurChanged: _onBackgroundBlurChanged,
                                onAddPhotos: _addMorePhotos,
                                onRemovePhoto: _removePhoto,
                                onShuffle: _onShuffle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile Layout (iOS & Android)
                  return Column(
                    children: [
                      // 1. Apple Photos Top Bar with Undo / Redo
                      ApplePhotosTopBar(
                        settings: _settings,
                        photoCount: _photos.length,
                        canUndo: _undoStack.isNotEmpty,
                        canRedo: _redoStack.isNotEmpty,
                        onUndo: _undo,
                        onRedo: _redo,
                        onStartOver: _resetCollage,
                        onExport: _openExportDialog,
                        onTogglePhotosTool: () {
                          setState(() => _activeTool = ApplePhotosTool.photos);
                        },
                      ),

                      // 2. Floating Hero Canvas (Pinch-to-Zoom & Pan)
                      Expanded(
                        child: ClipRect(
                          child: CollagePreview(
                            layoutResult: _layoutResult!,
                            settings: _settings,
                            photosById: photosMap,
                            backgroundUiImage: _settings.backgroundImage?.previewImage,
                            borderUiImage: _settings.borderImage?.previewImage,
                            onPhotoTapped: (photo, placement) {
                              _openCropViewfinder(photo, placement);
                            },
                          ),
                        ),
                      ),

                      // 3. Apple Photos Inspector Shelf (Dynamic per tool)
                      ApplePhotosShelf(
                        activeTool: _activeTool,
                        settings: _settings,
                        layoutResult: _layoutResult,
                        photos: _photos,
                        onLayoutModeChanged: _onLayoutModeChanged,
                        onCanvasRatioChanged: _onCanvasRatioChanged,
                        onCanvasOrientationChanged: _onCanvasOrientationChanged,
                        onUniformRatioChanged: _onUniformRatioChanged,
                        onUniformOrientationChanged: _onUniformOrientationChanged,
                        onSpacingChanged: _onSpacingChanged,
                        onMarginChanged: _onMarginChanged,
                        onBorderWidthChanged: _onBorderWidthChanged,
                        onBorderColorChanged: _onBorderColorChanged,
                        onPickBorderImage: _onPickBorderImage,
                        onRemoveBorderImage: _onRemoveBorderImage,
                        onBackgroundColorChanged: _onBackgroundColorChanged,
                        onPickBackgroundImage: _onPickBackgroundImage,
                        onRemoveBackgroundImage: _onRemoveBackgroundImage,
                        onBackgroundBlurChanged: _onBackgroundBlurChanged,
                        onAddPhotos: _addMorePhotos,
                        onRemovePhoto: _removePhoto,
                      ),

                      // 4. Apple Photos Bottom Tool Dock with Shuffle
                      ApplePhotosDock(
                        activeTool: _activeTool,
                        onSelectTool: (tool) {
                          setState(() => _activeTool = tool);
                        },
                        onShuffle: _onShuffle,
                      ),
                    ],
                  );
                },
              )
            : EmptyStateView(
                onSelectPhotos: () => _pickInitialPhotos(fromFiles: false),
                onSelectFiles: () => _pickInitialPhotos(fromFiles: true),
                onTrySamplePhotos: _loadSamplePhotos,
                isLoading: _isLoading,
              ),
      ),
    );
  }
}

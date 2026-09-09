import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/collage_settings.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import '../rendering/export_renderer.dart';
import '../services/export_service.dart';
import '../theme/apple_photos_theme.dart';

/// Modal dialog that performs high-resolution rendering and provides authentic Apple export actions.
class ExportDialog extends StatefulWidget {
  final LayoutResult layoutResult;
  final CollageSettings settings;
  final List<PhotoAsset> photos;

  const ExportDialog({
    super.key,
    required this.layoutResult,
    required this.settings,
    required this.photos,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final ExportService _exportService = const ExportService();

  bool _isRendering = true;
  double _progress = 0.0;
  Uint8List? _renderedJpegBytes;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    try {
      final bytes = await ExportRenderer.renderToJpeg(
        layoutResult: widget.layoutResult,
        settings: widget.settings,
        photos: widget.photos,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) {
        setState(() {
          _renderedJpegBytes = bytes;
          _isRendering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRendering = false;
          _statusMessage = 'Rendering failed: $e';
        });
      }
    }
  }

  Future<void> _saveToPhotos() async {
    if (_renderedJpegBytes == null) return;
    setState(() => _statusMessage = 'Saving to Photos...');

    final success = await _exportService.saveToPhotoLibrary(_renderedJpegBytes!);
    if (mounted) {
      setState(() {
        _isSuccess = success;
        _statusMessage = success ? 'Saved to Photos' : 'Could not save. Please check permissions.';
      });
    }
  }

  Future<void> _saveToFiles() async {
    if (_renderedJpegBytes == null) return;
    setState(() => _statusMessage = 'Selecting destination...');

    final path = await _exportService.saveToFilePicker(_renderedJpegBytes!);
    if (mounted) {
      setState(() {
        if (path != null) {
          _isSuccess = true;
          final filename = path.split(RegExp(r'[\\/]')).last;
          _statusMessage = 'Saved: $filename';
        } else {
          _statusMessage = null;
        }
      });
    }
  }

  Future<void> _share() async {
    if (_renderedJpegBytes == null) return;
    await _exportService.shareImage(_renderedJpegBytes!);
  }

  void _downloadWeb() {
    if (_renderedJpegBytes == null) return;
    _exportService.downloadOnWeb(_renderedJpegBytes!);
    setState(() {
      _isSuccess = true;
      _statusMessage = 'Download started';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xE61C1C1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ApplePhotosTheme.specularBorder, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header with Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Export Collage',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.clear, color: Colors.white70, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ApplePhotosTheme.appleGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '4K ULTRA HD',
                      style: TextStyle(
                        color: ApplePhotosTheme.appleGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'High-Resolution JPEG (~4096px)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isRendering) ...[
                const SizedBox(height: 20),
                const CupertinoActivityIndicator(radius: 16, color: ApplePhotosTheme.appleGold),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(ApplePhotosTheme.appleGold),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Composing high-resolution collage (${(_progress * 100).round()}%)...',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 20),
              ] else if (_renderedJpegBytes != null) ...[
                // Rendered Preview Card
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ApplePhotosTheme.specularBorder, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(_renderedJpegBytes!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),

                if (_statusMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? ApplePhotosTheme.appleGreen.withValues(alpha: 0.15)
                          : ApplePhotosTheme.appleRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isSuccess
                            ? ApplePhotosTheme.appleGreen.withValues(alpha: 0.3)
                            : ApplePhotosTheme.appleRed.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isSuccess ? ApplePhotosTheme.appleGreen : ApplePhotosTheme.appleRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Action Buttons (Save to Photos, Share, Web Download)
                Row(
                  children: [
                    if (kIsWeb)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadWeb,
                          icon: const Icon(CupertinoIcons.arrow_down_circle_fill, size: 18, color: Colors.black),
                          label: const Text('Download Image'),
                          style: ApplePhotosTheme.goldPillStyle,
                        ),
                      )
                    else ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveToPhotos,
                          icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 16, color: Colors.black),
                          label: const Text('Save to Photos'),
                          style: ApplePhotosTheme.goldPillStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Save to Files',
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: _saveToFiles,
                          child: const Icon(CupertinoIcons.folder, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Share',
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: _share,
                          child: const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                Text(
                  _statusMessage ?? 'Export failed',
                  style: const TextStyle(color: ApplePhotosTheme.appleRed),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

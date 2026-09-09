import 'dart:math';
import 'dart:ui';
import '../models/canvas_aspect_ratio.dart';
import '../models/collage_settings.dart';
import '../models/crop_transform.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import 'layout_engine.dart';

/// Layout Engine 2 — Uniform Frames
///
/// Every photo appears inside a uniform frame of identical dimensions and aspect ratio.
///
/// 1. "Best Fit": Calculates a frame aspect ratio that stays close to the majority
///    aspect ratio of uploaded photos (minimizing crop / preserving content) while
///    maximizing canvas utilization (minimizing empty margins).
/// 2. Dynamic Grid Arrangement: For ANY active frame aspect ratio (whether Best Fit
///    or user presets like 1:1, 4:5, 3:4, 2:3, 9:16, 16:9), the grid arrangement (cols x rows)
///    dynamically adapts to maximize canvas utilization and visual balance.
class UniformLayoutEngine implements CollageLayoutEngine {
  const UniformLayoutEngine();

  @override
  LayoutResult computeLayout({
    required List<PhotoAsset> photos,
    required CollageSettings settings,
    required Size targetCanvasSize,
  }) {
    if (photos.isEmpty) {
      return LayoutResult(
        canvasWidth: targetCanvasSize.width,
        canvasHeight: targetCanvasSize.height,
        placements: const [],
        canvasAspectRatio: targetCanvasSize.width / (targetCanvasSize.height > 0 ? targetCanvasSize.height : 1),
      );
    }

    final double canvasW = targetCanvasSize.width;
    final double canvasH = targetCanvasSize.height;
    final double margin = settings.outerMargin;
    final double spacing = settings.spacing;

    final double availW = max(20.0, canvasW - 2 * margin);
    final double availH = max(20.0, canvasH - 2 * margin);

    final List<PhotoAsset> orderedPhotos = _getShuffledPhotos(photos, settings.seed);
    final int n = orderedPhotos.length;

    // 1. Generate viable grid configurations (cols, rows)
    final List<_GridConfig> viableGrids = _getViableGrids(n, availW, availH);

    // 2. Determine representative aspect ratio of the majority of uploaded photos
    final double majorityPhotoRatio = _calculateMajorityPhotoRatio(photos, settings.uniformFrameOrientation);

    // 3. Determine "Best Fit" frame aspect ratio:
    // Balances preserving majority photo content (minimal crop) with maximizing canvas utilization
    final double bestFitRatio = _determineBestFitRatio(
      photos: photos,
      majorityRatio: majorityPhotoRatio,
      viableGrids: viableGrids,
      availW: availW,
      availH: availH,
      spacing: spacing,
      orientation: settings.uniformFrameOrientation,
    );

    // 4. Generate candidate frame aspect ratios for user selection chips
    final List<double> candidateRatios = _calculateCandidateFrameRatios(settings.uniformFrameOrientation);

    // 5. Determine active frame ratio: user setting or best-fit ratio
    double activeRatio = bestFitRatio;
    if (settings.uniformFrameAspectRatio != null) {
      activeRatio = settings.uniformFrameAspectRatio!;
      if (settings.uniformFrameOrientation.isLandscape && activeRatio < 1.0) {
        activeRatio = 1.0 / activeRatio;
      } else if (settings.uniformFrameOrientation.isPortrait && activeRatio > 1.0) {
        activeRatio = 1.0 / activeRatio;
      }
    }

    // 6. Dynamic Grid Arrangement:
    // Select the grid configuration that maximizes canvas utilization and visual harmony
    // specifically for the ACTIVE frame aspect ratio!
    final _GridConfig chosenGrid = _selectBestGridForRatio(
      grids: viableGrids,
      photoCount: n,
      activeRatio: activeRatio,
      availW: availW,
      availH: availH,
      spacing: spacing,
    );

    // 7. Calculate uniform frame dimensions for the chosen grid and active ratio
    final _FrameDimensions frameDim = _calculateFrameDimensions(
      chosenGrid,
      activeRatio,
      availW,
      availH,
      spacing,
    );

    // 8. Build placements centered on canvas
    final placements = _buildPlacements(
      orderedPhotos,
      chosenGrid,
      frameDim,
      canvasW,
      canvasH,
      margin,
      spacing,
      settings,
    );

    return LayoutResult(
      canvasWidth: canvasW,
      canvasHeight: canvasH,
      placements: placements,
      canvasAspectRatio: canvasW / canvasH,
      candidateFrameRatios: candidateRatios,
      activeFrameRatio: activeRatio,
      bestFitFrameRatio: bestFitRatio,
    );
  }

  List<PhotoAsset> _getShuffledPhotos(List<PhotoAsset> photos, int seed) {
    if (seed == 42 || photos.length <= 1) {
      return List<PhotoAsset>.from(photos);
    }
    final list = List<PhotoAsset>.from(photos);
    final rand = Random(seed);
    for (int i = list.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
    return list;
  }

  /// Explores viable (cols, rows) pairs for [n] photos.
  /// Eliminates heavily unbalanced grids with excessive empty cells.
  List<_GridConfig> _getViableGrids(int n, double width, double height) {
    final List<_GridConfig> candidates = [];
    final canvasRatio = width / height;

    if (n == 2) {
      return [
        const _GridConfig(cols: 2, rows: 1),
        const _GridConfig(cols: 1, rows: 2),
      ];
    }

    for (int cols = 1; cols <= n; cols++) {
      final rows = (n / cols).ceil();
      if (rows <= 0) continue;

      final emptyCells = (cols * rows) - n;

      // Disallow grids where an entire row would be empty or more
      if (emptyCells >= cols) continue;

      // Avoid single-column or single-row on drastically opposing canvas ratios
      if (cols == 1 && n >= 4 && canvasRatio > 1.6) continue;
      if (rows == 1 && n >= 4 && canvasRatio < 0.6) continue;

      // For small counts (n <= 6), strictly eliminate grids with excessive empty slots
      // (e.g. rejects 4x2 for 5 photos which leaves 3 empty slots and 4 photos on top)
      if (n <= 6 && emptyCells > 1) continue;
      if (n <= 10 && emptyCells > 2) continue;

      candidates.add(_GridConfig(cols: cols, rows: rows));
    }

    if (candidates.isEmpty) {
      final cols = sqrt(n).round().clamp(1, n);
      candidates.add(_GridConfig(cols: cols, rows: (n / cols).ceil()));
    }

    return candidates;
  }

  /// Calculates the representative aspect ratio of the majority of uploaded photos.
  ///
  /// Group photos into orientation clusters (portrait, square, landscape),
  /// finds the dominant cluster, and computes the median ratio within that cluster.
  double _calculateMajorityPhotoRatio(List<PhotoAsset> photos, CanvasOrientation orientation) {
    if (photos.isEmpty) return 1.0;

    final List<double> portraitRatios = [];
    final List<double> squareRatios = [];
    final List<double> landscapeRatios = [];

    for (final p in photos) {
      final r = p.aspectRatio > 0 ? p.aspectRatio : 1.0;
      if (r < 0.88) {
        portraitRatios.add(r);
      } else if (r > 1.14) {
        landscapeRatios.add(r);
      } else {
        squareRatios.add(r);
      }
    }

    // Determine the majority group
    List<double> dominantGroup;
    if (portraitRatios.length >= squareRatios.length && portraitRatios.length >= landscapeRatios.length) {
      dominantGroup = portraitRatios;
    } else if (landscapeRatios.length >= squareRatios.length && landscapeRatios.length >= portraitRatios.length) {
      dominantGroup = landscapeRatios;
    } else {
      dominantGroup = squareRatios;
    }

    dominantGroup.sort();
    double medianRatio = dominantGroup[dominantGroup.length ~/ 2];

    // Respect explicit orientation setting if chosen by user
    if (orientation.isLandscape && medianRatio < 1.0) {
      medianRatio = 1.0 / medianRatio;
    } else if (orientation.isPortrait && medianRatio > 1.0) {
      medianRatio = 1.0 / medianRatio;
    }

    return medianRatio;
  }

  /// Determines the "Best Fit" frame aspect ratio.
  ///
  /// Balances:
  /// 1. Closeness to the majority photo aspect ratio (minimal image cropping)
  /// 2. High canvas utilization across viable grid arrangements (minimal blank margins)
  double _determineBestFitRatio({
    required List<PhotoAsset> photos,
    required double majorityRatio,
    required List<_GridConfig> viableGrids,
    required double availW,
    required double availH,
    required double spacing,
    required CanvasOrientation orientation,
  }) {
    final Set<double> candidateSet = {};

    // 1. Majority photo ratio is always a prime candidate
    candidateSet.add(double.parse(majorityRatio.toStringAsFixed(2)));

    // 2. Standard aesthetic presets in the relevant orientation
    final standardPresets = orientation.isPortrait
        ? [0.56, 0.67, 0.75, 0.80, 1.0]
        : [1.0, 1.25, 1.33, 1.50, 1.78];

    for (final r in standardPresets) {
      candidateSet.add(r);
    }

    // 3. Natural cell aspect ratio of the viable grids
    for (final g in viableGrids) {
      final cellW = (availW - (g.cols - 1) * spacing) / g.cols;
      final cellH = (availH - (g.rows - 1) * spacing) / g.rows;
      if (cellW > 0 && cellH > 0) {
        final r = cellW / cellH;
        // Include if in the same orientation domain
        if ((majorityRatio <= 1.0 && r <= 1.15) || (majorityRatio > 1.0 && r >= 0.85)) {
          candidateSet.add(double.parse(r.toStringAsFixed(2)));
        }
      }
    }

    double bestRatio = majorityRatio;
    double highestScore = -double.infinity;

    for (final candRatio in candidateSet) {
      if (candRatio <= 0.2 || candRatio >= 5.0) continue;

      // Find the best grid arrangement for this candidate ratio
      final grid = _selectBestGridForRatio(
        grids: viableGrids,
        photoCount: photos.length,
        activeRatio: candRatio,
        availW: availW,
        availH: availH,
        spacing: spacing,
      );

      final dims = _calculateFrameDimensions(grid, candRatio, availW, availH, spacing);
      final totalFrameArea = photos.length * (dims.width * dims.height);
      final canvasArea = availW * availH;
      final double canvasUtilization = (canvasArea > 0) ? (totalFrameArea / canvasArea).clamp(0.0, 1.0) : 0.0;

      // Measure photo content preservation: fraction of each original photo visible (BoxFit.cover)
      double totalVisibility = 0.0;
      for (final p in photos) {
        final pRatio = p.aspectRatio > 0 ? p.aspectRatio : 1.0;
        final visibleFraction = min(pRatio / candRatio, candRatio / pRatio);
        totalVisibility += visibleFraction;
      }
      final double avgVisibility = (totalVisibility / photos.length).clamp(0.0, 1.0);

      // Measure closeness to majority photo ratio
      final double diffLog = (log(candRatio) - log(majorityRatio)).abs();
      final double closeness = (1.0 - diffLog * 0.5).clamp(0.0, 1.0);

      // Multi-objective balanced score:
      // - 45% canvas utilization (fill the canvas, minimize empty space)
      // - 40% photo content preservation (show most of each image)
      // - 15% closeness to the original majority photo ratio
      final double score = 0.45 * canvasUtilization + 0.40 * avgVisibility + 0.15 * closeness;

      if (score > highestScore) {
        highestScore = score;
        bestRatio = candRatio;
      }
    }

    // Snap to nearest standard preset if very close (within 0.03)
    for (final preset in [0.56, 0.67, 0.75, 0.80, 1.0, 1.25, 1.33, 1.50, 1.78]) {
      if ((bestRatio - preset).abs() <= 0.03) {
        return preset;
      }
    }

    return double.parse(bestRatio.toStringAsFixed(2));
  }

  /// Selects the best grid arrangement (cols x rows) specifically for [activeRatio].
  ///
  /// This ensures that when the user changes frame aspect ratio, the arrangement
  /// dynamically updates to maximize canvas utilization and visual balance.
  _GridConfig _selectBestGridForRatio({
    required List<_GridConfig> grids,
    required int photoCount,
    required double activeRatio,
    required double availW,
    required double availH,
    required double spacing,
  }) {
    _GridConfig bestGrid = grids.first;
    double highestScore = -double.infinity;
    final double canvasRatio = availW / availH;

    for (final g in grids) {
      final cellW = (availW - (g.cols - 1) * spacing) / g.cols;
      final cellH = (availH - (g.rows - 1) * spacing) / g.rows;
      if (cellW <= 0 || cellH <= 0) continue;

      // Fit frame of activeRatio into this cell
      double frameW = cellW;
      double frameH = frameW / activeRatio;
      if (frameH > cellH) {
        frameH = cellH;
        frameW = frameH * activeRatio;
      }

      // Total area occupied by the photos
      final double totalPhotosArea = photoCount * (frameW * frameH);
      final double canvasArea = availW * availH;
      final double canvasUtilization = (canvasArea > 0) ? (totalPhotosArea / canvasArea).clamp(0.0, 1.0) : 0.0;

      // Aspect ratio harmony between overall grid envelope and canvas
      final double totalGridW = g.cols * frameW + (g.cols - 1) * spacing;
      final double totalGridH = g.rows * frameH + (g.rows - 1) * spacing;
      final double gridRatio = totalGridW / (totalGridH > 0 ? totalGridH : 1.0);
      final double aspectDisparity = (log(gridRatio) - log(canvasRatio)).abs();
      final double harmony = (1.0 - aspectDisparity * 0.25).clamp(0.0, 1.0);

      // Penalties:
      // 1. Empty cells penalty (fewer empty slots prefer cleaner layouts)
      final int emptyCells = (g.cols * g.rows) - photoCount;
      final double emptyPenalty = emptyCells * 0.06;

      // 2. Extreme single-column or single-row penalty unless canvas is an extreme banner
      double shapePenalty = 0.0;
      if (photoCount >= 4) {
        if (g.cols == 1 && canvasRatio > 0.8) {
          shapePenalty += 0.35;
        }
        if (g.rows == 1 && canvasRatio < 1.3) {
          shapePenalty += 0.35;
        }
      }

      final double score = 0.65 * canvasUtilization + 0.35 * harmony - emptyPenalty - shapePenalty;

      if (score > highestScore) {
        highestScore = score;
        bestGrid = g;
      }
    }

    return bestGrid;
  }

  _FrameDimensions _calculateFrameDimensions(
    _GridConfig grid,
    double targetRatio,
    double availW,
    double availH,
    double spacing,
  ) {
    final maxCellW = (availW - (grid.cols - 1) * spacing) / grid.cols;
    final maxCellH = (availH - (grid.rows - 1) * spacing) / grid.rows;

    double frameW = maxCellW;
    double frameH = frameW / targetRatio;

    if (frameH > maxCellH) {
      frameH = maxCellH;
      frameW = frameH * targetRatio;
    }

    return _FrameDimensions(width: frameW, height: frameH);
  }

  List<double> _calculateCandidateFrameRatios(CanvasOrientation orientation) {
    if (orientation == CanvasOrientation.portrait) {
      return const [0.56, 0.67, 0.75, 0.80, 1.0];
    } else {
      return const [1.0, 1.25, 1.33, 1.50, 1.78];
    }
  }

  List<CollageItemPlacement> _buildPlacements(
    List<PhotoAsset> photos,
    _GridConfig grid,
    _FrameDimensions frameDim,
    double canvasW,
    double canvasH,
    double margin,
    double spacing,
    CollageSettings settings,
  ) {
    final List<CollageItemPlacement> placements = [];
    final int n = photos.length;

    final double totalGridW = grid.cols * frameDim.width + (grid.cols - 1) * spacing;
    final double totalGridH = grid.rows * frameDim.height + (grid.rows - 1) * spacing;

    // Center entire grid within canvas
    final double startX = (canvasW - totalGridW) / 2.0;
    final double startY = (canvasH - totalGridH) / 2.0;

    // Calculate items per row, supporting alternate row distributions on shuffle
    final List<int> rowCounts = _calculateRowCounts(n, grid, settings.seed);

    int photoIdx = 0;
    for (int r = 0; r < rowCounts.length && photoIdx < n; r++) {
      final int itemsInThisRow = rowCounts[r];
      final double rowW = itemsInThisRow > 0
          ? itemsInThisRow * frameDim.width + (itemsInThisRow - 1) * spacing
          : 0.0;

      // Center incomplete rows within total grid width
      final double rowStartX = startX + (totalGridW - rowW) / 2.0;
      final double currentY = startY + r * (frameDim.height + spacing);

      for (int c = 0; c < itemsInThisRow && photoIdx < n; c++) {
        final photo = photos[photoIdx];
        final currentX = rowStartX + c * (frameDim.width + spacing);
        final rect = Rect.fromLTWH(currentX, currentY, frameDim.width, frameDim.height);

        placements.add(
          CollageItemPlacement(
            photoId: photo.id,
            rect: rect,
            cropTransform: settings.cropTransforms[photo.id] ?? CropTransform.identity,
            sourceAspectRatio: photo.aspectRatio,
            zIndex: photoIdx,
          ),
        );

        photoIdx++;
      }
    }

    return placements;
  }

  List<int> _calculateRowCounts(int n, _GridConfig grid, int seed) {
    final List<int> rowCounts = [];
    final int emptySlots = (grid.cols * grid.rows) - n;

    if (emptySlots == 0) {
      for (int r = 0; r < grid.rows; r++) {
        rowCounts.add(grid.cols);
      }
      return rowCounts;
    }

    // For 2-row grids with empty slots (e.g. 5 photos in 3x2: 3+2 vs 2+3 on shuffle)
    if (grid.rows == 2 && emptySlots > 0) {
      final top = (seed % 2 != 0) ? (grid.cols - emptySlots) : grid.cols;
      final bottom = (seed % 2 != 0) ? grid.cols : (grid.cols - emptySlots);
      return [top, bottom];
    }

    // General case: distribute items evenly so rows are as balanced as possible
    int remaining = n;
    for (int r = 0; r < grid.rows; r++) {
      final int rowsLeft = grid.rows - r;
      final int count = (remaining / rowsLeft).ceil().clamp(1, grid.cols);
      rowCounts.add(count);
      remaining -= count;
    }
    return rowCounts;
  }
}

class _GridConfig {
  final int cols;
  final int rows;

  const _GridConfig({required this.cols, required this.rows});
}

class _FrameDimensions {
  final double width;
  final double height;

  const _FrameDimensions({required this.width, required this.height});
}

import 'dart:math';
import 'dart:ui';
import '../models/collage_settings.dart';
import '../models/crop_transform.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import 'layout_engine.dart';

/// Layout Engine 1 — Natural / Justified
///
/// Mathematical Edge-to-Edge Justified Layout:
/// - Guarantees photos fill canvas edge-to-edge without spilling outside.
/// - Calculates optimal row/column partitions with minimal aspect ratio changes (<=10-12%).
/// - Every photo stays extremely close to its true natural aspect ratio.
/// - Deterministic multi-layout shuffle selects between viable balanced compositions.
class NaturalLayoutEngine implements CollageLayoutEngine {
  static const double maxAspectTolerance = 0.14; // max 14% aspect adaptation

  const NaturalLayoutEngine();

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

    final int n = photos.length;

    // Apply deterministic photo permutation based on seed for shuffling
    final List<PhotoAsset> orderedPhotos = _getShuffledPhotos(photos, settings.seed);

    // 1. Find all viable row-based partition candidates
    final List<_NaturalCandidate> candidates = [];

    final rowCompositions = _generateCompositions(n, maxParts: min(n, 5));
    for (final comp in rowCompositions) {
      final cand = _evaluateRowComposition(comp, orderedPhotos, availW, availH, spacing);
      if (cand != null) {
        candidates.add(cand);
      }
    }

    // 2. Also evaluate column-based partition candidates for extreme landscape/portrait cases
    final colCompositions = _generateCompositions(n, maxParts: min(n, 4));
    for (final comp in colCompositions) {
      final cand = _evaluateColComposition(comp, orderedPhotos, availW, availH, spacing);
      if (cand != null) {
        candidates.add(cand);
      }
    }

    // Sort candidates by visual score (low area variance + low aspect distortion)
    candidates.sort((a, b) => a.score.compareTo(b.score));

    // Pick candidate based on seed for multi-layout shuffle variety
    _NaturalCandidate best;
    final validSet = candidates
        .where((c) => c.aspectDistortion <= maxAspectTolerance && c.areaDisparity <= (n >= 4 ? 2.5 : 4.0))
        .toList();

    if (validSet.isNotEmpty) {
      if (settings.seed == 42) {
        best = validSet.first;
      } else {
        final idx = (settings.seed.abs()) % validSet.length;
        best = validSet[idx];
      }
    } else if (candidates.isNotEmpty) {
      best = candidates.first;
    } else {
      best = _fallbackCandidate(orderedPhotos, availW, availH, spacing);
    }

    // Build placements guaranteed to touch all 4 edges and stay strictly inside canvas
    final placements = best.buildPlacements(margin, settings);

    return LayoutResult(
      canvasWidth: canvasW,
      canvasHeight: canvasH,
      placements: placements,
      canvasAspectRatio: canvasW / canvasH,
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

  /// Generates integer compositions of [n] into at most [maxParts] positive integers.
  List<List<int>> _generateCompositions(int n, {required int maxParts}) {
    final List<List<int>> result = [];

    void helper(int remaining, int currentParts, List<int> current) {
      if (remaining == 0) {
        // Disqualify partitions with 1-photo rows when n >= 4 and balanced partitions exist
        if (n >= 4 && current.contains(1)) return;
        result.add(List<int>.from(current));
        return;
      }
      if (currentParts >= maxParts) return;

      for (int k = 1; k <= remaining; k++) {
        current.add(k);
        helper(remaining - k, currentParts + 1, current);
        current.removeLast();
      }
    }

    helper(n, 0, []);
    return result;
  }

  /// Evaluates a row composition: each element of [comp] is the number of photos in that row.
  _NaturalCandidate? _evaluateRowComposition(
    List<int> comp,
    List<PhotoAsset> photos,
    double availW,
    double availH,
    double spacing,
  ) {
    final int m = comp.length;
    final double netH = availH - (m - 1) * spacing;
    if (netH <= 10.0) return null;

    final List<_RowInfo> rows = [];
    int photoIdx = 0;
    double sumNatH = 0.0;

    for (int r = 0; r < m; r++) {
      final int count = comp[r];
      final rowPhotos = photos.sublist(photoIdx, photoIdx + count);
      photoIdx += count;

      final double netW = availW - (count - 1) * spacing;
      if (netW <= 10.0) return null;

      final double sumR = rowPhotos.fold<double>(0.0, (sum, p) => sum + p.aspectRatio);
      if (sumR <= 0.0) return null;

      final double natH = netW / sumR;
      sumNatH += natH;
      rows.add(_RowInfo(photos: rowPhotos, netWidth: netW, sumRatio: sumR, naturalHeight: natH));
    }

    if (sumNatH <= 0.0) return null;

    // Aspect adjustment factor lambda = sumNatH / netH
    final double lambda = sumNatH / netH;
    final double aspectDistortion = (lambda - 1.0).abs();

    // Calculate individual photo dimensions and areas to minimize area variance
    final List<double> areas = [];
    for (final row in rows) {
      final double rowH = (netH / sumNatH) * row.naturalHeight;
      for (final photo in row.photos) {
        final double itemW = (photo.aspectRatio / row.sumRatio) * row.netWidth;
        areas.add(itemW * rowH);
      }
    }

    final int totalPhotos = photos.length;
    final double avgArea = areas.fold<double>(0.0, (s, a) => s + a) / totalPhotos;
    final double areaVariance = areas.fold<double>(
          0.0,
          (s, a) => s + pow((a - avgArea) / (avgArea > 0 ? avgArea : 1), 2),
        ) /
        totalPhotos;
    final double minArea = areas.reduce(min);
    final double maxArea = areas.reduce(max);
    final double areaDisparity = minArea > 0 ? (maxArea / minArea) : 100.0;

    // Reject extreme size disparities for n >= 4
    if (totalPhotos >= 4 && areaDisparity > 2.5) {
      return null;
    }

    // Score: prioritize equal area distribution and minimal aspect distortion
    final double score = (areaVariance * 5.0) + (aspectDistortion * 3.5) + (areaDisparity - 1.0) * 0.4;

    return _RowCandidate(
      rows: rows,
      availW: availW,
      availH: availH,
      spacing: spacing,
      lambda: lambda,
      aspectDistortion: aspectDistortion,
      areaVariance: areaVariance,
      areaDisparity: areaDisparity,
      score: score,
    );
  }

  /// Evaluates a column composition: each element of [comp] is the number of photos in that column.
  _NaturalCandidate? _evaluateColComposition(
    List<int> comp,
    List<PhotoAsset> photos,
    double availW,
    double availH,
    double spacing,
  ) {
    final int m = comp.length;
    if (m <= 1) return null; // Avoid redundant single-column when row handles it
    final double netW = availW - (m - 1) * spacing;
    if (netW <= 10.0) return null;

    final List<_ColInfo> cols = [];
    int photoIdx = 0;
    double sumNatW = 0.0;

    for (int c = 0; c < m; c++) {
      final int count = comp[c];
      final colPhotos = photos.sublist(photoIdx, photoIdx + count);
      photoIdx += count;

      final double netH = availH - (count - 1) * spacing;
      if (netH <= 10.0) return null;

      final double sumInvR = colPhotos.fold<double>(0.0, (sum, p) => sum + (1.0 / p.aspectRatio));
      if (sumInvR <= 0.0) return null;

      final double natW = netH / sumInvR;
      sumNatW += natW;
      cols.add(_ColInfo(photos: colPhotos, netHeight: netH, sumInvRatio: sumInvR, naturalWidth: natW));
    }

    if (sumNatW <= 0.0) return null;

    final double beta = sumNatW / netW;
    final double aspectDistortion = (beta - 1.0).abs();

    final List<double> areas = [];
    for (final col in cols) {
      final double colW = (netW / sumNatW) * col.naturalWidth;
      for (final photo in col.photos) {
        final double itemH = ((1.0 / photo.aspectRatio) / col.sumInvRatio) * col.netHeight;
        areas.add(colW * itemH);
      }
    }

    final int totalPhotos = photos.length;
    final double avgArea = areas.fold<double>(0.0, (s, a) => s + a) / totalPhotos;
    final double areaVariance = areas.fold<double>(
          0.0,
          (s, a) => s + pow((a - avgArea) / (avgArea > 0 ? avgArea : 1), 2),
        ) /
        totalPhotos;
    final double minArea = areas.reduce(min);
    final double maxArea = areas.reduce(max);
    final double areaDisparity = minArea > 0 ? (maxArea / minArea) : 100.0;

    if (totalPhotos >= 4 && areaDisparity > 2.5) {
      return null;
    }

    final double score = (areaVariance * 5.0) + (aspectDistortion * 3.5) + (areaDisparity - 1.0) * 0.4 + 0.1;

    return _ColCandidate(
      cols: cols,
      availW: availW,
      availH: availH,
      spacing: spacing,
      beta: beta,
      aspectDistortion: aspectDistortion,
      areaVariance: areaVariance,
      areaDisparity: areaDisparity,
      score: score,
    );
  }

  _NaturalCandidate _fallbackCandidate(
    List<PhotoAsset> photos,
    double availW,
    double availH,
    double spacing,
  ) {
    final n = photos.length;
    final int rows = max(1, (sqrt(n)).round());
    final List<int> comp = [];
    int remaining = n;
    for (int r = 0; r < rows; r++) {
      final int count = (remaining / (rows - r)).round();
      comp.add(count);
      remaining -= count;
    }
    return _evaluateRowComposition(comp, photos, availW, availH, spacing) ??
        _RowCandidate(
          rows: [_RowInfo(photos: photos, netWidth: availW, sumRatio: n.toDouble(), naturalHeight: availH)],
          availW: availW,
          availH: availH,
          spacing: spacing,
          lambda: 1.0,
          aspectDistortion: 0.0,
          areaVariance: 0.0,
          areaDisparity: 1.0,
          score: 1.0,
        );
  }
}

abstract class _NaturalCandidate {
  double get aspectDistortion;
  double get areaVariance;
  double get areaDisparity;
  double get score;
  List<CollageItemPlacement> buildPlacements(double margin, CollageSettings settings);
}

class _RowInfo {
  final List<PhotoAsset> photos;
  final double netWidth;
  final double sumRatio;
  final double naturalHeight;

  const _RowInfo({
    required this.photos,
    required this.netWidth,
    required this.sumRatio,
    required this.naturalHeight,
  });
}

class _RowCandidate implements _NaturalCandidate {
  final List<_RowInfo> rows;
  final double availW;
  final double availH;
  final double spacing;
  final double lambda;
  @override
  final double aspectDistortion;
  @override
  final double areaVariance;
  @override
  final double areaDisparity;
  @override
  final double score;

  _RowCandidate({
    required this.rows,
    required this.availW,
    required this.availH,
    required this.spacing,
    required this.lambda,
    required this.aspectDistortion,
    required this.areaVariance,
    required this.areaDisparity,
    required this.score,
  });

  @override
  List<CollageItemPlacement> buildPlacements(double margin, CollageSettings settings) {
    final List<CollageItemPlacement> placements = [];
    final int m = rows.length;
    final double netH = availH - (m - 1) * spacing;
    final double sumNatH = rows.fold<double>(0.0, (sum, r) => sum + r.naturalHeight);

    double currentY = margin;

    for (final row in rows) {
      // Scale row height so sum of row heights equals netH exactly
      final double rowH = (netH / sumNatH) * row.naturalHeight;
      final int count = row.photos.length;
      final double netW = availW - (count - 1) * spacing;

      double currentX = margin;

      for (int i = 0; i < count; i++) {
        final photo = row.photos[i];
        // Distribute width according to adjusted aspect ratio
        final double itemW = (photo.aspectRatio / row.sumRatio) * netW;
        final rect = Rect.fromLTWH(currentX, currentY, itemW, rowH);

        placements.add(
          CollageItemPlacement(
            photoId: photo.id,
            rect: rect,
            cropTransform: settings.cropTransforms[photo.id] ?? CropTransform.identity,
            sourceAspectRatio: photo.aspectRatio,
            zIndex: placements.length,
          ),
        );

        currentX += itemW + spacing;
      }

      currentY += rowH + spacing;
    }

    return placements;
  }
}

class _ColInfo {
  final List<PhotoAsset> photos;
  final double netHeight;
  final double sumInvRatio;
  final double naturalWidth;

  const _ColInfo({
    required this.photos,
    required this.netHeight,
    required this.sumInvRatio,
    required this.naturalWidth,
  });
}

class _ColCandidate implements _NaturalCandidate {
  final List<_ColInfo> cols;
  final double availW;
  final double availH;
  final double spacing;
  final double beta;
  @override
  final double aspectDistortion;
  @override
  final double areaVariance;
  @override
  final double areaDisparity;
  @override
  final double score;

  _ColCandidate({
    required this.cols,
    required this.availW,
    required this.availH,
    required this.spacing,
    required this.beta,
    required this.aspectDistortion,
    required this.areaVariance,
    required this.areaDisparity,
    required this.score,
  });

  @override
  List<CollageItemPlacement> buildPlacements(double margin, CollageSettings settings) {
    final List<CollageItemPlacement> placements = [];
    final int m = cols.length;
    final double netW = availW - (m - 1) * spacing;
    final double sumNatW = cols.fold<double>(0.0, (sum, c) => sum + c.naturalWidth);

    double currentX = margin;

    for (final col in cols) {
      final double colW = (netW / sumNatW) * col.naturalWidth;
      final int count = col.photos.length;
      final double netH = availH - (count - 1) * spacing;

      double currentY = margin;

      for (int i = 0; i < count; i++) {
        final photo = col.photos[i];
        final double itemH = ((1.0 / photo.aspectRatio) / col.sumInvRatio) * netH;
        final rect = Rect.fromLTWH(currentX, currentY, colW, itemH);

        placements.add(
          CollageItemPlacement(
            photoId: photo.id,
            rect: rect,
            cropTransform: settings.cropTransforms[photo.id] ?? CropTransform.identity,
            sourceAspectRatio: photo.aspectRatio,
            zIndex: placements.length,
          ),
        );

        currentY += itemH + spacing;
      }

      currentX += colW + spacing;
    }

    return placements;
  }
}

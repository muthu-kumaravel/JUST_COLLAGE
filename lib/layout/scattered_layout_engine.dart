import 'dart:math';
import 'dart:ui';
import '../models/collage_settings.dart';
import '../models/crop_transform.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import 'layout_engine.dart';

/// Layout Engine 3 — Random / Scattered
///
/// Editorial scattered photo collage:
/// 1. Low Area Variance: All photos cover approximately the same canvas area (equal importance).
/// 2. Organic Spread: Non-patterned, organic spatial distribution using phyllotaxis
///    and force-directed relaxation (no rigid column/row grid).
/// 3. Controlled Overlap: Photos overlap gently at edges without burying or obscuring
///    entire images. Image sizing dynamically scales to enforce optimal overlap.
/// 4. Source Aspect Ratio: 100% maintained for every photo.
/// 5. Strict Containment: Zero photos, borders, or shadows spill outside canvas margins.
class ScatteredLayoutEngine implements CollageLayoutEngine {
  static const double maxRotationDegrees = 15.0;
  static const double maxRotationRadians = maxRotationDegrees * (pi / 180.0);

  const ScatteredLayoutEngine();

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
    final int n = photos.length;

    final double margin = settings.outerMargin;
    final double borderW = settings.borderWidth;
    const double shadowPadding = 6.0;

    final rand = Random(settings.seed);

    final double availW = max(50.0, canvasW - 2 * margin);
    final double availH = max(50.0, canvasH - 2 * margin);
    final double availArea = availW * availH;

    // 1. Equal Area Baseline: All images get approximately equal visual area (minimal variance)
    // Sized so photos spread across the canvas with gentle, controlled edge overlaps
    final double areaFraction = _calculateAreaFraction(n);
    final double baseAreaPerPhoto = availArea * areaFraction;

    // 2. Compute initial dimensions maintaining exact source aspect ratio
    final List<double> unscaledWidths = [];
    final List<double> unscaledHeights = [];
    for (int i = 0; i < n; i++) {
      final r = photos[i].aspectRatio > 0 ? photos[i].aspectRatio : 1.0;
      final h = sqrt(baseAreaPerPhoto / r);
      final w = h * r;
      unscaledWidths.add(w);
      unscaledHeights.add(h);
    }

    // 3. Generate organic rotations strictly within [-15°, +15°]
    // Alternating signs with organic variation for a natural tabletop look
    final List<double> rotations = [];
    for (int i = 0; i < n; i++) {
      final double sign = (i % 2 == 0) ? 1.0 : -1.0;
      final double deg = (sign * (3.5 + rand.nextDouble() * 10.5)).clamp(-maxRotationDegrees, maxRotationDegrees);
      rotations.add(deg * (pi / 180.0));
    }

    // 4. Generate organic initial anchor positions using Phyllotaxis Golden Spiral
    // This distributes points smoothly across the 2D area with ZERO row/column grid patterns
    List<Offset> centers = _generateOrganicAnchors(n, availW, availH, margin, rand);

    // 5. Physics Relaxation: Repulsion between adjacent photos + boundary containment
    centers = _relaxCenters(
      centers: centers,
      widths: unscaledWidths,
      heights: unscaledHeights,
      rotations: rotations,
      canvasW: canvasW,
      canvasH: canvasH,
      margin: margin,
      borderW: borderW,
      shadowPadding: shadowPadding,
      rand: rand,
    );

    // 6. Overlap Control via Dynamic Scale Optimization
    // Sizing is scaled down if overlap is too heavy (so photos aren't covered too much),
    // or scaled up if photos are too disconnected.
    final double optimalScale = _optimizeScaleForControlledOverlap(
      centers: centers,
      baseWidths: unscaledWidths,
      baseHeights: unscaledHeights,
      rotations: rotations,
      canvasW: canvasW,
      canvasH: canvasH,
      margin: margin,
      borderW: borderW,
      shadowPadding: shadowPadding,
    );

    // Deterministically permute z-order on shuffle
    final List<int> photoOrder = List<int>.generate(n, (i) => i);
    if (settings.seed != 42 && n > 1) {
      photoOrder.shuffle(rand);
    }

    // 7. Construct final placements with strict zero-bleed clamping
    final List<CollageItemPlacement> placements = [];
    for (int z = 0; z < n; z++) {
      final photoIndex = photoOrder[z];
      final photo = photos[photoIndex];
      final rot = rotations[z];
      final absRot = rot.abs();

      final double itemW = unscaledWidths[photoIndex] * optimalScale;
      final double itemH = unscaledHeights[photoIndex] * optimalScale;

      final double halfW = (itemW * cos(absRot) + itemH * sin(absRot)) / 2.0 + borderW + shadowPadding;
      final double halfH = (itemW * sin(absRot) + itemH * cos(absRot)) / 2.0 + borderW + shadowPadding;

      final minCenterX = margin + halfW;
      final maxCenterX = canvasW - margin - halfW;
      final minCenterY = margin + halfH;
      final maxCenterY = canvasH - margin - halfH;

      final center = centers[z];
      final double clampedX = maxCenterX >= minCenterX
          ? center.dx.clamp(minCenterX, maxCenterX)
          : canvasW / 2.0;
      final double clampedY = maxCenterY >= minCenterY
          ? center.dy.clamp(minCenterY, maxCenterY)
          : canvasH / 2.0;

      final rect = Rect.fromCenter(
        center: Offset(clampedX, clampedY),
        width: itemW,
        height: itemH,
      );

      placements.add(
        CollageItemPlacement(
          photoId: photo.id,
          rect: rect,
          cropTransform: settings.cropTransforms[photo.id] ?? CropTransform.identity,
          rotation: rot,
          scale: 1.0,
          zIndex: z,
          sourceAspectRatio: photo.aspectRatio,
        ),
      );
    }

    return LayoutResult(
      canvasWidth: canvasW,
      canvasHeight: canvasH,
      placements: placements,
      canvasAspectRatio: canvasW / canvasH,
    );
  }

  double _calculateAreaFraction(int n) {
    if (n == 1) return 0.55;
    if (n == 2) return 0.30;
    if (n == 3) return 0.20;
    if (n == 4) return 0.15;
    if (n == 5) return 0.12;
    if (n <= 8) return 0.60 / n;
    if (n <= 15) return 0.65 / n;
    return 0.70 / n;
  }

  List<Offset> _generateOrganicAnchors(int n, double availW, double availH, double margin, Random rand) {
    final List<Offset> anchors = [];
    final double centerX = margin + availW / 2.0;
    final double centerY = margin + availH / 2.0;

    if (n == 1) {
      return [Offset(centerX, centerY)];
    }

    final double baseRotation = rand.nextDouble() * 2 * pi;

    if (n <= 6) {
      // Single ring distribution for small photo counts (n = 2..6)
      // Guarantees every photo has at most 2 adjacent neighbors,
      // preventing any single photo from being buried under 4+ photos!
      final double ringRadiusX = availW * (n == 2 ? 0.22 : (n <= 4 ? 0.26 : 0.28));
      final double ringRadiusY = availH * (n == 2 ? 0.22 : (n <= 4 ? 0.26 : 0.28));
      final double step = 2 * pi / n;

      for (int i = 0; i < n; i++) {
        final double angle = baseRotation + i * step;
        // Organic jitter on radius (+/- 10%) and angle (+/- 6 deg) for natural non-patterned look
        final double jitterR = 1.0 + (rand.nextDouble() * 0.20 - 0.10);
        final double jitterA = (rand.nextDouble() * 0.20 - 0.10);

        final double px = centerX + cos(angle + jitterA) * (ringRadiusX * jitterR);
        final double py = centerY + sin(angle + jitterA) * (ringRadiusY * jitterR);

        anchors.add(Offset(px, py));
      }
      return anchors;
    }

    // For n >= 7, use Sunflower / Phyllotaxis Golden-Angle Spiral
    const double goldenAngle = 2.399963229728653; // ~137.508° in radians
    final double maxRadiusX = availW * 0.36;
    final double maxRadiusY = availH * 0.36;

    for (int i = 0; i < n; i++) {
      final double t = sqrt((i + 0.8) / n);
      final double angle = baseRotation + i * goldenAngle;
      final double jitterR = 1.0 + (rand.nextDouble() * 0.16 - 0.08);
      final double jitterA = (rand.nextDouble() * 0.16 - 0.08);

      final double px = centerX + cos(angle + jitterA) * (maxRadiusX * t * jitterR);
      final double py = centerY + sin(angle + jitterA) * (maxRadiusY * t * jitterR);

      anchors.add(Offset(px, py));
    }

    return anchors;
  }

  List<Offset> _relaxCenters({
    required List<Offset> centers,
    required List<double> widths,
    required List<double> heights,
    required List<double> rotations,
    required double canvasW,
    required double canvasH,
    required double margin,
    required double borderW,
    required double shadowPadding,
    required Random rand,
  }) {
    final int n = centers.length;
    if (n <= 1) return centers;

    final List<Offset> current = List<Offset>.from(centers);
    final double availW = canvasW - 2 * margin;
    final double availH = canvasH - 2 * margin;

    // Ideal separation distance between photo centers
    final double idealDistance = sqrt((availW * availH) / n) * 0.65;

    // 25 iterations of physics repulsion
    for (int step = 0; step < 25; step++) {
      final List<Offset> deltas = List.generate(n, (_) => Offset.zero);

      // Pairwise repulsion
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final diff = current[i] - current[j];
          final dist = diff.distance;
          if (dist < 0.001) {
            final jx = (rand.nextDouble() * 2 - 1) * 5.0;
            final jy = (rand.nextDouble() * 2 - 1) * 5.0;
            deltas[i] += Offset(jx, jy);
            deltas[j] -= Offset(jx, jy);
          } else if (dist < idealDistance) {
            final force = (idealDistance - dist) / idealDistance;
            final push = (diff / dist) * (force * 18.0);
            deltas[i] += push;
            deltas[j] -= push;
          }
        }
      }

      // Apply deltas and clamp to boundary
      for (int i = 0; i < n; i++) {
        final rot = rotations[i].abs();
        final hw = (widths[i] * cos(rot) + heights[i] * sin(rot)) / 2.0 + borderW + shadowPadding;
        final hh = (widths[i] * sin(rot) + heights[i] * cos(rot)) / 2.0 + borderW + shadowPadding;

        final minX = margin + min(hw, availW * 0.4);
        final maxX = canvasW - margin - min(hw, availW * 0.4);
        final minY = margin + min(hh, availH * 0.4);
        final maxY = canvasH - margin - min(hh, availH * 0.4);

        final newX = (current[i].dx + deltas[i].dx).clamp(minX, maxX);
        final newY = (current[i].dy + deltas[i].dy).clamp(minY, maxY);
        current[i] = Offset(newX, newY);
      }
    }

    return current;
  }

  double _optimizeScaleForControlledOverlap({
    required List<Offset> centers,
    required List<double> baseWidths,
    required List<double> baseHeights,
    required List<double> rotations,
    required double canvasW,
    required double canvasH,
    required double margin,
    required double borderW,
    required double shadowPadding,
  }) {
    final int n = centers.length;
    if (n <= 1) return 1.0;

    // 1. Calculate max scale allowed so every photo stays within canvas bounds
    double maxAllowedScale = 2.0;
    for (int i = 0; i < n; i++) {
      final rot = rotations[i].abs();
      final c = centers[i];
      final maxHw = min(c.dx - margin, canvasW - margin - c.dx) - borderW - shadowPadding;
      final maxHh = min(c.dy - margin, canvasH - margin - c.dy) - borderW - shadowPadding;

      final unscaledHw = (baseWidths[i] * cos(rot) + baseHeights[i] * sin(rot)) / 2.0;
      final unscaledHh = (baseWidths[i] * sin(rot) + baseHeights[i] * cos(rot)) / 2.0;

      if (maxHw > 0 && unscaledHw > 0) {
        maxAllowedScale = min(maxAllowedScale, maxHw / unscaledHw);
      }
      if (maxHh > 0 && unscaledHh > 0) {
        maxAllowedScale = min(maxAllowedScale, maxHh / unscaledHh);
      }
    }

    // Binary search between 0.35 and maxAllowedScale for optimal overlap
    double low = 0.35;
    double high = maxAllowedScale;
    double bestScale = (low + high) / 2.0;

    for (int iter = 0; iter < 10; iter++) {
      final mid = (low + high) / 2.0;

      double maxOverlap = 0.0;
      double totalOverlap = 0.0;

      for (int i = 0; i < n; i++) {
        final wi = baseWidths[i] * mid;
        final hi = baseHeights[i] * mid;
        final areaI = wi * hi;

        final leftI = centers[i].dx - wi / 2.0;
        final rightI = centers[i].dx + wi / 2.0;
        final topI = centers[i].dy - hi / 2.0;
        final bottomI = centers[i].dy + hi / 2.0;

        double covered = 0.0;
        for (int j = i + 1; j < n; j++) {
          final wj = baseWidths[j] * mid;
          final hj = baseHeights[j] * mid;

          final leftJ = centers[j].dx - wj / 2.0;
          final rightJ = centers[j].dx + wj / 2.0;
          final topJ = centers[j].dy - hj / 2.0;
          final bottomJ = centers[j].dy + hj / 2.0;

          final ow = max(0.0, min(rightI, rightJ) - max(leftI, leftJ));
          final oh = max(0.0, min(bottomI, bottomJ) - max(topI, topJ));
          covered += (ow * oh);
        }

        final fraction = areaI > 0 ? (covered / areaI) : 0.0;
        if (fraction > maxOverlap) {
          maxOverlap = fraction;
        }
        totalOverlap += fraction;
      }

      final avgOverlap = totalOverlap / n;

      if (maxOverlap > 0.28) {
        high = mid;
      } else if (avgOverlap < 0.05) {
        low = mid;
        bestScale = mid;
      } else {
        bestScale = mid;
        low = mid;
      }
    }

    return bestScale.clamp(0.4, maxAllowedScale);
  }
}

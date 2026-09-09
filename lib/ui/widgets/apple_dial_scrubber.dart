import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/apple_photos_theme.dart';

/// An authentic Apple Photos horizontal tick-dial scrubber.
///
/// Features:
/// - Center Apple Gold indicator notch.
/// - Fluid horizontal tick lines with major/minor tick heights.
/// - Live tabular figure readout badge.
/// - Direct drag with mouse or touch, plus mouse wheel / trackpad scroll support.
/// - Tactile haptic feedback when stepping across values.
class AppleDialScrubber extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final int step;
  final ValueChanged<double> onChanged;

  const AppleDialScrubber({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.unit = 'px',
    this.step = 1,
    required this.onChanged,
  });

  @override
  State<AppleDialScrubber> createState() => _AppleDialScrubberState();
}

class _AppleDialScrubberState extends State<AppleDialScrubber> {
  double _dragAccumulator = 0.0;
  int _lastHapticVal = -999;

  void _updateValue(double delta) {
    _dragAccumulator += delta;
    const double pixelsPerStep = 6.0; // Drag sensitivity
    if (_dragAccumulator.abs() >= pixelsPerStep) {
      final steps = (_dragAccumulator / pixelsPerStep).truncate();
      _dragAccumulator -= steps * pixelsPerStep;

      final newVal = (widget.value + steps * widget.step).clamp(widget.min, widget.max);
      if (newVal != widget.value) {
        widget.onChanged(newVal.toDouble());
        final int rounded = newVal.round();
        if (rounded != _lastHapticVal) {
          _lastHapticVal = rounded;
          HapticFeedback.selectionClick();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int displayVal = widget.value.round();
    final bool isZero = displayVal == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Label and Tabular Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: ApplePhotosTheme.labelSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isZero
                      ? Colors.white.withValues(alpha: 0.08)
                      : ApplePhotosTheme.appleGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isZero
                        ? Colors.white.withValues(alpha: 0.12)
                        : ApplePhotosTheme.appleGold.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  widget.unit.isEmpty ? '$displayVal' : '$displayVal ${widget.unit}',
                  style: TextStyle(
                    color: isZero ? ApplePhotosTheme.labelSecondary : ApplePhotosTheme.appleGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Interactive Tick Dial Scrubber
          Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final double delta = pointerSignal.scrollDelta.dx != 0
                    ? pointerSignal.scrollDelta.dx
                    : pointerSignal.scrollDelta.dy;
                _updateValue(-delta * 0.4);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _dragAccumulator = 0.0;
              },
              onHorizontalDragUpdate: (details) {
                _updateValue(-(details.primaryDelta ?? 0.0));
              },
              child: SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DialPainter(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;

  _DialPainter({
    required this.value,
    required this.min,
    required this.max,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2.0;
    final double centerY = size.height / 2.0;

    const double tickSpacing = 8.0;
    const int numTicksVisible = 35;

    final Paint minorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    final Paint majorPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.60)
      ..strokeWidth = 1.5;

    final Paint goldIndicatorPaint = Paint()
      ..color = ApplePhotosTheme.appleGold
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw baseline track subtle line
    canvas.drawLine(
      Offset(16, centerY + 12),
      Offset(size.width - 16, centerY + 12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 0.5,
    );

    // Compute tick offset based on current value
    final double currentStepOffset = (value - min) * tickSpacing;

    for (int i = -numTicksVisible; i <= numTicksVisible; i++) {
      final double tickX = centerX + (i * tickSpacing) - (currentStepOffset % tickSpacing);

      if (tickX < 10 || tickX > size.width - 10) continue;

      // Distance from center for smooth edge fading
      final double distFromCenter = (tickX - centerX).abs();
      final double maxDist = size.width / 2.0;
      final double alpha = (1.0 - (distFromCenter / maxDist)).clamp(0.0, 1.0);

      final double actualValueAtTick = value + i;
      final bool isWithinRange = actualValueAtTick >= min && actualValueAtTick <= max;
      if (!isWithinRange) continue;

      final bool isMajor = (actualValueAtTick.round() % 5) == 0;
      final double tickHeight = isMajor ? 14.0 : 8.0;

      final paintToUse = isMajor ? majorPaint : minorPaint;
      paintToUse.color = (isMajor ? Colors.white.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.25))
          .withValues(alpha: alpha * (isMajor ? 0.65 : 0.25));

      canvas.drawLine(
        Offset(tickX, centerY - tickHeight / 2.0 + 2),
        Offset(tickX, centerY + tickHeight / 2.0 + 2),
        paintToUse,
      );
    }

    // Center Gold Indicator Needle
    canvas.drawLine(
      Offset(centerX, centerY - 10),
      Offset(centerX, centerY + 10),
      goldIndicatorPaint,
    );

    // Small Gold dot on top of center needle
    canvas.drawCircle(
      Offset(centerX, centerY - 11),
      2.0,
      goldIndicatorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.min != min || oldDelegate.max != max;
  }
}

import 'dart:math' as math;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/detection.dart';
import '../../../domain/models/disease.dart';
import '../../../domain/models/scan_result.dart';
import '../theme/app_colors.dart';

/// The checked photo with a mark around every finding. Pinch to zoom.
///
/// The whole photo is always visible (never cropped), so no mark can fall
/// outside the frame.
class DetectionPhoto extends StatelessWidget {
  const DetectionPhoto({
    super.key,
    required this.image,
    required this.result,
    required this.severityOf,
    required this.semanticLabel,
  });

  /// Widest and tallest shape the frame takes; photos beyond that get bars.
  static const _maxAspect = 2.0;
  static const _minAspect = 0.85;

  final ImageProvider image;
  final ScanResult result;
  final Severity Function(Detection detection) severityOf;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final aspect = (result.imageWidth / result.imageHeight).clamp(
      _minAspect,
      _maxAspect,
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: AspectRatio(
        aspectRatio: aspect,
        child: ColoredBox(
          color: AppColors.surface,
          child: ClipRect(
            child: InteractiveViewer(
              maxScale: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: image,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        size: 40,
                        color: AppColors.icon,
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _FindingsPainter(
                      result: result,
                      severityOf: severityOf,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FindingsPainter extends CustomPainter {
  const _FindingsPainter({required this.result, required this.severityOf});

  final ScanResult result;
  final Severity Function(Detection detection) severityOf;

  @override
  void paint(Canvas canvas, Size size) {
    // Same placement as BoxFit.contain: scale to fit, then centre.
    final scale = math.min(
      size.width / result.imageWidth,
      size.height / result.imageHeight,
    );
    final left = (size.width - result.imageWidth * scale) / 2;
    final top = (size.height - result.imageHeight * scale) / 2;

    // A pale halo keeps the mark visible on dark and on reddish leaves.
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = AppColors.white.withValues(alpha: 0.65);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Least confident first, so the surest marks end up on top.
    for (final detection in result.detections.reversed) {
      final box = detection.box;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left + box.x1 * scale,
          top + box.y1 * scale,
          left + box.x2 * scale,
          top + box.y2 * scale,
        ),
        const Radius.circular(3),
      );
      stroke.color = severityOf(detection) == Severity.none
          ? AppColors.green
          : AppColors.findingStroke;
      canvas
        ..drawRRect(rect, halo)
        ..drawRRect(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(_FindingsPainter oldDelegate) =>
      oldDelegate.result != result;
}

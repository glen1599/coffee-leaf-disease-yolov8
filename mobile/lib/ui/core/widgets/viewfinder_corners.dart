import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Four corner brackets, like the frame of a camera viewfinder.
///
/// The one decorative motif of the app: it marks "the leaf goes here".
class ViewfinderCorners extends StatelessWidget {
  const ViewfinderCorners({
    super.key,
    this.child,
    this.inset = 14,
    this.color = AppColors.green,
  });

  final Widget? child;
  final double inset;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _CornersPainter(inset: inset, color: color),
    child: child,
  );
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter({required this.inset, required this.color});

  static const _arm = 26.0;
  static const _radius = 6.0;
  static const _stroke = 3.0;

  final double inset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;
    final edge = inset + _stroke / 2;

    // One bracket in the top-left corner, mirrored into the other three.
    Path bracket() => Path()
      ..moveTo(edge, inset + _arm)
      ..lineTo(edge, edge + _radius)
      ..arcToPoint(
        Offset(edge + _radius, edge),
        radius: const Radius.circular(_radius),
      )
      ..lineTo(inset + _arm, edge);

    for (final (flipX, flipY) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      canvas
        ..save()
        ..translate(flipX ? size.width : 0, flipY ? size.height : 0)
        ..scale(flipX ? -1 : 1, flipY ? -1 : 1)
        ..drawPath(bracket(), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) =>
      oldDelegate.inset != inset || oldDelegate.color != color;
}

import 'dart:ui';
import 'package:flutter/material.dart';

class DottedBackground extends StatelessWidget {
  const DottedBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _DottedPainter(
        dotColor: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.2),
        spacing: 24.0,
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color dotColor;
  final double spacing;

  _DottedPainter({required this.dotColor, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPainter oldDelegate) {
    return oldDelegate.dotColor != dotColor || oldDelegate.spacing != spacing;
  }
}

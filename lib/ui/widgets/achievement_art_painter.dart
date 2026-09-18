import 'dart:math' as math;
import 'package:flutter/material.dart';

class AchievementArtPainter extends CustomPainter {
  final String id;
  final bool isUnlocked;
  final Color themeColor;

  AchievementArtPainter({
    required this.id,
    required this.isUnlocked,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.45;

    // Background circle (very subtle)
    final bgPaint = Paint()
      ..color = isUnlocked 
          ? themeColor.withOpacity(0.08) 
          : const Color(0xFF707A8A).withOpacity(0.03)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border circle (very thin)
    final borderPaint = Paint()
      ..color = isUnlocked 
          ? themeColor.withOpacity(0.2) 
          : const Color(0xFF707A8A).withOpacity(0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    // Drawing paint for the central art
    final artPaint = Paint()
      ..color = isUnlocked ? themeColor : const Color(0xFF707A8A).withOpacity(0.3)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = isUnlocked ? themeColor : const Color(0xFF707A8A).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    switch (id) {
      case 'first_steps':
        // 🌱 BROTE DE HOJA MINIMALISTA
        artPaint.style = PaintingStyle.stroke;
        final path = Path();
        // Central stem
        path.moveTo(center.dx, center.dy + radius * 0.5);
        path.lineTo(center.dx, center.dy - radius * 0.4);
        
        // Left leaf using bezier curves
        path.moveTo(center.dx, center.dy + radius * 0.1);
        path.quadraticBezierTo(
          center.dx - radius * 0.45, center.dy - radius * 0.1,
          center.dx, center.dy - radius * 0.3,
        );

        // Right leaf using bezier curves
        path.moveTo(center.dx, center.dy - radius * 0.1);
        path.quadraticBezierTo(
          center.dx + radius * 0.4, center.dy - radius * 0.3,
          center.dx, center.dy - radius * 0.45,
        );

        canvas.drawPath(path, artPaint);
        break;

      case 'double_traction':
        // 🛹 VESICA PISCIS (DOS CÍRCULOS INTERSECTADOS)
        artPaint.style = PaintingStyle.stroke;
        final double circleRadius = radius * 0.45;
        final double offset = radius * 0.22;
        
        canvas.drawCircle(center.translate(-offset, 0), circleRadius, artPaint);
        canvas.drawCircle(center.translate(offset, 0), circleRadius, artPaint);
        break;

      case 'streak_3':
        // 🔥 TRIQUETA (NUDO DE TRES LÓBULOS)
        artPaint.style = PaintingStyle.stroke;
        artPaint.strokeJoin = StrokeJoin.round;
        final path = Path();
        
        // Calculating 3 vertices of an equilateral triangle
        final double r = radius * 0.38;
        final v1 = Offset(center.dx, center.dy - r);
        final v2 = Offset(center.dx - r * math.cos(math.pi / 6), center.dy + r * math.sin(math.pi / 6));
        final v3 = Offset(center.dx + r * math.cos(math.pi / 6), center.dy + r * math.sin(math.pi / 6));
        
        // Draw 3 interlocking circular arcs
        final arcRadius = r * 1.55;
        path.addArc(Rect.fromCircle(center: v1, radius: arcRadius), math.pi * 0.18, math.pi * 0.64);
        path.addArc(Rect.fromCircle(center: v2, radius: arcRadius), -math.pi * 0.48, math.pi * 0.64);
        path.addArc(Rect.fromCircle(center: v3, radius: arcRadius), math.pi * 0.85, math.pi * 0.64);

        canvas.drawPath(path, artPaint);
        break;

      case 'streak_5':
        // 🖐️ CINCO DE ORO (PENTAGRAMA)
        artPaint.style = PaintingStyle.stroke;
        final double r = radius * 0.55;
        final List<Offset> points = [];
        
        for (int i = 0; i < 5; i++) {
          final double angle = -math.pi / 2 + (i * 2 * math.pi / 5);
          points.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));
        }

        // Draw outer pentagon
        for (int i = 0; i < 5; i++) {
          canvas.drawLine(points[i], points[(i + 1) % 5], artPaint);
        }

        // Draw thin inner star connections
        final starPaint = Paint()
          ..color = artPaint.color.withOpacity(0.35)
          ..strokeWidth = 1.0;
        canvas.drawLine(points[0], points[2], starPaint);
        canvas.drawLine(points[2], points[4], starPaint);
        canvas.drawLine(points[4], points[1], starPaint);
        canvas.drawLine(points[1], points[3], starPaint);
        canvas.drawLine(points[3], points[0], starPaint);

        // Solid central tiny node
        canvas.drawCircle(center, 4, fillPaint);
        break;

      case 'streak_7':
        // ⚡ SEMANA PERFECTA (ESTRELLA HEPTAGONAL)
        artPaint.style = PaintingStyle.stroke;
        final double r = radius * 0.6;
        final List<Offset> points = [];
        
        for (int i = 0; i < 7; i++) {
          final double angle = -math.pi / 2 + (i * 2 * math.pi / 7);
          points.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));
        }

        // Draw 7-pointed star outline (step = 2)
        final path = Path()..moveTo(points[0].dx, points[0].targetY(points[0]));
        int next = 0;
        for (int i = 0; i < 7; i++) {
          next = (next + 3) % 7;
          path.lineTo(points[next].dx, points[next].dy);
        }
        canvas.drawPath(path, artPaint);
        break;

      case 'streak_15':
        // 🏹 ARCO Y FLECHA
        artPaint.style = PaintingStyle.stroke;
        final path = Path();
        
        // Bow arc
        final rect = Rect.fromCircle(center: center, radius: radius * 0.5);
        path.addArc(rect, math.pi * 0.35, math.pi * 1.3);
        
        // String
        final pStart = Offset(center.dx + radius * 0.5 * math.cos(math.pi * 0.35), center.dy + radius * 0.5 * math.sin(math.pi * 0.35));
        final pEnd = Offset(center.dx + radius * 0.5 * math.cos(math.pi * 1.65), center.dy + radius * 0.5 * math.sin(math.pi * 1.65));
        canvas.drawLine(pStart, pEnd, Paint()..color = artPaint.color.withOpacity(0.3)..strokeWidth = 1.0);

        // Arrow
        final arrowStart = Offset(center.dx - radius * 0.45, center.dy + radius * 0.45);
        final arrowEnd = Offset(center.dx + radius * 0.4, center.dy - radius * 0.4);
        canvas.drawLine(arrowStart, arrowEnd, artPaint);

        // Arrowhead
        final arrowHeadPath = Path();
        final double arrowAngle = -math.pi / 4;
        final double wingLength = radius * 0.15;
        
        arrowHeadPath.moveTo(arrowEnd.dx, arrowEnd.dy);
        arrowHeadPath.lineTo(
          arrowEnd.dx - wingLength * math.cos(arrowAngle - 0.35),
          arrowEnd.dy - wingLength * math.sin(arrowAngle - 0.35)
        );
        arrowHeadPath.moveTo(arrowEnd.dx, arrowEnd.dy);
        arrowHeadPath.lineTo(
          arrowEnd.dx - wingLength * math.cos(arrowAngle + 0.35),
          arrowEnd.dy - wingLength * math.sin(arrowAngle + 0.35)
        );
        canvas.drawPath(arrowHeadPath, artPaint);
        break;

      case 'streak_30':
        // 🪐 SATURNO CELESTIAL
        artPaint.style = PaintingStyle.stroke;
        
        // Draw Saturn's body
        canvas.drawCircle(center, radius * 0.32, fillPaint);
        
        // Draw Ring (rotated ellipse)
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(-math.pi / 10); // Rotate 18 degrees
        
        final ringPaint = Paint()
          ..color = artPaint.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        
        final ringRect = Rect.fromCenter(center: Offset.zero, width: radius * 1.25, height: radius * 0.22);
        canvas.drawOval(ringRect, ringPaint);
        canvas.restore();
        break;

      case 'streak_90':
        // ☀️ ÓRBITA SOLAR
        artPaint.style = PaintingStyle.stroke;
        
        // Central Sun
        canvas.drawCircle(center, radius * 0.25, fillPaint);
        
        // 12 Sun Rays
        final double innerR = radius * 0.38;
        final double outerR = radius * 0.58;
        for (int i = 0; i < 12; i++) {
          final double angle = i * 2 * math.pi / 12;
          final start = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
          final end = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));
          canvas.drawLine(start, end, artPaint);
        }
        break;

      case 'habits_5':
        // 👑 CORONA ZEN
        artPaint.style = PaintingStyle.stroke;
        artPaint.strokeJoin = StrokeJoin.round;
        final path = Path();
        
        final double w = radius * 0.7;
        final double h = radius * 0.45;
        
        final startPt = Offset(center.dx - w * 0.5, center.dy + h * 0.3);
        path.moveTo(startPt.dx, startPt.dy);
        // Base line
        path.lineTo(center.dx + w * 0.5, center.dy + h * 0.3);
        // Right side
        path.lineTo(center.dx + w * 0.55, center.dy - h * 0.3);
        // Right cusp
        path.lineTo(center.dx + w * 0.3, center.dy + h * 0.05);
        // Mid-right cusp
        path.lineTo(center.dx, center.dy - h * 0.5);
        // Mid-left cusp
        path.lineTo(center.dx - w * 0.3, center.dy + h * 0.05);
        // Left side
        path.lineTo(startPt.dx - w * 0.05, center.dy - h * 0.3);
        path.close();

        canvas.drawPath(path, artPaint);

        // Small jewels (5 dots at the crown tips)
        final double dotR = 2.5;
        canvas.drawCircle(Offset(center.dx - w * 0.55, center.dy - h * 0.3), dotR, fillPaint);
        canvas.drawCircle(Offset(center.dx - w * 0.3, center.dy + h * 0.05), dotR, fillPaint);
        canvas.drawCircle(Offset(center.dx, center.dy - h * 0.5), dotR, fillPaint);
        canvas.drawCircle(Offset(center.dx + w * 0.3, center.dy + h * 0.05), dotR, fillPaint);
        canvas.drawCircle(Offset(center.dx + w * 0.55, center.dy - h * 0.3), dotR, fillPaint);
        break;

      case 'habits_8':
        // 🚀 ESPIRAL GALÁCTICA (FIBONACCI)
        artPaint.style = PaintingStyle.stroke;
        final path = Path();
        
        // Logarithmic spiral drawing
        double a = 1.2;
        double b = 0.22;
        
        bool first = true;
        for (double theta = 0; theta < 5 * math.pi; theta += 0.1) {
          final double r = a * math.pow(math.e, b * theta);
          final double x = center.dx + r * math.cos(theta);
          final double y = center.dy + r * math.sin(theta);
          
          if (first) {
            path.moveTo(x, y);
            first = false;
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, artPaint);
        break;

      case 'orbits_multiple_3':
        // 🌟 TRES ÓRBITAS CONCÉNTRICAS
        artPaint.style = PaintingStyle.stroke;
        
        final double r1 = radius * 0.3;
        final double r2 = radius * 0.5;
        final double r3 = radius * 0.7;

        // Draw 3 orbit lines
        canvas.drawCircle(center, r1, Paint()..color = artPaint.color.withOpacity(0.15)..strokeWidth = 1.0..style = PaintingStyle.stroke);
        canvas.drawCircle(center, r2, Paint()..color = artPaint.color.withOpacity(0.25)..strokeWidth = 1.2..style = PaintingStyle.stroke);
        canvas.drawCircle(center, r3, Paint()..color = artPaint.color.withOpacity(0.4)..strokeWidth = 1.5..style = PaintingStyle.stroke);

        // Draw 3 planet nodes along the orbits
        canvas.drawCircle(Offset(center.dx + r1 * math.cos(math.pi / 4), center.dy + r1 * math.sin(math.pi / 4)), 3.5, fillPaint);
        canvas.drawCircle(Offset(center.dx + r2 * math.cos(5 * math.pi / 4), center.dy + r2 * math.sin(5 * math.pi / 4)), 4.5, fillPaint);
        canvas.drawCircle(Offset(center.dx + r3 * math.cos(3 * math.pi / 2), center.dy + r3 * math.sin(3 * math.pi / 2)), 5.5, fillPaint);
        break;

      case 'total_200':
        // 💎 DIAMANTE FACETADO
        artPaint.style = PaintingStyle.stroke;
        artPaint.strokeJoin = StrokeJoin.round;
        
        final double w = radius * 0.65;
        final double h = radius * 0.55;
        
        // Pentagon facets vertices
        final vTopL = Offset(center.dx - w * 0.35, center.dy - h * 0.35);
        final vTopR = Offset(center.dx + w * 0.35, center.dy - h * 0.35);
        final vMidL = Offset(center.dx - w * 0.5, center.dy);
        final vMidR = Offset(center.dx + w * 0.5, center.dy);
        final vBottom = Offset(center.dx, center.dy + h * 0.5);

        // Draw outside boundary
        final path = Path()
          ..moveTo(vTopL.dx, vTopL.dy)
          ..lineTo(vTopR.dx, vTopR.dy)
          ..lineTo(vMidR.dx, vMidR.dy)
          ..lineTo(vBottom.dx, vBottom.dy)
          ..lineTo(vMidL.dx, vMidL.dy)
          ..close();
        canvas.drawPath(path, artPaint);

        // Inner facets connections
        final facetPaint = Paint()
          ..color = artPaint.color.withOpacity(0.4)
          ..strokeWidth = 1.2;
        
        canvas.drawLine(vTopL, vBottom, facetPaint);
        canvas.drawLine(vTopR, vBottom, facetPaint);
        canvas.drawLine(vTopL, vTopR, facetPaint);
        canvas.drawLine(vMidL, vTopL, facetPaint);
        canvas.drawLine(vMidR, vTopR, facetPaint);
        canvas.drawLine(vMidL, vMidR, facetPaint);
        canvas.drawLine(vTopL, vMidR, facetPaint);
        canvas.drawLine(vTopR, vMidL, facetPaint);
        break;

      default:
        // Default circular abstract art
        canvas.drawCircle(center, radius * 0.3, artPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AchievementArtPainter oldDelegate) {
    return oldDelegate.id != id || 
           oldDelegate.isUnlocked != isUnlocked || 
           oldDelegate.themeColor != themeColor;
  }
}

extension on Offset {
  double targetY(Offset o) => o.dy;
}

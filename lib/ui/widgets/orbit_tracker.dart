import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/habit.dart';
import '../../utils/date_utils.dart';

class OrbitTracker extends StatefulWidget {
  final List<Habit> habits;
  final DateTime currentMonth;
  final Function(DateTime date) onDayColumnTapped;

  const OrbitTracker({
    Key? key,
    required this.habits,
    required this.currentMonth,
    required this.onDayColumnTapped,
  }) : super(key: key);

  @override
  State<OrbitTracker> createState() => _OrbitTrackerState();
}

class _OrbitTrackerState extends State<OrbitTracker> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int? _hoveredDay;
  DateTime? _lastTappedDate;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.value = 1.0;
  }

  @override
  void didUpdateWidget(OrbitTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMonth != widget.currentMonth) {
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int? _getDayFromOffset(Offset localPosition, Size size) {
    if (widget.habits.isEmpty) return null;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    var angle = math.atan2(dy, dx);
    
    if (angle < 0) angle += 2 * math.pi;

    final startOffsetAngle = math.pi; // Empieza a las 9 en punto (izquierda)
    var rotatedAngle = angle - startOffsetAngle;
    if (rotatedAngle < 0) rotatedAngle += 2 * math.pi;

    final maxRadius = math.min(size.width, size.height) * 0.37;
    final minRadius = maxRadius * 0.3; 
    
    if (distance < minRadius || distance > maxRadius) return null;

    final daysInMonth = OrbitDateUtils.getDaysInMonth(widget.currentMonth.year, widget.currentMonth.month);
    final totalSweep = math.pi * 1.6; // 288 degrees horseshoe
    final anglePerDay = totalSweep / daysInMonth;

    if (rotatedAngle > totalSweep) return null;

    final dayIndex = (rotatedAngle / anglePerDay).floor();
    final day = dayIndex + 1;
    
    if (day < 1 || day > daysInMonth) return null;
    return day;
  }

  void _handlePanUpdate(Offset localPosition, Size size) {
    final day = _getDayFromOffset(localPosition, size);
    if (day != _hoveredDay) {
      setState(() {
        _hoveredDay = day;
      });
      if (day != null) {
        // Advanced premium haptic tick simulating a physical rotary dial gear!
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handlePanEnd() {
    if (_hoveredDay == null) return;
    
    final tappedDate = DateTime(widget.currentMonth.year, widget.currentMonth.month, _hoveredDay!);
    
    // Future date block
    if (OrbitDateUtils.isFutureDate(tappedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes predecir el futuro 🔮')),
      );
      setState(() => _hoveredDay = null);
      return;
    }

    setState(() {
      _lastTappedDate = tappedDate;
      _hoveredDay = null; // reset hover
    });

    widget.onDayColumnTapped(tappedDate);
  }

  @override
  Widget build(BuildContext context) {
    final gridTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF707A8A);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (details) => _handlePanUpdate(details.localPosition, size),
          onPanUpdate: (details) => _handlePanUpdate(details.localPosition, size),
          onPanEnd: (details) => _handlePanEnd(),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: OrbitPainter(
                  habits: widget.habits,
                  currentMonth: widget.currentMonth,
                  hoveredDay: _hoveredDay,
                  animatingDate: _lastTappedDate,
                  animationValue: _scaleAnimation.value,
                  gridTextColor: gridTextColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class OrbitPainter extends CustomPainter {
  final List<Habit> habits;
  final DateTime currentMonth;
  final int? hoveredDay;
  final DateTime? animatingDate;
  final double animationValue;
  final Color gridTextColor;

  OrbitPainter({
    required this.habits,
    required this.currentMonth,
    this.hoveredDay,
    this.animatingDate,
    this.animationValue = 1.0,
    required this.gridTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (habits.isEmpty) return;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final maxRadius = math.min(size.width, size.height) * 0.37; // Reduced from 0.45 to add breathing room and avoid overlap
    final minRadius = maxRadius * 0.3;
    final availableRadius = maxRadius - minRadius;
    final ringWidth = availableRadius / (habits.length > 0 ? habits.length : 1);
    final ringPadding = ringWidth * 0.08; // Slightly reduced padding for a cleaner visual grid

    final daysInMonth = OrbitDateUtils.getDaysInMonth(currentMonth.year, currentMonth.month);
    final totalSweep = math.pi * 1.6; // 288 degrees horseshoe
    final anglePerDay = totalSweep / daysInMonth;
    final startOffsetAngle = math.pi; // Left side

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Softened grid paint for Zen aesthetic (adapts to active theme)
    final gridPaint = Paint()
      ..color = gridTextColor.withOpacity(0.06) // Adapts beautifully to Pizarra/Crema/Bosque themes!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;
    final today = now.day;

    // Draw outer numbers
    for (int d = 1; d <= daysInMonth; d++) {
      final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
      final centerAngle = startAngle + (anglePerDay / 2);
      
      // textRadius is perfectly offset from maxRadius
      final textRadius = maxRadius + 14.0;
      final tx = center.dx + textRadius * math.cos(centerAngle);
      final ty = center.dy + textRadius * math.sin(centerAngle);

      double rotationAngle = centerAngle + math.pi / 2;
      
      // Normalize rotation angle to [-pi, pi] to detect upside-down text
      double normalizedRotation = rotationAngle;
      while (normalizedRotation > math.pi) normalizedRotation -= 2 * math.pi;
      while (normalizedRotation < -math.pi) normalizedRotation += 2 * math.pi;

      // Flip the number 180 degrees if it would be upside-down for the user
      if (normalizedRotation.abs() > math.pi / 2) {
        rotationAngle += math.pi;
      }

      final isToday = isCurrentMonth && d == today;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(rotationAngle);

      if (isToday) {
        // Highlight background circle for the current day
        final highlightPaint = Paint()
          ..color = const Color(0xFFE6A590) // Match UI accent color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 11.0, highlightPaint);
      }

      textPainter.text = TextSpan(
        text: d.toString().padLeft(2, '0'),
        style: TextStyle(
          color: isToday ? Colors.white : gridTextColor.withOpacity(0.65), 
          fontSize: isToday ? 10.5 : 9.5, 
          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
          letterSpacing: 0.5,
        ),
      );
      textPainter.layout();
      
      // Center the text perfectly on (tx, ty) to guarantee uniform spacing at all angles
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
      
      // Draw radial grid lines
      final innerTx = center.dx + minRadius * math.cos(startAngle);
      final innerTy = center.dy + minRadius * math.sin(startAngle);
      final outerTx = center.dx + maxRadius * math.cos(startAngle);
      final outerTy = center.dy + maxRadius * math.sin(startAngle);
      canvas.drawLine(Offset(innerTx, innerTy), Offset(outerTx, outerTy), gridPaint);
    }
    
    // Draw closing radial line for the grid
    final endAngle = startOffsetAngle + totalSweep;
    final innerTx = center.dx + minRadius * math.cos(endAngle);
    final innerTy = center.dy + minRadius * math.sin(endAngle);
    final outerTx = center.dx + maxRadius * math.cos(endAngle);
    final outerTy = center.dy + maxRadius * math.sin(endAngle);
    canvas.drawLine(Offset(innerTx, innerTy), Offset(outerTx, outerTy), gridPaint);

    // Draw circular grid lines
    for (int h = 0; h <= habits.length; h++) {
      final r = minRadius + (h * ringWidth);
      final path = Path();
      path.arcTo(Rect.fromCircle(center: center, radius: r), startOffsetAngle, totalSweep, true);
      canvas.drawPath(path, gridPaint);
    }

    for (int h = 0; h < habits.length; h++) {
      // Dibujamos de fuera hacia adentro para coincidir con la lista invertida (primer elemento = outer ring)
      final habitIndex = habits.length - 1 - h;
      final habit = habits[habitIndex];
      final innerRadius = minRadius + (h * ringWidth) + ringPadding;
      final outerRadius = minRadius + ((h + 1) * ringWidth) - ringPadding;
      for (int d = 1; d <= daysInMonth; d++) {
        final dateIso = DateTime(currentMonth.year, currentMonth.month, d).toIso8601String().split('T').first;
        final isCompleted = habit.completedDates.contains(dateIso);
        
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        final sweepAngle = anglePerDay - 0.04; // Padding between days

        final path = Path();
        path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweepAngle, true);
        path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + sweepAngle, -sweepAngle, false);
        path.close();

        final paint = Paint()..style = PaintingStyle.fill;

        if (isCompleted) {
          paint.color = habit.color.withOpacity(animationValue);
        } else {
          paint.color = habit.color.withOpacity(0.05);
        }

        canvas.drawPath(path, paint);
      }
    }

    // 3. Hover indicator (Scrubbing feedback)
    if (hoveredDay != null && hoveredDay! >= 1 && hoveredDay! <= daysInMonth) {
      final d = hoveredDay!;
      final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
      final sweepAngle = anglePerDay - 0.04;
      final outerRadius = minRadius + (habits.length * ringWidth) - ringPadding;
      final innerRadius = minRadius + ringPadding;

      final path = Path();
      path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweepAngle, true);
      path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + sweepAngle, -sweepAngle, false);
      path.close();

      final hoverPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withOpacity(0.9);

      canvas.drawPath(path, hoverPaint);
    }

    // 4. Glow effect (Apple Watch style) for perfectly completed days
    for (int d = 1; d <= daysInMonth; d++) {
      final dateIso = DateTime(currentMonth.year, currentMonth.month, d).toIso8601String().split('T').first;
      
      bool allCompleted = true;
      for (var habit in habits) {
        if (!habit.completedDates.contains(dateIso)) {
          allCompleted = false;
          break;
        }
      }

      if (allCompleted && habits.isNotEmpty) {
        final startAngle = startOffsetAngle + ((d - 1) * anglePerDay);
        final sweepAngle = anglePerDay - 0.04;
        final outerRadius = minRadius + (habits.length * ringWidth) - ringPadding;
        final innerRadius = minRadius + ringPadding;

        // Draw a glowing border around the whole day column
        final path = Path();
        path.arcTo(Rect.fromCircle(center: center, radius: innerRadius), startAngle, sweepAngle, true);
        path.arcTo(Rect.fromCircle(center: center, radius: outerRadius), startAngle + sweepAngle, -sweepAngle, false);
        path.close();

        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withOpacity(0.8 * animationValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4.0);

        canvas.drawPath(path, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter oldDelegate) {
    return oldDelegate.habits != habits ||
           oldDelegate.currentMonth != currentMonth ||
           oldDelegate.hoveredDay != hoveredDay ||
           oldDelegate.animationValue != animationValue;
  }
}

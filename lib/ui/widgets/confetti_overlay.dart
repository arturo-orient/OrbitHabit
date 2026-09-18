import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double size;
  double speedY;
  double speedX;
  double angle;
  double spinSpeed;
  Color color;
  bool isCircle;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedY,
    required this.speedX,
    required this.angle,
    required this.spinSpeed,
    required this.color,
    required this.isCircle,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final VoidCallback onFinished;

  const ConfettiOverlay({Key? key, required this.onFinished}) : super(key: key);

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  final List<Color> _colors = const [
    Color(0xFF84A59D), // Verde Salvia
    Color(0xFFB5A6C9), // Azul Lavanda
    Color(0xFFF2C6B4), // Melocotón Suave
    Color(0xFFE5D08F), // Mostaza/Arena
    Color(0xFF9EA1D4), // Periwinkle
    Color(0xFFE5989B), // Rosa Empolvado
    Color(0xFFA8C2D3), // Gris Invierno
  ];

  @override
  void initState() {
    super.initState();
    // 4 seconds of peaceful, floating celebration (snowflake style)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });

    _generateParticles();
    _controller.forward();
  }

  void _generateParticles() {
    // 65 particles is the perfect "Zen density" — pleasant without being chaotic
    for (int i = 0; i < 65; i++) {
      _particles.add(ConfettiParticle(
        x: _random.nextDouble(),
        y: -0.2 - _random.nextDouble() * 0.8,
        size: 5 + _random.nextDouble() * 7,
        // Extremely smooth and slow falling speed (0.1 to 0.25 screens per second)
        speedY: 0.12 + _random.nextDouble() * 0.15,
        speedX: -0.04 + _random.nextDouble() * 0.08,
        angle: _random.nextDouble() * math.pi * 2,
        spinSpeed: -0.04 + _random.nextDouble() * 0.08,
        color: _colors[_random.nextInt(_colors.length)],
        isCircle: _random.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Update physics each frame smoothly at 120 FPS
        for (var p in _particles) {
          p.y += p.speedY * 0.016; 
          p.x += p.speedX * 0.016;
          p.angle += p.spinSpeed;
          // Subtly sway sideways like floating willow leaves using a sine function
          p.x += math.sin(_controller.value * math.pi * 4 + p.size) * 0.0006;
        }

        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(particles: _particles),
          ),
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // Ignore particles outside the viewport plus padding
      if (p.y > 1.15 || p.x < -0.15 || p.x > 1.15) continue;

      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.angle);

      paint.color = p.color;

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        // Flat capsule/willow-leaf shape
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size * 0.7),
            Radius.circular(p.size * 0.35),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';

class HabitProgressCard extends StatefulWidget {
  final String name;
  final Color color;
  final int? percentage;
  final int streak;

  const HabitProgressCard({
    Key? key,
    required this.name,
    required this.color,
    this.percentage,
    required this.streak,
  }) : super(key: key);

  @override
  State<HabitProgressCard> createState() => _HabitProgressCardState();
}

class _HabitProgressCardState extends State<HabitProgressCard> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.streak >= 30) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant HabitProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streak >= 30 && oldWidget.streak < 30) {
      _glowController.repeat(reverse: true);
    } else if (widget.streak < 30 && oldWidget.streak >= 30) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // Tiers logic
  Color? _getFlameColor() {
    if (widget.streak >= 30) return const Color(0xFF00E5FF); // Diamante
    if (widget.streak >= 14) return const Color(0xFFFFD700); // Oro
    if (widget.streak >= 7) return const Color(0xFFC0C0C0);  // Plata
    if (widget.streak >= 3) return const Color(0xFFCD7F32);  // Bronce
    return null;
  }

  Color? _getGlowColor() {
    if (widget.streak >= 30) return const Color(0xFF00E5FF); // Animated Diamond
    if (widget.streak >= 14) return const Color(0xFFFFD700).withOpacity(0.4); // Gold glow
    if (widget.streak >= 7) return const Color(0xFFC0C0C0).withOpacity(0.3);  // Silver glow
    return null; // No glow for Bronze or < 3
  }

  @override
  Widget build(BuildContext context) {
    final flameColor = _getFlameColor();
    final baseGlowColor = _getGlowColor();

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        List<BoxShadow> shadows = [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ];

        if (baseGlowColor != null) {
          if (widget.streak >= 30) {
            // Brillo legendario animado
            shadows.add(
              BoxShadow(
                color: baseGlowColor.withOpacity(_glowAnimation.value),
                blurRadius: 15 + (10 * _glowAnimation.value),
                spreadRadius: 2 * _glowAnimation.value,
              ),
            );
          } else {
            // Brillo estático para plata y oro
            shadows.add(
              BoxShadow(
                color: baseGlowColor,
                blurRadius: 12,
                spreadRadius: 1,
              ),
            );
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: widget.streak >= 30 
                ? Border.all(color: baseGlowColor!.withOpacity(0.5 + 0.5 * _glowAnimation.value), width: 1.5)
                : null,
            boxShadow: shadows,
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.name,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (flameColor != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: flameColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: flameColor.withOpacity(0.3), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, color: flameColor, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.streak}',
                          style: TextStyle(
                            color: flameColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.percentage != null)
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.percentage}%',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.percentage! / 100,
                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white.withOpacity(0.08) 
                          : Colors.grey.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

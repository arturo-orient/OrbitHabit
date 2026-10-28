import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Tarjeta de progreso de hábito con estándar Neo-Bento, física táctil elástica,
/// interruptor táctil Quick-Check y telemetría semanal de 7 LEDs (Monday-Sunday).
class HabitProgressCard extends StatefulWidget {
  final String name;
  final Color color;
  final int? percentage;
  final int streak;
  final List<bool>? weeklyCompletions;
  final VoidCallback? onTap;
  final bool isCompletedToday;
  final VoidCallback? onToggleToday;

  const HabitProgressCard({
    Key? key,
    required this.name,
    required this.color,
    this.percentage,
    required this.streak,
    this.weeklyCompletions,
    this.onTap,
    this.isCompletedToday = false,
    this.onToggleToday,
  }) : super(key: key);

  @override
  State<HabitProgressCard> createState() => _HabitProgressCardState();
}

class _HabitProgressCardState extends State<HabitProgressCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  // Niveles cromáticos técnicos para las rachas
  Color? _getStreakBadgeColor(bool isDark) {
    if (widget.streak >= 30) return AppTheme.dynamicAccent(isDark); // Nivel Maestro: Dinámico según tema
    if (widget.streak >= 14) return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);  // Nivel Oro
    if (widget.streak >= 7) return isDark ? const Color(0xFFE4E4E7) : const Color(0xFF475569);   // Nivel Plata
    if (widget.streak >= 3) return isDark ? const Color(0xFFD97706) : const Color(0xFFC2410C);   // Nivel Bronce
    return null;
  }

  Widget _buildWeeklyTelemetry(bool isDark) {
    if (widget.weeklyCompletions == null || widget.weeklyCompletions!.length < 7) {
      return const SizedBox.shrink();
    }
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final currentWeekday = DateTime.now().weekday - 1; // 0 = Lunes, 6 = Domingo

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final isDone = widget.weeklyCompletions![i];
        final isCurrent = i == currentWeekday;

        return Padding(
          padding: const EdgeInsets.only(left: 3.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7.0,
                height: 7.0,
                decoration: BoxDecoration(
                  color: isDone
                      ? widget.color
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(1.8),
                  border: isCurrent && !isDone
                      ? Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.25),
                          width: 0.8,
                        )
                      : null,
                  boxShadow: isDone
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.45),
                            blurRadius: 3,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                days[i],
                style: AppTheme.monoStyle(
                  fontSize: 7.5,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: isDone
                      ? (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary)
                      : (isCurrent
                          ? (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary)
                          : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streakColor = _getStreakBadgeColor(isDark);
    final isLegendary = widget.streak >= 30;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: AppTheme.bentoCard(
            isLight: !isDark,
            borderRadius: AppTheme.radiusMd,
            borderColor: isLegendary
                ? AppTheme.dynamicAccent(isDark).withValues(alpha: 0.35)
                : (widget.isCompletedToday
                    ? widget.color.withValues(alpha: 0.25)
                    : null),
          ),
          child: Row(
            children: [
              // Interruptor Táctico Quick-Check (Direct Toggle)
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onToggleToday?.call();
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.isCompletedToday
                        ? widget.color.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5.5),
                    border: Border.all(
                      color: widget.isCompletedToday
                          ? widget.color
                          : (isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.20)),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: widget.isCompletedToday
                      ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: widget.color,
                        )
                      : Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Nombre del hábito y Badge técnico de racha
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.name,
                            style: AppTheme.displayStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? (widget.isCompletedToday
                                      ? AppTheme.obsidianTextPrimary.withValues(alpha: 0.70)
                                      : AppTheme.obsidianTextPrimary)
                                  : (widget.isCompletedToday
                                      ? AppTheme.boneTextPrimary.withValues(alpha: 0.70)
                                      : AppTheme.boneTextPrimary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (streakColor != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: streakColor.withValues(alpha: 0.12),
                              borderRadius: AppTheme.radiusXs,
                              border: Border.all(
                                color: streakColor.withValues(alpha: 0.28),
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: streakColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.streak}d',
                                  style: AppTheme.monoStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: streakColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.percentage != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (widget.percentage! / 100).clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                          minHeight: 3.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Telemetría semanal de 7 LEDs
              _buildWeeklyTelemetry(isDark),
            ],
          ),
        ),
      ),
    );
  }
}

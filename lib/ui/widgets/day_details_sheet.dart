import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../widgets/confetti_overlay.dart';
import '../../providers/habit_provider.dart';
import '../../services/sound_service.dart';

class DayDetailsSheet extends ConsumerStatefulWidget {
  final DateTime date;

  const DayDetailsSheet({Key? key, required this.date}) : super(key: key);

  @override
  ConsumerState<DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends ConsumerState<DayDetailsSheet> {
  void _showFullScreenConfetti() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: ConfettiOverlay(
            onFinished: () {
              entry.remove();
            },
          ),
        ),
      ),
    );
    
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final allHabits = ref.watch(habitsProvider);
    final dateIso = widget.date.toIso8601String().split('T').first;
    
    // Filtramos los hábitos que tocan hoy
    final activeHabits = allHabits.where((h) => h.activeWeekdays.contains(widget.date.weekday)).toList();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Día ${widget.date.day}/${widget.date.month}/${widget.date.year}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayLarge?.color),
              ),
              const SizedBox(height: 24),
              if (activeHabits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Día de descanso. ¡Disfruta!', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6))),
                ),
              if (activeHabits.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: activeHabits.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final habit = activeHabits[index];
                      final isCompleted = habit.completedDates.contains(dateIso);
                      final currentProgress = habit.dailyProgress[dateIso] ?? 0;
                      
                      return _HabitRow(
                        key: ValueKey(habit.id),
                        habit: habit,
                        isCompleted: isCompleted,
                        currentProgress: currentProgress,
                        dateIso: dateIso,
                        onConfetti: _showFullScreenConfetti,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitRow extends ConsumerStatefulWidget {
  final Habit habit;
  final bool isCompleted;
  final int currentProgress;
  final String dateIso;
  final VoidCallback onConfetti;

  const _HabitRow({
    Key? key,
    required this.habit,
    required this.isCompleted,
    required this.currentProgress,
    required this.dateIso,
    required this.onConfetti,
  }) : super(key: key);

  @override
  ConsumerState<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends ConsumerState<_HabitRow> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final wasCompleted = widget.isCompleted;
    
    _controller.forward().then((_) => _controller.reverse());
    
    if (!wasCompleted) {
      HapticFeedback.mediumImpact();
      SoundService().playCheck();
      widget.onConfetti();
    } else {
      HapticFeedback.lightImpact();
    }
    
    ref.read(habitsProvider.notifier).toggleDay(widget.habit.id, widget.dateIso);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isCompleted ? widget.habit.color.withOpacity(0.15) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isCompleted ? widget.habit.color : Colors.grey.withOpacity(0.15),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: widget.habit.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.habit.name,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    widget.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    color: widget.isCompleted ? widget.habit.color : Colors.grey.withOpacity(0.3),
                    size: 28,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

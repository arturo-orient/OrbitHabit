import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../widgets/add_habit_sheet.dart';

class ManageHabitsScreen extends ConsumerWidget {
  const ManageHabitsScreen({Key? key}) : super(key: key);

  void _showEditHabitSheet(BuildContext context, habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHabitSheet(habitToEdit: habit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Hábitos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: habits.isEmpty
          ? Center(
              child: Text('No tienes hábitos.', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6), fontSize: 16)),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: habits.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(habitsProvider.notifier).reorderHabits(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final habit = habits[index];
                return Container(
                  key: ValueKey(habit.id),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: habit.color.withOpacity(0.2), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: habit.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      habit.name,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      'Meta: ${habit.targetDays} días',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)),
                          onPressed: () => _showEditHabitSheet(context, habit),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            ref.read(habitsProvider.notifier).deleteHabit(habit.id);
                          },
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.drag_handle, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

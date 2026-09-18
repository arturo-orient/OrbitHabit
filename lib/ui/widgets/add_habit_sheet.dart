import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';

class AddHabitSheet extends ConsumerStatefulWidget {
  final Habit? habitToEdit;

  const AddHabitSheet({Key? key, this.habitToEdit}) : super(key: key);

  @override
  ConsumerState<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<AddHabitSheet> {
  final _nameController = TextEditingController();
  
  late int _targetDays;
  late Color _selectedColor;
  
  // Advanced Fields
  late List<int> _activeWeekdays;
  late bool _hasMonthlyTarget;

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      _nameController.text = widget.habitToEdit!.name;
      _targetDays = widget.habitToEdit!.targetDays;
      _selectedColor = widget.habitToEdit!.color;
      _activeWeekdays = List.from(widget.habitToEdit!.activeWeekdays);
      _hasMonthlyTarget = widget.habitToEdit!.hasMonthlyTarget;
    } else {
      _targetDays = 20;
      _selectedColor = const Color(0xFF84A59D); // Verde Salvia
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
      _hasMonthlyTarget = true;
    }
  }

  final List<Color> _palette = [
    const Color(0xFF84A59D), // Verde Salvia
    const Color(0xFFB5A6C9), // Azul Lavanda
    const Color(0xFFF2C6B4), // Melocotón Suave
    const Color(0xFFE5D08F), // Mostaza Apagado / Arena
    const Color(0xFF9EA1D4), // Periwinkle
    const Color(0xFFE5989B), // Rosa Empolvado
    const Color(0xFFA8C2D3), // Gris Invierno
  ];

  void _saveHabit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    // Ensure at least one day is selected if not everyday
    if (_activeWeekdays.isEmpty) {
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
    }

    if (widget.habitToEdit != null) {
      final updatedHabit = widget.habitToEdit!.copyWith(
        name: name,
        colorValue: _selectedColor.value,
        targetDays: _targetDays,
        isNumeric: false,
        dailyTarget: 1,
        dailyUnit: '',
        activeWeekdays: _activeWeekdays,
        hasMonthlyTarget: _hasMonthlyTarget,
      );
      ref.read(habitsProvider.notifier).updateHabit(updatedHabit);
    } else {
      final newHabit = Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        colorValue: _selectedColor.value,
        targetDays: _targetDays,
        orderIndex: 0,
        isNumeric: false,
        dailyTarget: 1,
        dailyUnit: '',
        activeWeekdays: _activeWeekdays,
        hasMonthlyTarget: _hasMonthlyTarget,
      );
      ref.read(habitsProvider.notifier).addHabit(newHabit);
    }
    Navigator.pop(context);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 
                MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.habitToEdit != null ? 'Editar Hábito' : 'Nuevo Hábito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayLarge?.color)),
            const SizedBox(height: 16),
            
            // 1. Nombre
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Nombre del hábito (ej. Beber Agua)',
                labelStyle: TextStyle(color: textColor?.withOpacity(0.6)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _selectedColor, width: 2)),
              ),
            ),
            
            // 2. Frecuencia Semanal
            _buildSectionTitle('Frecuencia'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final isSelected = _activeWeekdays.contains(day);
                final dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_activeWeekdays.length > 1) _activeWeekdays.remove(day);
                      } else {
                        _activeWeekdays.add(day);
                      }
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? _selectedColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? _selectedColor : Colors.grey.withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(dayNames[day - 1], style: TextStyle(color: isSelected ? Colors.white : textColor?.withOpacity(0.6), fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),

            // 3. Meta Mensual Opcional
            _buildSectionTitle('Meta Mensual'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Establecer objetivo de días al mes', style: TextStyle(color: textColor)),
              subtitle: Text('Recomendado para medir el éxito a largo plazo.', style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12)),
              activeColor: _selectedColor,
              value: _hasMonthlyTarget,
              onChanged: (val) => setState(() => _hasMonthlyTarget = val),
            ),
            if (_hasMonthlyTarget) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Días objetivo al mes:', style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_targetDays > 1) setState(() => _targetDays--);
                        },
                      ),
                      Text('$_targetDays', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_targetDays < 31) setState(() => _targetDays++);
                        },
                      ),
                    ],
                  )
                ],
              ),
            ],

            // 5. Color
            _buildSectionTitle('Color Visual'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _palette.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Theme.of(context).cardColor, width: 3) : null,
                      boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)] : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Guardar Hábito', style: TextStyle(color: Theme.of(context).cardColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            if (widget.habitToEdit != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Eliminar hábito?'),
                        content: Text('Se perderá todo el historial y las rachas de "${widget.habitToEdit!.name}". Esta acción no se puede deshacer.'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Theme.of(context).cardColor,
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancelar', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      ref.read(habitsProvider.notifier).deleteHabit(widget.habitToEdit!.id);
                      Navigator.pop(context); // Close the sheet
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Eliminar Hábito', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

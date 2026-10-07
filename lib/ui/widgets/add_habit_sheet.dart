import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';

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
  late int _frequencyType;
  late int _targetDaysPerWeek;

  // Schedule Sync Fields
  late bool _addToDailySchedule;
  late TimeOfDay _scheduleStartTime;
  late TimeOfDay _scheduleEndTime;
  late bool _hasMonthlyHourTarget;
  late int _monthlyTargetHours;

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      _nameController.text = widget.habitToEdit!.name;
      _targetDays = widget.habitToEdit!.targetDays;
      _selectedColor = widget.habitToEdit!.color;
      _activeWeekdays = List.from(widget.habitToEdit!.activeWeekdays);
      _hasMonthlyTarget = widget.habitToEdit!.hasMonthlyTarget;
      _frequencyType = widget.habitToEdit!.frequencyType;
      _targetDaysPerWeek = widget.habitToEdit!.targetDaysPerWeek;

      final existingBlocks = ref.read(scheduleProvider);
      final linked = existingBlocks.cast<ScheduleBlock?>().firstWhere(
            (b) => b?.habitId == widget.habitToEdit!.id,
            orElse: () => null,
          );
      if (linked != null) {
        _addToDailySchedule = true;
        _scheduleStartTime = TimeOfDay(hour: linked.startHour, minute: linked.startMinute);
        _scheduleEndTime = TimeOfDay(hour: linked.endHour, minute: linked.endMinute);
        _hasMonthlyHourTarget = linked.hasMonthlyHourTarget;
        _monthlyTargetHours = linked.monthlyTargetHours;
      } else {
        _addToDailySchedule = false;
        _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
        _scheduleEndTime = const TimeOfDay(hour: 9, minute: 0);
        _hasMonthlyHourTarget = false;
        _monthlyTargetHours = 120;
      }
    } else {
      _targetDays = 20;
      _selectedColor = const Color(0xFF84A59D); // Verde Salvia
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
      _hasMonthlyTarget = true;
      _frequencyType = 0;
      _targetDaysPerWeek = 3;
      _addToDailySchedule = false;
      _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
      _scheduleEndTime = const TimeOfDay(hour: 9, minute: 0);
      _hasMonthlyHourTarget = false;
      _monthlyTargetHours = 120;
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

  Future<void> _pickScheduleTime(bool isStart) async {
    final initial = isStart ? _scheduleStartTime : _scheduleEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: _selectedColor,
                  ),
            ),
            child: child ?? const SizedBox(),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _scheduleStartTime = picked;
        } else {
          _scheduleEndTime = picked;
        }
      });
    }
  }

  void _saveHabit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    
    // Ensure at least one day is selected if not everyday
    if (_activeWeekdays.isEmpty) {
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
    }

    final habitId = widget.habitToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

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
        frequencyType: _frequencyType,
        targetDaysPerWeek: _targetDaysPerWeek,
      );
      ref.read(habitsProvider.notifier).updateHabit(updatedHabit);
    } else {
      final newHabit = Habit(
        id: habitId,
        name: name,
        colorValue: _selectedColor.value,
        targetDays: _targetDays,
        orderIndex: 0,
        isNumeric: false,
        dailyTarget: 1,
        dailyUnit: '',
        activeWeekdays: _activeWeekdays,
        hasMonthlyTarget: _hasMonthlyTarget,
        frequencyType: _frequencyType,
        targetDaysPerWeek: _targetDaysPerWeek,
      );
      ref.read(habitsProvider.notifier).addHabit(newHabit);
    }

    // Synchronize Daily Schedule Block
    final currentBlocks = ref.read(scheduleProvider);
    final existingBlockIndex = currentBlocks.indexWhere((b) => b.habitId == habitId);

    if (_addToDailySchedule) {
      final existingBlock = existingBlockIndex != -1 ? currentBlocks[existingBlockIndex] : null;
      final habitDates = widget.habitToEdit?.completedDates ?? <String>{};
      final mergedDates = {
        ...?existingBlock?.completedDates,
        ...habitDates,
      }.toList();

      final scheduleBlock = ScheduleBlock(
        id: existingBlock?.id ?? 'block_$habitId',
        title: name,
        startHour: _scheduleStartTime.hour,
        startMinute: _scheduleStartTime.minute,
        endHour: _scheduleEndTime.hour,
        endMinute: _scheduleEndTime.minute,
        colorValue: _selectedColor.value,
        habitId: habitId,
        daysOfWeek: _frequencyType == 0 ? _activeWeekdays : [1, 2, 3, 4, 5, 6, 7],
        hasMonthlyHourTarget: _hasMonthlyHourTarget,
        monthlyTargetHours: _monthlyTargetHours,
        completedDates: mergedDates,
        extraHours: existingBlock?.extraHours ?? 0.0,
      );

      if (existingBlockIndex != -1) {
        ref.read(scheduleProvider.notifier).updateBlock(scheduleBlock);
      } else {
        ref.read(scheduleProvider.notifier).addBlock(scheduleBlock);
      }
    } else if (existingBlockIndex != -1) {
      ref.read(scheduleProvider.notifier).deleteBlock(currentBlocks[existingBlockIndex].id);
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
            
            // Toggle de tipo de frecuencia
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _frequencyType = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _frequencyType == 0 ? _selectedColor.withOpacity(0.2) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Días Específicos',
                          style: TextStyle(
                            color: _frequencyType == 0 ? _selectedColor : textColor?.withOpacity(0.6),
                            fontWeight: _frequencyType == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.withOpacity(0.3)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _frequencyType = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _frequencyType == 1 ? _selectedColor.withOpacity(0.2) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Veces por Semana',
                          style: TextStyle(
                            color: _frequencyType == 1 ? _selectedColor : textColor?.withOpacity(0.6),
                            fontWeight: _frequencyType == 1 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_frequencyType == 0) ...[
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
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Días por semana:', style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 16)),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_targetDaysPerWeek > 1) setState(() => _targetDaysPerWeek--);
                        },
                      ),
                      Text('$_targetDaysPerWeek', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.add, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_targetDaysPerWeek < 7) setState(() => _targetDaysPerWeek++);
                        },
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'El hábito aparecerá todos los días hasta que cumplas tu objetivo de $_targetDaysPerWeek días en la semana actual.',
                style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
              ),
            ],

            // 3. Horario en Reloj 24h (Opcional)
            _buildSectionTitle('Horario en Reloj 24h (Opcional)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Añadir bloque a mi reloj diario', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Aparecerá en tu horario de 24h y podrás marcarlo desde ambos modos.',
                style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
              ),
              activeColor: _selectedColor,
              value: _addToDailySchedule,
              onChanged: (val) => setState(() => _addToDailySchedule = val),
            ),
            if (_addToDailySchedule) ...[
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickScheduleTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Inicio', style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${_scheduleStartTime.hour.toString().padLeft(2, '0')}:${_scheduleStartTime.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward, color: textColor?.withOpacity(0.3), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickScheduleTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fin', style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '${_scheduleEndTime.hour.toString().padLeft(2, '0')}:${_scheduleEndTime.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Objetivo de horas al mes (Turnos/Trabajo)', style: TextStyle(color: textColor, fontSize: 15)),
                subtitle: Text(
                  'Ideal para turnos rotativos (ej. 120 horas al mes).',
                  style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
                ),
                activeColor: _selectedColor,
                value: _hasMonthlyHourTarget,
                onChanged: (val) => setState(() => _hasMonthlyHourTarget = val),
              ),
              if (_hasMonthlyHourTarget) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Horas al mes:', style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 15)),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                          onPressed: () {
                            if (_monthlyTargetHours > 10) setState(() => _monthlyTargetHours -= 10);
                          },
                        ),
                        Text('$_monthlyTargetHours h', style: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.add, color: textColor?.withOpacity(0.6)),
                          onPressed: () {
                            if (_monthlyTargetHours < 300) setState(() => _monthlyTargetHours += 10);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ],

            // 4. Meta Mensual Opcional
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
                      // Delete any linked schedule block too!
                      final currentBlocks = ref.read(scheduleProvider);
                      for (final b in currentBlocks) {
                        if (b.habitId == widget.habitToEdit!.id) {
                          ref.read(scheduleProvider.notifier).deleteBlock(b.id);
                        }
                      }
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

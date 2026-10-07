import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/schedule_block.dart';
import '../../domain/models/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';

class AddScheduleBlockSheet extends ConsumerStatefulWidget {
  final ScheduleBlock? blockToEdit;

  const AddScheduleBlockSheet({Key? key, this.blockToEdit}) : super(key: key);

  @override
  ConsumerState<AddScheduleBlockSheet> createState() => _AddScheduleBlockSheetState();
}

class _AddScheduleBlockSheetState extends ConsumerState<AddScheduleBlockSheet> {
  final _titleController = TextEditingController();

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Color _selectedColor;
  late List<int> _activeDays;
  String? _selectedHabitId;

  final List<Color> _palette = const [
    Color(0xFF84A59D), // Verde Salvia
    Color(0xFFB5A6C9), // Azul Lavanda
    Color(0xFFF2C6B4), // Melocotón Suave
    Color(0xFFE5D08F), // Mostaza Apagado / Arena
    Color(0xFF9EA1D4), // Periwinkle
    Color(0xFFE5989B), // Rosa Empolvado
    Color(0xFFA8C2D3), // Gris Invierno
  ];

  late bool _hasMonthlyHourTarget;
  late int _monthlyTargetHours;
  late List<String> _completedDates;
  late bool _syncWithOrbit;

  @override
  void initState() {
    super.initState();
    if (widget.blockToEdit != null) {
      final b = widget.blockToEdit!;
      _titleController.text = b.title;
      _startTime = TimeOfDay(hour: b.startHour, minute: b.startMinute);
      _endTime = TimeOfDay(hour: b.endHour, minute: b.endMinute);
      _selectedColor = b.color;
      _activeDays = List.from(b.daysOfWeek);
      _selectedHabitId = b.habitId;
      _syncWithOrbit = b.habitId != null || b.hasMonthlyHourTarget;
      _hasMonthlyHourTarget = b.hasMonthlyHourTarget;
      _monthlyTargetHours = b.monthlyTargetHours;
      final habitDates = <String>{};
      if (b.habitId != null) {
        final habits = ref.read(habitsProvider);
        final linked = habits.cast<Habit?>().firstWhere(
          (h) => h?.id == b.habitId,
          orElse: () => null,
        );
        if (linked != null) habitDates.addAll(linked.completedDates);
      }
      _completedDates = {...b.completedDates, ...habitDates}.toList();
    } else {
      _startTime = const TimeOfDay(hour: 23, minute: 0);
      _endTime = const TimeOfDay(hour: 7, minute: 0);
      _selectedColor = const Color(0xFF9EA1D4);
      _activeDays = [1, 2, 3, 4, 5, 6, 7];
      _selectedHabitId = null;
      _syncWithOrbit = true;
      _hasMonthlyHourTarget = false;
      _monthlyTargetHours = 120;
      _completedDates = [];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _startMinutes => _startTime.hour * 60 + _startTime.minute;
  int get _endMinutes => _endTime.hour * 60 + _endTime.minute;
  bool get _isOvernight => _endMinutes <= _startMinutes;

  int get _durationMinutes {
    if (_isOvernight) {
      return (1440 - _startMinutes) + _endMinutes;
    }
    return _endMinutes - _startMinutes;
  }

  String get _formattedDuration {
    final h = _durationMinutes ~/ 60;
    final m = _durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Future<void> _pickTime(bool isStart) async {
    HapticFeedback.selectionClick();
    final initial = isStart ? _startTime : _endTime;
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
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveBlock() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (_activeDays.isEmpty) {
      _activeDays = [1, 2, 3, 4, 5, 6, 7];
    }

    String? finalHabitId = _selectedHabitId;

    if (_syncWithOrbit) {
      final habits = ref.read(habitsProvider);
      if (finalHabitId != null) {
        final habitIndex = habits.indexWhere((h) => h.id == finalHabitId);
        if (habitIndex != -1) {
          final linkedHabit = habits[habitIndex];
          final updatedDates = {...linkedHabit.completedDates, ..._completedDates};
          ref.read(habitsProvider.notifier).updateHabit(
            linkedHabit.copyWith(
              name: title,
              colorValue: _selectedColor.value,
              completedDates: updatedDates,
              activeWeekdays: _activeDays,
            ),
          );
        }
      } else {
        // Si no seleccionó un hábito específico, buscar coincidencia por nombre o crear uno nuevo
        final existingByName = habits.cast<Habit?>().firstWhere(
              (h) => h != null && h.name.trim().toLowerCase() == title.toLowerCase(),
              orElse: () => null,
            );

        if (existingByName != null) {
          finalHabitId = existingByName.id;
          final updatedDates = {...existingByName.completedDates, ..._completedDates};
          ref.read(habitsProvider.notifier).updateHabit(
            existingByName.copyWith(
              completedDates: updatedDates,
              activeWeekdays: _activeDays,
            ),
          );
        } else {
          // Crear un NUEVO hábito automáticamente en Modo Órbita
          final newHabitId = DateTime.now().millisecondsSinceEpoch.toString();
          final newHabit = Habit(
            id: newHabitId,
            name: title,
            colorValue: _selectedColor.value,
            targetDays: 20,
            orderIndex: habits.length,
            isNumeric: false,
            dailyTarget: 1,
            dailyUnit: '',
            activeWeekdays: _activeDays,
            hasMonthlyTarget: _hasMonthlyHourTarget,
            frequencyType: 0,
            targetDaysPerWeek: 3,
            completedDates: Set<String>.from(_completedDates),
          );
          ref.read(habitsProvider.notifier).addHabit(newHabit);
          finalHabitId = newHabitId;
        }
      }
    }

    final block = ScheduleBlock(
      id: widget.blockToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      startHour: _startTime.hour,
      startMinute: _startTime.minute,
      endHour: _endTime.hour,
      endMinute: _endTime.minute,
      colorValue: _selectedColor.value,
      habitId: finalHabitId,
      daysOfWeek: _activeDays,
      hasMonthlyHourTarget: _hasMonthlyHourTarget,
      monthlyTargetHours: _monthlyTargetHours,
      completedDates: _completedDates,
      extraHours: widget.blockToEdit?.extraHours ?? 0.0,
    );

    if (widget.blockToEdit != null) {
      ref.read(scheduleProvider.notifier).updateBlock(block);
    } else {
      ref.read(scheduleProvider.notifier).addBlock(block);
    }

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 22),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Title
            Text(
              widget.blockToEdit != null ? 'Editar Bloque Horario' : 'Nuevo Bloque Horario',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.displayLarge?.color,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Actividad / Nombre
            TextField(
              controller: _titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Actividad (ej. Trabajo Nocturno, Gym, Dormir)',
                labelStyle: TextStyle(color: textColor?.withOpacity(0.6)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _selectedColor, width: 2),
                ),
              ),
            ),

            // 2. Sincronización con Modo Órbita
            _buildSectionTitle('Sincronización con Modo Órbita'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Mostrar también como hábito en la Órbita',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                'Aparecerá en la rueda orbital y podrás marcar tus días desde ambos modos.',
                style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
              ),
              activeColor: _selectedColor,
              value: _syncWithOrbit,
              onChanged: (val) {
                setState(() {
                  _syncWithOrbit = val;
                  if (!val) {
                    _selectedHabitId = null;
                  }
                });
              },
            ),

            if (_syncWithOrbit && habits.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedHabitId,
                    isExpanded: true,
                    dropdownColor: theme.cardColor,
                    hint: Text(
                      '✨ Crear nuevo hábito automático con este nombre',
                      style: TextStyle(color: textColor?.withOpacity(0.6), fontSize: 13),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '✨ Crear nuevo hábito con este nombre',
                          style: TextStyle(color: _selectedColor, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      ...habits.map((h) {
                        return DropdownMenuItem<String?>(
                          value: h.id,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: h.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Vincular a: ${h.name}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedHabitId = val;
                        if (val != null) {
                          final h = habits.firstWhere((element) => element.id == val);
                          if (_titleController.text.isEmpty) {
                            _titleController.text = h.name;
                          }
                          _selectedColor = h.color;
                          _completedDates = {..._completedDates, ...h.completedDates}.toList();
                        }
                      });
                    },
                  ),
                ),
              ),
            ],

            // 3. Horarios (Inicio & Fin)
            _buildSectionTitle('Horario'),
            Row(
              children: [
                // Hora Inicio
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desde',
                            style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward, color: textColor?.withOpacity(0.3), size: 18),
                const SizedBox(width: 12),
                // Hora Fin
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickTime(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hasta',
                            style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Badge de duración & Aviso de turno nocturno
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isOvernight
                    ? const Color(0xFF9EA1D4).withOpacity(0.12)
                    : _selectedColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOvernight ? Icons.nights_stay : Icons.schedule,
                    size: 16,
                    color: _isOvernight ? const Color(0xFF9EA1D4) : _selectedColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOvernight
                        ? 'Duración: $_formattedDuration · 🌙 Cruza medianoche (Turno nocturno)'
                        : 'Duración: $_formattedDuration',
                    style: TextStyle(
                      color: _isOvernight ? const Color(0xFF9EA1D4) : _selectedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // 4. Meta Mensual de Horas (Turnos / Trabajo de 120h)
            _buildSectionTitle('Objetivo Mensual de Horas (Opcional)'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Establecer objetivo de horas al mes', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Ideal para turnos rotativos (ej. 120h). Lleva la cuenta de horas acumuladas y horas extra.',
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
                  Text('Horas objetivo al mes:',
                      style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 15)),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_monthlyTargetHours > 10) {
                            setState(() => _monthlyTargetHours -= 10);
                          }
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _selectedColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '$_monthlyTargetHours h',
                          style: GoogleFonts.outfit(
                            color: _selectedColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: textColor?.withOpacity(0.6)),
                        onPressed: () {
                          if (_monthlyTargetHours < 300) {
                            setState(() => _monthlyTargetHours += 10);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Selector de días trabajados en este mes
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                  final shiftHours = _durationMinutes / 60.0;
                  final currentMonthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                  final completedThisMonth = _completedDates.where((d) => d.startsWith(currentMonthPrefix)).length;
                  final totalWorkedHours = (completedThisMonth * shiftHours);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Turnos trabajados este mes:',
                            style: TextStyle(
                              color: textColor?.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: _selectedColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$completedThisMonth turnos · ${totalWorkedHours.toStringAsFixed(0)} / ${_monthlyTargetHours}h',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toca los días en los que has hecho turno para registrarlos:',
                        style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(daysInMonth, (index) {
                          final dayNum = index + 1;
                          final dateIso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                          final isWorked = _completedDates.contains(dateIso);
                          final isToday = dayNum == now.day;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (isWorked) {
                                  _completedDates.remove(dateIso);
                                } else {
                                  _completedDates.add(dateIso);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: isWorked ? _selectedColor : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isWorked
                                      ? _selectedColor
                                      : isToday
                                          ? _selectedColor.withOpacity(0.6)
                                          : Colors.grey.withOpacity(0.25),
                                  width: isToday ? 1.8 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$dayNum',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: isWorked || isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isWorked ? Colors.white : textColor?.withOpacity(0.75),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // 5. Días de la semana
            _buildSectionTitle('Días Activos (Repetición semanal)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final isSelected = _activeDays.contains(day);
                final dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        if (_activeDays.length > 1) _activeDays.remove(day);
                      } else {
                        _activeDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? _selectedColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayNames[day - 1],
                      style: TextStyle(
                        color: isSelected ? Colors.white : textColor?.withOpacity(0.6),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // 5. Paleta de Color (Solo si no está vinculado a un hábito)
            if (_selectedHabitId == null) ...[
              _buildSectionTitle('Color Visual'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _palette.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: theme.cardColor, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveBlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Guardar Bloque',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Botón Eliminar si se está editando
            if (widget.blockToEdit != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: theme.cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('¿Eliminar bloque horario?'),
                        content: Text(
                            'Se eliminará "${widget.blockToEdit!.title}" de tu rutina diaria.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: textColor?.withOpacity(0.7)),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(
                                  color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      ref
                          .read(scheduleProvider.notifier)
                          .deleteBlock(widget.blockToEdit!.id);
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  label: const Text(
                    'Eliminar Bloque',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

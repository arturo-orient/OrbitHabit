import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/sound_service.dart';

enum TaskTargetMode {
  none,   // Sin meta fija
  days,   // Meta por días (ej: 20 días al mes o 3 días a la semana)
  hours,  // Meta por horas / turnos (ej: 120 horas al mes)
}

class UnifiedTaskSheet extends ConsumerStatefulWidget {
  final Habit? habitToEdit;
  final ScheduleBlock? blockToEdit;
  final bool defaultEnableSchedule;

  const UnifiedTaskSheet({
    Key? key,
    this.habitToEdit,
    this.blockToEdit,
    this.defaultEnableSchedule = false,
  }) : super(key: key);

  @override
  ConsumerState<UnifiedTaskSheet> createState() => _UnifiedTaskSheetState();
}

class _UnifiedTaskSheetState extends ConsumerState<UnifiedTaskSheet> {
  final _nameController = TextEditingController();

  late Color _selectedColor;

  // 1. Horario en Reloj 24h
  late bool _hasSchedule;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<int> _activeWeekdays;

  // 2. Modos de Meta
  late TaskTargetMode _targetMode;

  // Parámetros de meta por días
  late int _frequencyType; // 0 = Días específicos, 1 = X días por semana
  late int _targetDaysPerWeek;
  late int _targetDays;

  // Parámetros de meta por horas (Trabajo / Turnos)
  late int _monthlyTargetHours;
  late double _extraHours;
  late List<String> _completedDates;

  final List<Color> _palette = const [
    Color(0xFF84A59D), // Verde Salvia
    Color(0xFFB5A6C9), // Azul Lavanda
    Color(0xFFF2C6B4), // Melocotón Suave
    Color(0xFFE5D08F), // Mostaza Apagado / Arena
    Color(0xFF9EA1D4), // Periwinkle
    Color(0xFFE5989B), // Rosa Empolvado
    Color(0xFFA8C2D3), // Gris Invierno
  ];

  @override
  void initState() {
    super.initState();

    final habits = ref.read(habitsProvider);
    final blocks = ref.read(scheduleProvider);

    Habit? habit = widget.habitToEdit;
    ScheduleBlock? block = widget.blockToEdit;

    // Vinculación cruzada inteligente
    if (habit != null && block == null) {
      block = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) =>
                b?.habitId == habit!.id ||
                b?.title.trim().toLowerCase() == habit.name.trim().toLowerCase(),
            orElse: () => null,
          );
    } else if (block != null && habit == null) {
      habit = habits.cast<Habit?>().firstWhere(
            (h) =>
                h?.id == block!.habitId ||
                h?.name.trim().toLowerCase() == block.title.trim().toLowerCase(),
            orElse: () => null,
          );
    }

    if (habit != null || block != null) {
      final title = habit?.name ?? block?.title ?? '';
      _nameController.text = title;
      _selectedColor = habit?.color ?? block?.color ?? const Color(0xFF9EA1D4);

      // Horario
      if (block != null) {
        _hasSchedule = true;
        _startTime = TimeOfDay(hour: block.startHour, minute: block.startMinute);
        _endTime = TimeOfDay(hour: block.endHour, minute: block.endMinute);
        _activeWeekdays = List.from(block.daysOfWeek);
        _extraHours = block.extraHours;
      } else {
        _hasSchedule = false;
        _startTime = const TimeOfDay(hour: 23, minute: 0);
        _endTime = const TimeOfDay(hour: 7, minute: 0);
        _activeWeekdays = habit != null ? List.from(habit.activeWeekdays) : [1, 2, 3, 4, 5, 6, 7];
        _extraHours = 0.0;
      }

      // Fechas completadas unificadas
      final mergedSet = <String>{};
      if (habit != null) mergedSet.addAll(habit.completedDates);
      if (block != null) mergedSet.addAll(block.completedDates);
      _completedDates = mergedSet.toList();

      // Modo de Meta
      if (block != null && block.hasMonthlyHourTarget) {
        _targetMode = TaskTargetMode.hours;
        _monthlyTargetHours = block.monthlyTargetHours;
      } else if (habit != null && habit.hasMonthlyTarget) {
        _targetMode = TaskTargetMode.days;
        _monthlyTargetHours = 120;
      } else {
        _targetMode = TaskTargetMode.none;
        _monthlyTargetHours = 120;
      }

      _frequencyType = habit?.frequencyType ?? 0;
      _targetDaysPerWeek = habit?.targetDaysPerWeek ?? 3;
      _targetDays = habit?.targetDays ?? 20;
    } else {
      // Nueva tarea desde cero
      _selectedColor = const Color(0xFF9EA1D4);
      _hasSchedule = widget.defaultEnableSchedule;
      _startTime = const TimeOfDay(hour: 23, minute: 0);
      _endTime = const TimeOfDay(hour: 7, minute: 0);
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];

      _targetMode = widget.defaultEnableSchedule ? TaskTargetMode.hours : TaskTargetMode.days;
      _frequencyType = 0;
      _targetDaysPerWeek = 3;
      _targetDays = 20;
      _monthlyTargetHours = 120;
      _extraHours = 0.0;
      _completedDates = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.habitToEdit != null || widget.blockToEdit != null;

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

  void _saveTask() {
    final title = _nameController.text.trim();
    if (title.isEmpty) return;

    if (_activeWeekdays.isEmpty) {
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
    }

    final habits = ref.read(habitsProvider);
    final blocks = ref.read(scheduleProvider);

    // 1. Determinar ID de Hábito
    String habitId = widget.habitToEdit?.id ?? widget.blockToEdit?.habitId ?? '';
    if (habitId.isEmpty) {
      final existingByName = habits.cast<Habit?>().firstWhere(
            (h) => h != null && h.name.trim().toLowerCase() == title.toLowerCase(),
            orElse: () => null,
          );
      habitId = existingByName?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    }

    // 2. Determinar ID de Bloque
    String blockId = widget.blockToEdit?.id ?? '';
    if (blockId.isEmpty) {
      final existingBlock = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) =>
                b?.habitId == habitId ||
                b?.title.trim().toLowerCase() == title.toLowerCase(),
            orElse: () => null,
          );
      blockId = existingBlock?.id ?? 'block_$habitId';
    }

    // 3. Guardar / Actualizar Hábito en Modo Órbita
    final isNewHabit = !habits.any((h) => h.id == habitId);
    final habit = Habit(
      id: habitId,
      name: title,
      colorValue: _selectedColor.value,
      targetDays: _targetMode == TaskTargetMode.days ? _targetDays : 20,
      orderIndex: isNewHabit ? habits.length : (widget.habitToEdit?.orderIndex ?? 0),
      isNumeric: false,
      dailyTarget: 1,
      dailyUnit: '',
      activeWeekdays: _activeWeekdays,
      hasMonthlyTarget: _targetMode == TaskTargetMode.days,
      frequencyType: _targetMode == TaskTargetMode.days ? _frequencyType : 0,
      targetDaysPerWeek: _targetDaysPerWeek,
      completedDates: Set<String>.from(_completedDates),
    );

    if (isNewHabit) {
      ref.read(habitsProvider.notifier).addHabit(habit);
    } else {
      ref.read(habitsProvider.notifier).updateHabit(habit);
    }

    // 4. Guardar / Actualizar o Eliminar Bloque en Modo Reloj
    final isNewBlock = !blocks.any((b) => b.id == blockId);
    if (_hasSchedule) {
      final scheduleBlock = ScheduleBlock(
        id: blockId,
        title: title,
        startHour: _startTime.hour,
        startMinute: _startTime.minute,
        endHour: _endTime.hour,
        endMinute: _endTime.minute,
        colorValue: _selectedColor.value,
        habitId: habitId,
        daysOfWeek: _activeWeekdays,
        hasMonthlyHourTarget: _targetMode == TaskTargetMode.hours,
        monthlyTargetHours: _monthlyTargetHours,
        completedDates: _completedDates,
        extraHours: _extraHours,
      );

      if (isNewBlock) {
        ref.read(scheduleProvider.notifier).addBlock(scheduleBlock);
      } else {
        ref.read(scheduleProvider.notifier).updateBlock(scheduleBlock);
      }
    } else if (!isNewBlock) {
      // Si el usuario desactivó el horario y antes tenía bloque, se elimina
      ref.read(scheduleProvider.notifier).deleteBlock(blockId);
    }

    HapticFeedback.mediumImpact();
    SoundService().playCheck();
    Navigator.pop(context);
  }

  Future<void> _deleteTask() async {
    final title = _nameController.text.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Eliminar tarea?'),
        content: Text(
          'Se eliminará "$title" tanto del Modo Órbita como de tu Reloj diario. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final habits = ref.read(habitsProvider);
      final blocks = ref.read(scheduleProvider);

      final habitId = widget.habitToEdit?.id ?? widget.blockToEdit?.habitId;
      if (habitId != null) {
        ref.read(habitsProvider.notifier).deleteHabit(habitId);
      } else if (title.isNotEmpty) {
        final match = habits.cast<Habit?>().firstWhere(
              (h) => h?.name.trim().toLowerCase() == title.toLowerCase(),
              orElse: () => null,
            );
        if (match != null) {
          ref.read(habitsProvider.notifier).deleteHabit(match.id);
        }
      }

      final blockId = widget.blockToEdit?.id;
      if (blockId != null) {
        ref.read(scheduleProvider.notifier).deleteBlock(blockId);
      } else if (habitId != null) {
        final match = blocks.cast<ScheduleBlock?>().firstWhere(
              (b) => b?.habitId == habitId,
              orElse: () => null,
            );
        if (match != null) {
          ref.read(scheduleProvider.notifier).deleteBlock(match.id);
        }
      }

      HapticFeedback.heavyImpact();
      Navigator.pop(context);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 22),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.75),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            18,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arrastrador superior
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Título de la Hoja
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Editar Tarea' : 'Nueva Tarea',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hasSchedule ? 'Órbita + Reloj' : 'Modo Órbita',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Nombre de la Tarea
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Nombre de la tarea',
                hintText: 'ej. Trabajar, Gimnasio, Meditar...',
                hintStyle: TextStyle(color: textColor?.withOpacity(0.35)),
                labelStyle: TextStyle(color: textColor?.withOpacity(0.6)),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _selectedColor, width: 2),
                ),
              ),
            ),

            // 2. Paleta de Color Visual
            _buildSectionTitle('Color Visual'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _palette.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedColor = color);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.cardColor, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: color.withOpacity(0.55), blurRadius: 10, spreadRadius: 1)]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            // 3. Sección: Horario en el Reloj 24h
            _buildSectionTitle('Horario en Reloj 24h (Opcional)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasSchedule
                      ? _selectedColor.withOpacity(0.4)
                      : Colors.grey.withOpacity(0.15),
                ),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Asignar horas en el Reloj 24h',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Se dibujará en tu rutina diaria circular y podrás marcarlo en el reloj.',
                  style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 12),
                ),
                activeColor: _selectedColor,
                value: _hasSchedule,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _hasSchedule = val);
                },
              ),
            ),

            if (_hasSchedule) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Desde
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
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward, color: textColor?.withOpacity(0.3), size: 16),
                  const SizedBox(width: 10),
                  // Hasta
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
              const SizedBox(height: 8),
              // Badge de duración & aviso nocturno
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
                      size: 15,
                      color: _isOvernight ? const Color(0xFF9EA1D4) : _selectedColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOvernight
                          ? '$_formattedDuration · 🌙 Cruza medianoche (Turno nocturno)'
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
            ],

            // 4. Días de la Semana Activos (Repetición)
            _buildSectionTitle('Días de la Semana (Repetición habitual)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                final isSelected = _activeWeekdays.contains(day);
                final dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        if (_activeWeekdays.length > 1) _activeWeekdays.remove(day);
                      } else {
                        _activeWeekdays.add(day);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? _selectedColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.grey.withOpacity(0.25),
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

            // 5. Tipo de Medición / Meta (Pastillas Selectoras)
            _buildSectionTitle('Tipo de Meta / Seguimiento'),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  _buildTabOption(TaskTargetMode.none, '⚪ Sin meta'),
                  _buildTabOption(TaskTargetMode.days, '📅 Por Días'),
                  _buildTabOption(TaskTargetMode.hours, '💼 Por Horas'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6. Sub-panel según tipo de meta
            if (_targetMode == TaskTargetMode.days) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Días objetivo al mes:', style: TextStyle(color: textColor?.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                              onPressed: () {
                                if (_targetDays > 1) setState(() => _targetDays--);
                              },
                            ),
                            Text('$_targetDays días', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
                ),
              ),
            ] else if (_targetMode == TaskTargetMode.hours) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contador de Horas Meta
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Objetivo al mes:',
                          style: TextStyle(
                            color: textColor?.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                              onPressed: () {
                                if (_monthlyTargetHours > 10) {
                                  setState(() => _monthlyTargetHours -= 10);
                                }
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _selectedColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$_monthlyTargetHours h',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: textColor?.withOpacity(0.6)),
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
                    const Divider(height: 20),

                    // Horas Extra
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Horas extra acumuladas:',
                          style: TextStyle(color: textColor?.withOpacity(0.7), fontSize: 13),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, color: textColor?.withOpacity(0.6)),
                              onPressed: () {
                                if (_extraHours > 0) {
                                  setState(() => _extraHours = (_extraHours - 1.0).clamp(0.0, 300.0));
                                }
                              },
                            ),
                            Text(
                              '+${_extraHours.toStringAsFixed(0)} h',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, color: textColor?.withOpacity(0.6)),
                              onPressed: () {
                                setState(() => _extraHours += 1.0);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Selector de días trabajados en el mes actual (1..31)
                    Builder(
                      builder: (context) {
                        final now = DateTime.now();
                        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                        final shiftHours = _durationMinutes / 60.0;
                        final currentMonthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                        final completedThisMonth = _completedDates.where((d) => d.startsWith(currentMonthPrefix)).length;
                        final totalWorkedHours = (completedThisMonth * shiftHours) + _extraHours;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Turnos este mes:',
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
                              'Toca los días en los que has hecho turno:',
                              style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11),
                            ),
                            const SizedBox(height: 10),
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
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Botón Principal Guardar
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _isEditing ? 'Guardar Cambios' : 'Crear Tarea',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Botón Eliminar si se está editando
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _deleteTask,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Eliminar Tarea',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabOption(TaskTargetMode mode, String label) {
    final isSelected = _targetMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _targetMode = mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/sound_service.dart';
import '../theme/app_theme.dart';
import 'custom_color_picker_dialog.dart';

enum TaskTargetMode {
  none,   // Sin meta fija
  days,   // Meta por días (ej: 20 días al mes o 3 días a la semana)
  hours,  // Meta por horas / turnos (ej: 120 horas al mes)
}

class _ScheduleItem {
  String id;
  String title;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _ScheduleItem({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
  });

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;
  bool get isOvernight => endMinutes <= startMinutes;

  int get durationMinutes {
    if (isOvernight) {
      return (1440 - startMinutes) + endMinutes;
    }
    return endMinutes - startMinutes;
  }

  String get formattedDuration {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get formattedRange {
    final sH = startTime.hour.toString().padLeft(2, '0');
    final sM = startTime.minute.toString().padLeft(2, '0');
    final eH = endTime.hour.toString().padLeft(2, '0');
    final eM = endTime.minute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }
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
  String? _nameError;

  late Color _selectedColor;

  // 1. Visibilidad y Modos
  late bool _hasSchedule;
  late bool _showInOrbit;
  String? _linkedHabitId; // ID de hábito existente vinculado (para múltiples turnos)

  // 2. Horario en Reloj 24h
  final List<_ScheduleItem> _schedules = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late List<int> _activeWeekdays;

  // 3. Modos de Meta
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
    Color(0xFFEF4444), // Rojo Carmín
    Color(0xFFF97316), // Coral Mandarina
    Color(0xFFF59E0B), // Ámbar Cálido
    Color(0xFFEAB308), // Oro Mostaza
    Color(0xFF10B981), // Verde Esmeralda
    Color(0xFF84A59D), // Verde Salvia Zen
    Color(0xFF06B6D4), // Cian Turquesa
    Color(0xFF2563EB), // Azul Cobalto
    Color(0xFF6366F1), // Índigo Eléctrico
    Color(0xFF8B5CF6), // Púrpura Zen
    Color(0xFF9EA1D4), // Lavanda Periwinkle
    Color(0xFFE5989B), // Rosa Empolvado
  ];

  @override
  void initState() {
    super.initState();

    final habits = ref.read(habitsProvider);
    final blocks = ref.read(scheduleProvider);

    Habit? habit = widget.habitToEdit;
    ScheduleBlock? block = widget.blockToEdit;

    // Vinculación cruzada por ID explícito
    if (habit != null && block == null) {
      block = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) => b?.habitId == habit!.id,
            orElse: () => null,
          );
    } else if (block != null && habit == null && block.habitId != null) {
      habit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == block!.habitId,
            orElse: () => null,
          );
    }

    if (habit != null || block != null) {
      final title = habit?.name ?? block?.title ?? '';
      _nameController.text = title;
      _selectedColor = habit?.color ?? block?.color ?? const Color(0xFF9EA1D4);

      // Visibilidad y Modos
      _hasSchedule = block != null;
      _showInOrbit = habit != null;
      _linkedHabitId = (habit != null) ? null : block?.habitId;

      // Horario y Franjas asociadas
      if (habit != null) {
        final related = blocks.where((b) => b.habitId == habit!.id || b.title.trim().toLowerCase() == habit!.name.trim().toLowerCase()).toList();
        for (final b in related) {
          _schedules.add(_ScheduleItem(
            id: b.id,
            title: b.title,
            startTime: TimeOfDay(hour: b.startHour, minute: b.startMinute),
            endTime: TimeOfDay(hour: b.endHour, minute: b.endMinute),
          ));
        }
        if (_schedules.isNotEmpty) {
          _hasSchedule = true;
        }
      } else if (block != null) {
        _schedules.add(_ScheduleItem(
          id: block.id,
          title: block.title,
          startTime: TimeOfDay(hour: block.startHour, minute: block.startMinute),
          endTime: TimeOfDay(hour: block.endHour, minute: block.endMinute),
        ));
      }

      if (block != null) {
        _startTime = TimeOfDay(hour: block.startHour, minute: block.startMinute);
        _endTime = TimeOfDay(hour: block.endHour, minute: block.endMinute);
        _activeWeekdays = List.from(block.daysOfWeek);
        _extraHours = block.extraHours;
      } else {
        _startTime = null;
        _endTime = null;
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
      _showInOrbit = !widget.defaultEnableSchedule; // Si se crea desde el reloj, puede ser solo guía

      _startTime = widget.defaultEnableSchedule ? const TimeOfDay(hour: 8, minute: 0) : null;
      _endTime = widget.defaultEnableSchedule ? const TimeOfDay(hour: 16, minute: 0) : null;
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

  bool get _hasSelectedTimes => _startTime != null && _endTime != null;
  int get _startMinutes => _startTime != null ? (_startTime!.hour * 60 + _startTime!.minute) : 0;
  int get _endMinutes => _endTime != null ? (_endTime!.hour * 60 + _endTime!.minute) : 0;
  bool get _isOvernight => _hasSelectedTimes && (_endMinutes <= _startMinutes);

  int get _durationMinutes {
    if (!_hasSelectedTimes) return 0;
    if (_isOvernight) {
      return (1440 - _startMinutes) + _endMinutes;
    }
    return _endMinutes - _startMinutes;
  }

  String get _formattedDuration {
    if (!_hasSelectedTimes) return '--';
    final h = _durationMinutes ~/ 60;
    final m = _durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Future<void> _pickTime(bool isStart) async {
    HapticFeedback.selectionClick();
    final initial = (isStart ? _startTime : _endTime) ?? TimeOfDay.now();
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

  Future<void> _showAddScheduleDialog() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parentTaskName = _nameController.text.trim();

    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);

    if (_startTime != null && _endTime != null && _schedules.isEmpty) {
      startTime = _startTime!;
      endTime = _endTime!;
    }

    final scheduleTitleController = TextEditingController(
      text: _schedules.isEmpty && parentTaskName.isNotEmpty ? parentTaskName : '',
    );

    final result = await showDialog<_ScheduleItem>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final startM = startTime.hour * 60 + startTime.minute;
            final endM = endTime.hour * 60 + endTime.minute;
            final isOvernight = endM <= startM;
            final durationM = isOvernight ? (1440 - startM) + endM : endM - startM;
            final durH = durationM ~/ 60;
            final durMin = durationM % 60;
            final durationStr = durH > 0 && durMin > 0
                ? '${durH}h ${durMin}m'
                : durH > 0
                    ? '${durH}h'
                    : '${durMin}m';

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                        width: AppTheme.borderPrecision,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Añadir Horario',
                              style: AppTheme.displayStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(dialogContext),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Configura una franja horaria para esta actividad.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Nombre de la franja / horario
                        Text(
                          'NOMBRE DEL HORARIO (OPCIONAL)',
                          style: AppTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: scheduleTitleController,
                          style: TextStyle(
                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ej. Mañana, Tarde, Bloque 1...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: AppTheme.radiusSm,
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppTheme.radiusSm,
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppTheme.radiusSm,
                              borderSide: BorderSide(
                                color: _selectedColor,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Horas: Desde / Hasta
                        Text(
                          'HORAS',
                          style: AppTheme.monoStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Desde
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final p = await showTimePicker(
                                    context: context,
                                    initialTime: startTime,
                                    builder: (context, child) => MediaQuery(
                                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _selectedColor),
                                        ),
                                        child: child ?? const SizedBox(),
                                      ),
                                    ),
                                  );
                                  if (p != null) {
                                    setDialogState(() => startTime = p);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                                    borderRadius: AppTheme.radiusSm,
                                    border: Border.all(
                                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                      width: AppTheme.borderPrecision,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Desde',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                        style: AppTheme.monoStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                            const SizedBox(width: 8),
                            // Hasta
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final p = await showTimePicker(
                                    context: context,
                                    initialTime: endTime,
                                    builder: (context, child) => MediaQuery(
                                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: Theme.of(context).colorScheme.copyWith(primary: _selectedColor),
                                        ),
                                        child: child ?? const SizedBox(),
                                      ),
                                    ),
                                  );
                                  if (p != null) {
                                    setDialogState(() => endTime = p);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                                    borderRadius: AppTheme.radiusSm,
                                    border: Border.all(
                                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                      width: AppTheme.borderPrecision,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hasta',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                        style: AppTheme.monoStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
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

                        // Duración badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOvernight ? const Color(0xFF9EA1D4).withValues(alpha: 0.14) : _selectedColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOvernight ? const Color(0xFF9EA1D4).withValues(alpha: 0.3) : _selectedColor.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOvernight ? Icons.nights_stay_rounded : Icons.schedule_rounded,
                                size: 13,
                                color: isOvernight ? const Color(0xFF9EA1D4) : _selectedColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Duración: $durationStr${isOvernight ? ' · 🌙 Cruza medianoche' : ''}',
                                style: AppTheme.monoStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOvernight ? const Color(0xFF9EA1D4) : _selectedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                  side: BorderSide(
                                    color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                    width: AppTheme.borderPrecision,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final titleText = scheduleTitleController.text.trim();
                                  final finalTitle = titleText.isNotEmpty
                                      ? titleText
                                      : (parentTaskName.isNotEmpty ? parentTaskName : 'Horario');
                                  Navigator.pop(
                                    dialogContext,
                                    _ScheduleItem(
                                      id: 'block_${DateTime.now().millisecondsSinceEpoch}_${_schedules.length}',
                                      title: finalTitle,
                                      startTime: startTime,
                                      endTime: endTime,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                                child: const Text(
                                  'Añadir Horario',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    scheduleTitleController.dispose();

    if (result != null && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _schedules.add(result);
        _hasSchedule = true;
      });
    }
  }

  void _saveTask() {
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.vibrate();
      setState(() {
        _nameError = 'Introduce un nombre para la tarea';
      });
      return;
    }

    final habits = ref.read(habitsProvider);
    final blocks = ref.read(scheduleProvider);

    // 1. Identificadores si estamos editando
    final editingHabitId = widget.habitToEdit?.id ?? widget.blockToEdit?.habitId;
    final editingBlockId = widget.blockToEdit?.id;

    // 2. Validación de Duplicados: proteger contra sobreescritura y colisión de nombres
    if (_showInOrbit && _linkedHabitId == null) {
      final duplicateHabit = habits.cast<Habit?>().firstWhere(
            (h) =>
                h != null &&
                h.id != editingHabitId &&
                h.name.trim().toLowerCase() == title.toLowerCase(),
            orElse: () => null,
          );
      if (duplicateHabit != null) {
        HapticFeedback.vibrate();
        setState(() {
          _nameError = 'Ya existe un hábito llamado "$title"';
        });
        return;
      }
    }

    if (_hasSchedule) {
      if (_startTime == null || _endTime == null) {
        // Si NO está en la órbita ni vinculado a nada, sí es obligatorio indicar horas para el reloj
        if (!_showInOrbit && _linkedHabitId == null) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Selecciona las horas en el reloj o activa el Modo Órbita.',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
          return;
        }
        // Si está en la órbita, permitimos guardar sin horas fijas para crearle turnos específicos después!
      } else if (_startTime!.hour == _endTime!.hour && _startTime!.minute == _endTime!.minute) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFE11D48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Text(
              'La hora de inicio y fin no pueden ser idénticas.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
        return;
      }

      final duplicateBlock = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) =>
                b != null &&
                b.id != editingBlockId &&
                b.title.trim().toLowerCase() == title.toLowerCase(),
            orElse: () => null,
          );
      if (duplicateBlock != null) {
        HapticFeedback.vibrate();
        setState(() {
          _nameError = 'Ya existe un bloque llamado "$title" en el reloj';
        });
        return;
      }
    }

    if (_activeWeekdays.isEmpty) {
      _activeWeekdays = [1, 2, 3, 4, 5, 6, 7];
    }

    // IDs finales: si es nuevo, se genera un ID estrictamente único con timestamp y aleatorio
    final targetHabitId = editingHabitId ?? _linkedHabitId ?? 'habit_${DateTime.now().millisecondsSinceEpoch}';
    final blockId = editingBlockId ?? 'block_${DateTime.now().millisecondsSinceEpoch}';

    // 3. Manejo de Modo Órbita (Rueda de Hábitos)
    if (_showInOrbit || _linkedHabitId != null) {
      final existingHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == targetHabitId,
            orElse: () => null,
          );

      if (existingHabit != null) {
        final updatedHabit = existingHabit.copyWith(
          name: title,
          colorValue: _selectedColor.value,
          targetDays: _targetMode == TaskTargetMode.days ? _targetDays : existingHabit.targetDays,
          activeWeekdays: _activeWeekdays,
          hasMonthlyTarget: _targetMode == TaskTargetMode.days,
          frequencyType: _targetMode == TaskTargetMode.days ? _frequencyType : existingHabit.frequencyType,
          targetDaysPerWeek: _targetDaysPerWeek,
        );
        ref.read(habitsProvider.notifier).updateHabit(updatedHabit);
      } else if (_showInOrbit) {
        final habit = Habit(
          id: targetHabitId,
          name: title,
          colorValue: _selectedColor.value,
          targetDays: _targetMode == TaskTargetMode.days ? _targetDays : 20,
          orderIndex: widget.habitToEdit?.orderIndex ?? habits.length,
          isNumeric: false,
          dailyTarget: 1,
          dailyUnit: '',
          activeWeekdays: _activeWeekdays,
          hasMonthlyTarget: _targetMode == TaskTargetMode.days,
          frequencyType: _targetMode == TaskTargetMode.days ? _frequencyType : 0,
          targetDaysPerWeek: _targetDaysPerWeek,
          completedDates: Set<String>.from(_completedDates),
        );
        ref.read(habitsProvider.notifier).addHabit(habit);
      }
    } else if (widget.habitToEdit != null && editingHabitId != null && !_showInOrbit) {
      // Solo si el usuario estaba editando un hábito directamente y decide quitarlo de la órbita
      ref.read(habitsProvider.notifier).deleteHabit(editingHabitId);
    }

    // 4. Manejo de Modo Reloj 24h
    if (_hasSchedule) {
      final finalHabitId = _linkedHabitId ?? (_showInOrbit ? targetHabitId : null);
      final hasHourTarget = (_showInOrbit && _targetMode == TaskTargetMode.hours) ||
          (_linkedHabitId != null &&
              (habits.cast<Habit?>().firstWhere((h) => h?.id == _linkedHabitId, orElse: () => null)?.hasMonthlyTarget ?? false));

      // Guardar todos los horarios definidos en la lista _schedules:
      for (final s in _schedules) {
        final existingBlock = blocks.cast<ScheduleBlock?>().firstWhere(
              (b) => b?.id == s.id,
              orElse: () => null,
            );
        final isNew = existingBlock == null;
        final scheduleBlock = ScheduleBlock(
          id: s.id,
          title: s.title,
          startHour: s.startTime.hour,
          startMinute: s.startTime.minute,
          endHour: s.endTime.hour,
          endMinute: s.endTime.minute,
          colorValue: _selectedColor.value,
          habitId: finalHabitId,
          daysOfWeek: _activeWeekdays,
          hasMonthlyHourTarget: hasHourTarget,
          monthlyTargetHours: _monthlyTargetHours,
          completedDates: existingBlock?.completedDates ?? _completedDates,
          assignedDates: existingBlock?.assignedDates ?? (widget.blockToEdit?.id == s.id ? widget.blockToEdit!.assignedDates : const []),
          extraHours: existingBlock?.extraHours ?? _extraHours,
        );

        if (isNew) {
          ref.read(scheduleProvider.notifier).addBlock(scheduleBlock);
        } else {
          ref.read(scheduleProvider.notifier).updateBlock(scheduleBlock);
        }
      }

      if (_schedules.isNotEmpty) {
        // Si antes había un bloque individual genérico y ahora se usan franjas múltiples, eliminar el genérico viejo para que no choquen horas:
        if (editingBlockId != null && !_schedules.any((s) => s.id == editingBlockId)) {
          ref.read(scheduleProvider.notifier).deleteBlock(editingBlockId);
        }
      } else {
        // Si no se usó la lista de franjas, guardar el horario base único (con fallback seguro a 08:00 - 16:00):
        final start = _startTime ?? const TimeOfDay(hour: 8, minute: 0);
        final end = _endTime ?? const TimeOfDay(hour: 16, minute: 0);
        final isNewBlock = !blocks.any((b) => b.id == blockId);
        final scheduleBlock = ScheduleBlock(
          id: blockId,
          title: title,
          startHour: start.hour,
          startMinute: start.minute,
          endHour: end.hour,
          endMinute: end.minute,
          colorValue: _selectedColor.value,
          habitId: finalHabitId,
          daysOfWeek: _activeWeekdays,
          hasMonthlyHourTarget: hasHourTarget,
          monthlyTargetHours: _monthlyTargetHours,
          completedDates: _completedDates,
          assignedDates: widget.blockToEdit?.assignedDates ?? [],
          extraHours: _extraHours,
        );

        if (isNewBlock) {
          ref.read(scheduleProvider.notifier).addBlock(scheduleBlock);
        } else {
          ref.read(scheduleProvider.notifier).updateBlock(scheduleBlock);
        }
      }
    } else {
      // Si el horario está desactivado, limpiar bloques asociados
      for (final s in _schedules) {
        ref.read(scheduleProvider.notifier).deleteBlock(s.id);
      }
      if (editingBlockId != null) {
        ref.read(scheduleProvider.notifier).deleteBlock(editingBlockId);
      }
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
          'Se eliminará "$title" de OrbitHabit. Esta acción no se puede deshacer.',
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
      }

      final blockId = widget.blockToEdit?.id;
      // Borrar en cascada todos los bloques asociados por habitId, por blockId o por título coincidente
      for (final b in blocks) {
        if ((habitId != null && b.habitId == habitId) ||
            b.id == blockId ||
            (title.isNotEmpty && b.title.trim().toLowerCase() == title.toLowerCase())) {
          ref.read(scheduleProvider.notifier).deleteBlock(b.id);
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
    final habits = ref.watch(habitsProvider);

    String modeBadgeText = 'Modo Órbita';
    if (_linkedHabitId != null) {
      modeBadgeText = 'Horario Vinculado';
    } else if (_hasSchedule && _showInOrbit) {
      modeBadgeText = 'Órbita + Reloj';
    } else if (_hasSchedule && !_showInOrbit) {
      modeBadgeText = 'Solo Reloj (Guía)';
    }

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(
          color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
          width: AppTheme.borderPrecision,
        ),
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
                        modeBadgeText,
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
              onChanged: (val) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Nombre de la tarea',
                hintText: 'ej. Trabajar, Dormir, Gimnasio...',
                errorText: _nameError,
                errorStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
                hintStyle: TextStyle(color: textColor?.withOpacity(0.35)),
                labelStyle: TextStyle(
                  color: _nameError != null ? Colors.redAccent : textColor?.withOpacity(0.6),
                ),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _nameError != null ? Colors.redAccent : Colors.grey.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _nameError != null ? Colors.redAccent : _selectedColor,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
            ),

            // 2. Paleta de Color Visual
            _buildSectionTitle('Color Visual'),
            Builder(
              builder: (context) {
                // ignore: deprecated_member_use
                final isCustomSelected = !_palette.any((c) => (c.value & 0x00FFFFFF) == (_selectedColor.value & 0x00FFFFFF));
                final isDark = theme.brightness == Brightness.dark;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._palette.map((color) {
                      // ignore: deprecated_member_use
                      final isSelected = (color.value & 0x00FFFFFF) == (_selectedColor.value & 0x00FFFFFF);
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
                          alignment: Alignment.center,
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
                              : null,
                        ),
                      );
                    }),

                    // Botón de Color Personalizado
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final picked = await CustomColorPickerDialog.show(context, _selectedColor);
                        if (picked != null) {
                          setState(() => _selectedColor = picked);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCustomSelected
                              ? _selectedColor
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                          shape: BoxShape.circle,
                          border: isCustomSelected
                              ? Border.all(color: theme.cardColor, width: 3)
                              : Border.all(
                                  color: isDark ? Colors.white30 : Colors.black26,
                                  width: 1.5,
                                ),
                          boxShadow: isCustomSelected
                              ? [BoxShadow(color: _selectedColor.withOpacity(0.55), blurRadius: 10, spreadRadius: 1)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: isCustomSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 19)
                            : Icon(
                                Icons.colorize_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // 3. Sección: Visibilidad y Modos (¿Dónde se muestra?)
            _buildSectionTitle('Visibilidad y Modos'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Text('⏰ ', style: TextStyle(fontSize: 16)),
                        Text(
                          'Reloj 24h (Rutina diaria)',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Se dibuja en tu reloj circular de 24 horas con horario fijo.',
                      style: TextStyle(color: textColor?.withOpacity(0.5), fontSize: 11.5),
                    ),
                    activeColor: _selectedColor,
                    value: _hasSchedule,
                    onChanged: (val) {
                      if (!val && !_showInOrbit) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La tarea debe aparecer al menos en el Reloj o en la Órbita.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      setState(() {
                        _hasSchedule = val;
                        if (val && _startTime == null && _endTime == null && _schedules.isEmpty) {
                          _startTime = const TimeOfDay(hour: 8, minute: 0);
                          _endTime = const TimeOfDay(hour: 16, minute: 0);
                        }
                      });
                    },
                  ),
                  const Divider(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        const Text('🪐 ', style: TextStyle(fontSize: 16)),
                        Text(
                          'Modo Órbita (Rueda de hábitos)',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      _showInOrbit
                          ? 'Crea un anillo en la rueda para trackear días y rachas.'
                          : 'Desactivado: Bloque guía para el reloj (ej. Dormir / Descanso).',
                      style: TextStyle(
                        color: _showInOrbit
                            ? textColor?.withOpacity(0.5)
                            : const Color(0xFFE5989B),
                        fontSize: 11.5,
                      ),
                    ),
                    activeColor: _selectedColor,
                    value: _showInOrbit,
                    onChanged: (val) {
                      if (!val && !_hasSchedule) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La tarea debe aparecer al menos en el Reloj o en la Órbita.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showInOrbit = val;
                        if (!val) {
                          _targetMode = TaskTargetMode.none;
                        }
                      });
                    },
                  ),
                  if (_hasSchedule && habits.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildHabitLinkSelector(habits, textColor, isDark),
                  ],
                ],
              ),
            ),

            // 4. Sección Horario (Solo si _hasSchedule está activado)
            if (_hasSchedule) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('Horarios en el Reloj 24h'),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: _showAddScheduleDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _selectedColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, size: 14, color: _selectedColor),
                            const SizedBox(width: 4),
                            Text(
                              'Añadir Horario',
                              style: TextStyle(
                                color: _selectedColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Lista de Franjas configuradas
              if (_schedules.isNotEmpty) ...[
                ..._schedules.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: AppTheme.bentoCard(
                      isLight: !isDark,
                      borderRadius: AppTheme.radiusSm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: AppTheme.displayStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                ),
                              ),
                              Text(
                                '${item.formattedRange} · ${item.formattedDuration}${item.isOvernight ? ' · 🌙 Nocturno' : ''}',
                                style: AppTheme.monoStyle(
                                  fontSize: 10.5,
                                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _schedules.remove(item));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 6),
              ] else ...[
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
                                _startTime != null
                                    ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                    : '--:--',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _startTime != null ? textColor : textColor?.withOpacity(0.35),
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
                                _endTime != null
                                    ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                    : '--:--',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _endTime != null ? textColor : textColor?.withOpacity(0.35),
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
                if (_hasSelectedTimes) ...[
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
                              ? '$_formattedDuration · 🌙 Cruza medianoche (Nocturno)'
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
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 15,
                          color: textColor?.withOpacity(0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Toca "Desde" y "Hasta" o pulsa "Añadir Horario" para crear variantes',
                          style: TextStyle(
                            color: textColor?.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],

            // 5. Días de la Semana Activos (Repetición)
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

            // 6. Tipo de Medición / Meta (Solo visible si está activo en Modo Órbita)
            if (_showInOrbit) ...[
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

              // Sub-panel según tipo de meta
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
                              ),
                              Text(
                                '$_monthlyTargetHours h',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedColor,
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
                                    'Sesiones este mes:',
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
                                      '$completedThisMonth sesiones · ${totalWorkedHours.toStringAsFixed(0)} / ${_monthlyTargetHours}h',
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
                                'Toca los días en los que has completado el horario:',
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

  Widget _buildHabitLinkSelector(List<Habit> habits, Color? textColor, bool isDark) {
    Habit? linkedHabit;
    if (_linkedHabitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere((h) => h?.id == _linkedHabitId, orElse: () => null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vincular a un Hábito Existente',
              style: TextStyle(
                color: textColor?.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (linkedHabit != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _linkedHabitId = null;
                    _showInOrbit = true;
                  });
                },
                child: Text(
                  'Desvincular',
                  style: TextStyle(
                    color: Colors.redAccent.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          linkedHabit != null
              ? 'Este horario sumará automáticamente al objetivo de "${linkedHabit.name}".'
              : 'Selecciona si este horario es una variante de un hábito existente:',
          style: TextStyle(
            color: linkedHabit != null ? AppTheme.dynamicAccent(isDark) : textColor?.withOpacity(0.5),
            fontSize: 11.5,
            fontWeight: linkedHabit != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Chip: Nuevo independiente
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _linkedHabitId = null;
                    _showInOrbit = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _linkedHabitId == null
                        ? (isDark ? Colors.white24 : Colors.black12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _linkedHabitId == null
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : (isDark ? Colors.white24 : Colors.black12),
                      width: _linkedHabitId == null ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    '➕ Hábito independiente',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11.5,
                      fontWeight: _linkedHabitId == null ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Chips de hábitos existentes
              ...habits.map((h) {
                final isSelected = _linkedHabitId == h.id;
                final habitColor = h.color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected) {
                          _linkedHabitId = null;
                          _showInOrbit = true;
                        } else {
                          _linkedHabitId = h.id;
                          _selectedColor = habitColor;
                          _showInOrbit = false; // Ya está en la órbita a través de su hábito
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? habitColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? habitColor
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: habitColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            h.name,
                            style: TextStyle(
                              color: isSelected ? habitColor : textColor,
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_rounded, size: 13, color: habitColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

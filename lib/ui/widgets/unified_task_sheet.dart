import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/notification_service.dart';
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
  final bool isTourMode;

  const UnifiedTaskSheet({
    Key? key,
    this.habitToEdit,
    this.blockToEdit,
    this.defaultEnableSchedule = false,
    this.isTourMode = false,
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

  // Subtareas / Pasos (Checklist)
  final List<SubTask> _subTasks = [];

  // 2. Horario en Reloj 24h
  final List<_ScheduleItem> _schedules = [];
  final Set<String> _deletedScheduleIds = {};
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
  List<String> _assignedDates = [];
  bool _didSyncAssignedDates = false;
  DateTime? _calendarMonth;

  // 4. Recordatorios personalizados por tarea / turno
  bool _hasReminder = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  int _reminderOffsetMinutes = 15;

  // Estado del sub-tour guiado paso a paso dentro del creador de tareas (3-B, 3-C, 3-D, 3-E)
  int _tourSubStep = 0;
  final GlobalKey _tourIdentitySectionKey = GlobalKey(debugLabel: 'sheet_tour_identity');
  final GlobalKey _tourSubtasksSectionKey = GlobalKey(debugLabel: 'sheet_tour_subtasks');
  final GlobalKey _tourVisibilitySectionKey = GlobalKey(debugLabel: 'sheet_tour_visibility');
  final GlobalKey _tourTargetSectionKey = GlobalKey(debugLabel: 'sheet_tour_target');

  void _goToTourSubStep(int nextStep) {
    HapticFeedback.selectionClick();
    final clamped = nextStep.clamp(0, 3);
    setState(() {
      _tourSubStep = clamped;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final keys = [
        _tourIdentitySectionKey,
        _tourSubtasksSectionKey,
        _tourSectionVisibilityOrFallbackKey,
        _tourTargetSectionKey,
      ];
      final targetContext = keys[clamped].currentContext;
      if (targetContext != null) {
        try {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: 0.12,
          );
        } catch (_) {}
      }
    });
  }

  GlobalKey get _tourSectionVisibilityOrFallbackKey => _tourVisibilitySectionKey;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _weekdaysShort = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

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

    // Vinculación cruzada por ID explícito o por nombre coincidente
    if (habit != null && block == null) {
      block = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) =>
                b != null &&
                (b.habitId == habit!.id ||
                    b.title.trim().toLowerCase() == habit.name.trim().toLowerCase()),
            orElse: () => null,
          );
    } else if (block != null && habit == null) {
      habit = habits.cast<Habit?>().firstWhere(
            (h) =>
                h != null &&
                ((block!.habitId != null && h.id == block.habitId) ||
                    h.name.trim().toLowerCase() == block.title.trim().toLowerCase()),
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
      if (widget.blockToEdit != null && widget.blockToEdit!.habitId != null) {
        _linkedHabitId = widget.blockToEdit!.habitId;
      } else if (widget.habitToEdit != null) {
        _linkedHabitId = widget.habitToEdit!.id;
      } else if (block?.habitId != null) {
        _linkedHabitId = block!.habitId;
      } else {
        _linkedHabitId = null;
      }

      // Horario y Franjas asociadas
      if (habit != null) {
        _subTasks.addAll(habit.subTasks);
        final h = habit;
        final related = blocks.where((b) => b.habitId == h.id || b.title.trim().toLowerCase() == h.name.trim().toLowerCase()).toList();
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
          _linkedHabitId = habit.id;
        }
      } else if (block != null) {
        final blk = block;
        final related = blocks.where((b) =>
            b.id == blk.id ||
            (blk.habitId != null && b.habitId == blk.habitId) ||
            (b.title.trim().toLowerCase() == blk.title.trim().toLowerCase())).toList();
        for (final b in related) {
          if (!_schedules.any((s) => s.id == b.id)) {
            _schedules.add(_ScheduleItem(
              id: b.id,
              title: b.title,
              startTime: TimeOfDay(hour: b.startHour, minute: b.startMinute),
              endTime: TimeOfDay(hour: b.endHour, minute: b.endMinute),
            ));
          }
        }
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

      // Fechas completadas y asignadas unificadas desde el Calendario General
      final todayIso = DateTime.now().toIso8601String().split('T').first;
      final mergedCompletedSet = <String>{};
      final mergedAssignedSet = <String>{};
      if (habit != null) {
        mergedCompletedSet.addAll(habit.completedDates);
      }
      if (block != null) {
        mergedCompletedSet.addAll(block.completedDates);
        mergedAssignedSet.addAll(block.assignedDates);
        for (final d in block.assignedDates) {
          if (d.compareTo(todayIso) < 0) mergedCompletedSet.add(d);
        }
      }
      for (final s in _schedules) {
        final b = blocks.cast<ScheduleBlock?>().firstWhere(
              (blk) => blk?.id == s.id,
              orElse: () => null,
            );
        if (b != null) {
          mergedCompletedSet.addAll(b.completedDates);
          mergedAssignedSet.addAll(b.assignedDates);
          for (final d in b.assignedDates) {
            if (d.compareTo(todayIso) < 0) mergedCompletedSet.add(d);
          }
        }
      }
      mergedAssignedSet.addAll(mergedCompletedSet);
      _completedDates = mergedCompletedSet.toList();
      _assignedDates = mergedAssignedSet.toList();

      // Modo de Meta
      final relatedHourBlock = (block != null && block.hasMonthlyHourTarget)
          ? block
          : blocks.cast<ScheduleBlock?>().firstWhere(
                (b) => b != null && _schedules.any((s) => s.id == b.id) && b.hasMonthlyHourTarget,
                orElse: () => null,
              );
      if (relatedHourBlock != null) {
        _targetMode = TaskTargetMode.hours;
        _monthlyTargetHours = relatedHourBlock.monthlyTargetHours;
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

      // Inicializar Recordatorio desde el hábito o el bloque
      _hasReminder = (habit?.hasReminder ?? false) || (block?.hasReminder ?? false);
      if (habit != null && habit.reminderHour != null) {
        _reminderTime = TimeOfDay(
          hour: habit.reminderHour!,
          minute: habit.reminderMinute ?? 0,
        );
      } else {
        _reminderTime = const TimeOfDay(hour: 20, minute: 0);
      }
      _reminderOffsetMinutes = block?.reminderOffsetMinutes ?? 15;
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
      _assignedDates = [];
      _hasReminder = false;
      _reminderTime = const TimeOfDay(hour: 20, minute: 0);
      _reminderOffsetMinutes = 15;
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

  Future<void> _showSubTaskDialog({SubTask? subTaskToEdit, int? index}) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = subTaskToEdit != null;
    final titleController = TextEditingController(text: subTaskToEdit?.title ?? '');

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
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
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'Modificar Subtarea' : 'Nueva Subtarea',
                          style: AppTheme.displayStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
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
                      'Añade una subtarea accionable para completar esta actividad.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: TextStyle(
                        color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ej. Tomar creatina, 10 min estiramiento...',
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
                      onSubmitted: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isNotEmpty) {
                          Navigator.pop(ctx, trimmed);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              side: BorderSide(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final text = titleController.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.pop(ctx, text);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              isEditing ? 'Guardar' : 'Añadir',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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

    titleController.dispose();

    if (result != null && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        if (isEditing && index != null && index < _subTasks.length) {
          _subTasks[index] = _subTasks[index].copyWith(title: result);
        } else {
          _subTasks.add(SubTask(
            id: 'subtask_${DateTime.now().millisecondsSinceEpoch}_${_subTasks.length}',
            title: result,
            orderIndex: _subTasks.length,
          ));
        }
      });
    }
  }

  Future<void> _showScheduleDialog({_ScheduleItem? itemToEdit, int? editIndex}) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parentTaskName = _nameController.text.trim();
    final isEditing = itemToEdit != null;

    TimeOfDay startTime;
    TimeOfDay endTime;

    if (isEditing) {
      startTime = itemToEdit.startTime;
      endTime = itemToEdit.endTime;
    } else if (_schedules.isNotEmpty) {
      startTime = _schedules.last.endTime;
      endTime = TimeOfDay(hour: (startTime.hour + 8) % 24, minute: startTime.minute);
    } else if (_startTime != null && _endTime != null) {
      startTime = _startTime!;
      endTime = _endTime!;
    } else {
      startTime = const TimeOfDay(hour: 8, minute: 0);
      endTime = const TimeOfDay(hour: 16, minute: 0);
    }

    final scheduleTitleController = TextEditingController(
      text: isEditing
          ? itemToEdit.title
          : (_schedules.isEmpty && parentTaskName.isNotEmpty ? parentTaskName : ''),
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
                              isEditing ? 'Modificar Subtarea' : 'Añadir Horario',
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
                          isEditing
                              ? 'Modifica el nombre o las horas de esta subtarea.'
                              : 'Configura una franja horaria para esta actividad.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Nombre de la franja / subtarea
                        Text(
                          'NOMBRE DEL HORARIO / SUBTAREA',
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
                                      id: itemToEdit?.id ?? 'block_${DateTime.now().millisecondsSinceEpoch}_${_schedules.length}',
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
                                child: Text(
                                  isEditing ? 'Guardar Cambios' : 'Añadir Horario',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        if (isEditing && editIndex != null && editIndex < _schedules.length) {
          _schedules[editIndex] = result;
        } else {
          _schedules.add(result);
        }
        _hasSchedule = true;
      });
    }
  }

  Future<void> _showAddScheduleDialog() => _showScheduleDialog();

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

    // 1. Identificadores si estamos editando (incluyendo vinculaciones cruzadas y bloques propios)
    final originalTitle = (widget.habitToEdit?.name ?? widget.blockToEdit?.title)?.trim().toLowerCase();
    final editingHabitId = widget.habitToEdit?.id ??
        widget.blockToEdit?.habitId ??
        _linkedHabitId ??
        (_isEditing && originalTitle != null
            ? habits
                .cast<Habit?>()
                .firstWhere(
                  (h) => h != null && h.name.trim().toLowerCase() == originalTitle,
                  orElse: () => null,
                )
                ?.id
            : null);

    final editingBlockId = widget.blockToEdit?.id ??
        (_schedules.isNotEmpty ? _schedules.first.id : null) ??
        (editingHabitId != null
            ? blocks
                .cast<ScheduleBlock?>()
                .firstWhere(
                  (b) => b != null && b.habitId == editingHabitId,
                  orElse: () => null,
                )
                ?.id
            : null);

    final ownBlockIds = <String>{
      if (widget.blockToEdit != null) widget.blockToEdit!.id,
      if (editingBlockId != null) editingBlockId,
      ..._schedules.map((s) => s.id),
      ..._deletedScheduleIds,
      for (final b in blocks)
        if ((editingHabitId != null && b.habitId == editingHabitId) ||
            (_isEditing && originalTitle != null && b.title.trim().toLowerCase() == originalTitle))
          b.id,
    };

    // 2. Validación de Duplicados: proteger contra colisión con OTRAS tareas distintas
    if (_showInOrbit && _linkedHabitId == null) {
      final duplicateHabit = habits.cast<Habit?>().firstWhere(
            (h) =>
                h != null &&
                h.id != editingHabitId &&
                !(_isEditing && originalTitle != null && h.name.trim().toLowerCase() == originalTitle) &&
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
      if (_startTime == null && _endTime == null && _schedules.isEmpty) {
        _startTime = const TimeOfDay(hour: 8, minute: 0);
        _endTime = const TimeOfDay(hour: 16, minute: 0);
      }

      if (_startTime == null || _endTime == null) {
        // Si NO está en la órbita ni vinculado a nada, sí es obligatorio indicar horas para el reloj
        if (!_showInOrbit && _linkedHabitId == null && _schedules.isEmpty) {
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
                !ownBlockIds.contains(b.id) &&
                (editingHabitId == null || b.habitId != editingHabitId) &&
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

    // 3. Manejo de Modo Órbita (Rueda de Hábitos) y Subtareas
    if (_showInOrbit || _linkedHabitId != null || _subTasks.isNotEmpty) {
      final existingHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.id == targetHabitId,
            orElse: () => null,
          );

      final habitReminderEnabled =
          _hasReminder && !_hasSchedule && _targetMode != TaskTargetMode.hours;

      if (existingHabit != null) {
        final updatedHabit = existingHabit.copyWith(
          name: title,
          colorValue: _selectedColor.value,
          targetDays: _targetMode == TaskTargetMode.days ? _targetDays : existingHabit.targetDays,
          activeWeekdays: _activeWeekdays,
          hasMonthlyTarget: _targetMode == TaskTargetMode.days,
          frequencyType: _targetMode == TaskTargetMode.days ? _frequencyType : existingHabit.frequencyType,
          targetDaysPerWeek: _targetDaysPerWeek,
          completedDates: Set<String>.from(_completedDates),
          subTasks: _subTasks,
          hasReminder: habitReminderEnabled,
          reminderHour: habitReminderEnabled ? _reminderTime.hour : null,
          reminderMinute: habitReminderEnabled ? _reminderTime.minute : null,
          clearReminderTime: !habitReminderEnabled,
        );
        ref.read(habitsProvider.notifier).updateHabit(updatedHabit);
      } else if (_showInOrbit || _subTasks.isNotEmpty) {
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
          subTasks: _subTasks,
          hasReminder: habitReminderEnabled,
          reminderHour: habitReminderEnabled ? _reminderTime.hour : null,
          reminderMinute: habitReminderEnabled ? _reminderTime.minute : null,
        );
        ref.read(habitsProvider.notifier).addHabit(habit);
      }
    } else if (widget.habitToEdit != null && editingHabitId != null && !_showInOrbit) {
      // Solo si el usuario estaba editando un hábito directamente y decide quitarlo de la órbita
      ref.read(habitsProvider.notifier).deleteHabit(editingHabitId);
    }

    // 4. Manejo de Modo Reloj 24h
    if (_hasSchedule || _targetMode == TaskTargetMode.hours) {
      final finalHabitId = _linkedHabitId ?? (_showInOrbit ? targetHabitId : null);
      final hasHourTarget = _targetMode == TaskTargetMode.hours;

      final effectiveSchedules = <_ScheduleItem>[
        ..._schedules.map((s) {
          if (_schedules.length == 1 && widget.habitToEdit != null && s.title.trim().toLowerCase() == widget.habitToEdit!.name.trim().toLowerCase()) {
            return _ScheduleItem(
              id: s.id,
              title: title,
              startTime: s.startTime,
              endTime: s.endTime,
            );
          }
          if (_schedules.length == 1 && widget.blockToEdit != null && s.id == widget.blockToEdit!.id) {
            return _ScheduleItem(
              id: s.id,
              title: title,
              startTime: s.startTime,
              endTime: s.endTime,
            );
          }
          return s;
        }),
        if (_schedules.isEmpty)
          _ScheduleItem(
            id: editingBlockId ?? 'block_${DateTime.now().millisecondsSinceEpoch}',
            title: title,
            startTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
            endTime: _endTime ?? const TimeOfDay(hour: 16, minute: 0),
          ),
      ];

      // Calcular fechas ya asignadas en otros bloques de la misma tarea (si tiene múltiples turnos)
      final allOtherBlocksAssigned = <String>{};
      final allOtherBlocksCompleted = <String>{};
      if (effectiveSchedules.length > 1) {
        for (final s in effectiveSchedules.skip(1)) {
          final b = blocks.cast<ScheduleBlock?>().firstWhere(
                (blk) => blk?.id == s.id,
                orElse: () => null,
              );
          if (b != null) {
            allOtherBlocksAssigned.addAll(b.assignedDates.where((d) => _assignedDates.contains(d)));
            allOtherBlocksCompleted.addAll(b.completedDates.where((d) => _completedDates.contains(d)));
          }
        }
      }

      // Guardar todos los horarios definidos:
      for (int idx = 0; idx < effectiveSchedules.length; idx++) {
        final s = effectiveSchedules[idx];
        final existingBlock = blocks.cast<ScheduleBlock?>().firstWhere(
              (b) => b?.id == s.id,
              orElse: () => null,
            );
        final isNew = existingBlock == null;
        final List<String> blockCompletedDates;
        final List<String> blockAssignedDates;

        if (effectiveSchedules.length == 1) {
          blockCompletedDates = List<String>.from(_completedDates);
          blockAssignedDates = List<String>.from(_assignedDates);
        } else if (idx == 0) {
          blockCompletedDates = _completedDates
              .where((d) => (existingBlock?.completedDates.contains(d) ?? false) || !allOtherBlocksCompleted.contains(d))
              .toList();
          blockAssignedDates = _assignedDates
              .where((d) => (existingBlock?.assignedDates.contains(d) ?? false) || !allOtherBlocksAssigned.contains(d))
              .toList();
        } else {
          final firstBlock = blocks.cast<ScheduleBlock?>().firstWhere(
                (b) => b?.id == effectiveSchedules.first.id,
                orElse: () => null,
              );
          final firstBlockCompleted = firstBlock?.completedDates.toSet() ?? const <String>{};
          blockCompletedDates = isNew
              ? const <String>[]
              : existingBlock.completedDates
                  .where((d) => _completedDates.contains(d) && !firstBlockCompleted.contains(d))
                  .toList();
          blockAssignedDates = isNew
              ? const <String>[]
              : existingBlock.assignedDates
                  .where((d) => _assignedDates.contains(d) && !firstBlockCompleted.contains(d))
                  .toList();
        }

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
          completedDates: blockCompletedDates,
          assignedDates: blockAssignedDates,
          monthlyExtraHours: existingBlock?.monthlyExtraHours ?? const {},
          extraHours: existingBlock?.extraHours ?? _extraHours,
          hasReminder: _hasReminder,
          reminderOffsetMinutes: _reminderOffsetMinutes,
        );

        if (isNew) {
          ref.read(scheduleProvider.notifier).addBlock(scheduleBlock);
        } else {
          ref.read(scheduleProvider.notifier).updateBlock(scheduleBlock);
        }
      }

      if (effectiveSchedules.isNotEmpty) {
        // Si antes había un bloque individual genérico y ahora se usan franjas múltiples, eliminar el genérico viejo para que no choquen horas:
        if (editingBlockId != null && !effectiveSchedules.any((s) => s.id == editingBlockId)) {
          ref.read(scheduleProvider.notifier).deleteBlock(editingBlockId);
        }
      }

      // Eliminar de Hive cualquier subtarea que el usuario haya borrado explícitamente
      for (final delId in _deletedScheduleIds) {
        ref.read(scheduleProvider.notifier).deleteBlock(delId);
      }
    } else {
      // Si el horario está desactivado, limpiar bloques asociados
      for (final s in _schedules) {
        ref.read(scheduleProvider.notifier).deleteBlock(s.id);
      }
      for (final delId in _deletedScheduleIds) {
        ref.read(scheduleProvider.notifier).deleteBlock(delId);
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

  Future<void> _duplicateTask() async {
    HapticFeedback.selectionClick();
    final currentTitle = _nameController.text.trim();
    final duplicatedTitle = currentTitle.isEmpty ? 'Copia' : '$currentTitle (Copia)';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Duplicar tarea?'),
        content: Text(
          'Se creará "$duplicatedTitle" como una nueva tarea independiente con sus subtareas y horarios listos para planificar.',
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
            child: Text(
              'Duplicar',
              style: TextStyle(
                color: _selectedColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final newHabitId = 'habit_${DateTime.now().millisecondsSinceEpoch}';
    final habits = ref.read(habitsProvider);

    // 1. Clonar subtareas con IDs nuevos y progreso limpio
    final duplicatedSubTasks = _subTasks.asMap().entries.map((entry) {
      return SubTask(
        id: 'subtask_${DateTime.now().millisecondsSinceEpoch}_${entry.key}',
        title: entry.value.title,
        completedDates: const {},
        orderIndex: entry.key,
      );
    }).toList();

    // 2. Si es hábito (o visible en órbita o tiene subtareas)
    final bool shouldCreateHabit = _showInOrbit || widget.habitToEdit != null || _subTasks.isNotEmpty;
    if (shouldCreateHabit) {
      final newHabit = Habit(
        id: newHabitId,
        name: duplicatedTitle,
        colorValue: _selectedColor.value,
        targetDays: _targetMode == TaskTargetMode.days ? _targetDays : 20,
        orderIndex: habits.length,
        isNumeric: false,
        dailyTarget: 1,
        dailyUnit: '',
        activeWeekdays: _activeWeekdays,
        hasMonthlyTarget: _targetMode == TaskTargetMode.days,
        frequencyType: _targetMode == TaskTargetMode.days ? _frequencyType : 0,
        targetDaysPerWeek: _targetDaysPerWeek,
        completedDates: const {},
        subTasks: duplicatedSubTasks,
      );
      ref.read(habitsProvider.notifier).addHabit(newHabit);
    }

    // 3. Si tiene horarios asignados, clonar los bloques de horario
    if (_hasSchedule) {
      final finalHabitId = shouldCreateHabit ? newHabitId : null;
      final hasHourTarget = _targetMode == TaskTargetMode.hours;

      for (int i = 0; i < _schedules.length; i++) {
        final s = _schedules[i];
        final newBlock = ScheduleBlock(
          id: 'block_${DateTime.now().millisecondsSinceEpoch}_$i',
          title: s.title.isEmpty ? duplicatedTitle : '${s.title} (Copia)',
          startHour: s.startTime.hour,
          startMinute: s.startTime.minute,
          endHour: s.endTime.hour,
          endMinute: s.endTime.minute,
          colorValue: _selectedColor.value,
          habitId: finalHabitId,
          daysOfWeek: _activeWeekdays,
          hasMonthlyHourTarget: hasHourTarget,
          monthlyTargetHours: _monthlyTargetHours,
          completedDates: const [],
          assignedDates: const [],
          extraHours: 0.0,
        );
        ref.read(scheduleProvider.notifier).addBlock(newBlock);
      }
    }

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tarea duplicada: "$duplicatedTitle"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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

  Widget _wrapTourSection({
    required int stepIndex,
    required GlobalKey sectionKey,
    required bool isDark,
    required Widget child,
  }) {
    if (!widget.isTourMode) return child;

    final isFocused = _tourSubStep == stepIndex;
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (!isFocused) {
          _goToTourSubStep(stepIndex);
        }
      },
      child: AnimatedOpacity(
        key: sectionKey,
        duration: const Duration(milliseconds: 220),
        opacity: isFocused ? 1.0 : 0.32,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.symmetric(vertical: isFocused ? 6.0 : 0.0),
          padding: EdgeInsets.all(isFocused ? 12.0 : 0.0),
          decoration: BoxDecoration(
            color: isFocused
                ? accent.withValues(alpha: isDark ? 0.08 : 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isFocused
                ? Border.all(
                    color: accent,
                    width: 1.8,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTourGuideCard(bool isDark) {
    final accent = Theme.of(context).colorScheme.primary;
    final cardBg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F5F2);
    final cardBorder = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8D5CE);
    final textPrimary = isDark ? const Color(0xFFF4F3EF) : const Color(0xFF0A0A0A);
    final textSecondary = isDark ? const Color(0xFF9E9C96) : const Color(0xFF52514E);

    const subSteps = <({String label, String title, String body})>[
      (
        label: '3-B',
        title: '1. Nombre y Color Visual',
        body: 'Ponle nombre a tu hábito o turno y elige el color con el que brillará su anillo en la rueda y en el reloj.',
      ),
      (
        label: '3-C',
        title: '2. Subtareas paso a paso',
        body: 'Opcional: divide cualquier actividad en pequeños pasos (ej. Calentar, Pesas, Estirar) para ir marcando tu avance.',
      ),
      (
        label: '3-D',
        title: '3. Dónde se muestra y Horario',
        body: 'Elige si aparece en el Reloj 24h con hora fija (incluso turnos nocturnos), en la Rueda Mensual o en ambos a la vez.',
      ),
      (
        label: '3-E',
        title: '4. Días activos y Tipo de Meta',
        body: 'Selecciona qué días aplica y define tu objetivo: sin meta, por días al mes o por Bolsa de Horas si trabajas por turnos.',
      ),
    ];

    final current = subSteps[_tourSubStep.clamp(0, subSteps.length - 1)];
    final isLastSubStep = _tourSubStep >= subSteps.length - 1;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '[ PASO ${current.label} / 07 ]',
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.monoStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: cardBorder, width: 1.0),
                  ),
                  child: Text(
                    '[ VOLVER AL TOUR ]',
                    style: AppTheme.monoStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mini barra de 4 secciones del formulario con animación fluida
          Row(
            children: List.generate(subSteps.length, (i) {
              final active = i <= _tourSubStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: 3.0,
                  margin: EdgeInsets.only(right: i < subSteps.length - 1 ? 5.0 : 0.0),
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.10)),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Contenido del sub-paso con transición suave (Fade + Slide + AnimatedSize)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey<int>(_tourSubStep),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title,
                    style: AppTheme.displayStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    current.body,
                    style: AppTheme.bodyStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_tourSubStep > 0) ...[
                GestureDetector(
                  onTap: () => _goToTourSubStep(_tourSubStep - 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: cardBorder, width: 1.0),
                    ),
                    child: Text(
                      '[ ← ANTERIOR ]',
                      style: AppTheme.monoStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox.shrink(),
              Flexible(
                child: GestureDetector(
                  onTap: () {
                    if (isLastSubStep) {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop();
                    } else {
                      _goToTourSubStep(_tourSubStep + 1);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLastSubStep ? '[ VOLVER AL TOUR → ]' : '[ SIGUIENTE PARTE → ]',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTheme.monoStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
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
          const SizedBox(height: 14),

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ],
          ),
          const SizedBox(height: 14),

          // Tarjeta Guía fijada en la parte superior durante el Tour Guiado (Pasos 3-B a 3-E)
          if (widget.isTourMode) _buildTourGuideCard(isDark),

          // Formulario desplazable con secciones iluminadas dinámicamente
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECCIÓN 3-B: Nombre + Color Visual
                  _wrapTourSection(
                    stepIndex: 0,
                    sectionKey: _tourIdentitySectionKey,
                    isDark: isDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
          ],
        ),
      ),

      // SECCIÓN 3-C: Subtareas (Checklist)
      _wrapTourSection(
        stepIndex: 1,
        sectionKey: _tourSubtasksSectionKey,
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3. Sección: Subtareas (Checklist)
            _buildSectionTitle('Subtareas'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('📝 ', style: TextStyle(fontSize: 15)),
                          Text(
                            'Subtareas (${_subTasks.length})',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showSubTaskDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.12),
                            borderRadius: AppTheme.radiusXs,
                            border: Border.all(
                              color: _selectedColor.withValues(alpha: 0.35),
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: _selectedColor),
                              const SizedBox(width: 4),
                              Text(
                                'Añadir Subtarea',
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
                    ],
                  ),
                  if (_subTasks.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Opcional: Añade subtareas para marcar conforme avances en esta actividad.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textColor?.withValues(alpha: 0.45) ?? Colors.grey,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _subTasks.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _subTasks.removeAt(oldIndex);
                            _subTasks.insert(newIndex, item);
                            for (int i = 0; i < _subTasks.length; i++) {
                              _subTasks[i] = _subTasks[i].copyWith(orderIndex: i);
                            }
                          });
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            elevation: 0,
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final st = _subTasks[index];
                          return Container(
                            key: ValueKey(st.id),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                width: AppTheme.borderPrecision,
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      size: 16,
                                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    st.title,
                                    style: AppTheme.bodyStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _showSubTaskDialog(subTaskToEdit: st, index: index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(Icons.edit_outlined, size: 13, color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _subTasks.removeAt(index));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, size: 13, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),

      // SECCIÓN 3-D: Visibilidad y Modos + Horarios
      _wrapTourSection(
        stepIndex: 2,
        sectionKey: _tourVisibilitySectionKey,
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 4. Sección: Visibilidad y Modos (¿Dónde se muestra?)
            _buildSectionTitle('Visibilidad y Modos'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.15)),
              ),
              child: Material(
                color: Colors.transparent,
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

              // Lista de Subtareas / Horarios configurados
              if (_schedules.isNotEmpty) ...[
                ..._schedules.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return GestureDetector(
                    onTap: () => _showScheduleDialog(itemToEdit: item, editIndex: index),
                    child: Container(
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
                          // Botón Editar
                          GestureDetector(
                            onTap: () => _showScheduleDialog(itemToEdit: item, editIndex: index),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                                  width: AppTheme.borderPrecision,
                                ),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ),
                          // Botón Eliminar
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _deletedScheduleIds.add(item.id);
                                _schedules.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
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
          ],
        ),
      ),

      // SECCIÓN 3-E: Días de la Semana + Tipo de Meta
      _wrapTourSection(
        stepIndex: 3,
        sectionKey: _tourTargetSectionKey,
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    border: Border.all(color: _selectedColor.withValues(alpha: 0.3)),
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
                              color: textColor?.withValues(alpha: 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: textColor?.withValues(alpha: 0.6)),
                                onPressed: () {
                                  if (_monthlyTargetHours > 10) {
                                    setState(() => _monthlyTargetHours -= 10);
                                  }
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _selectedColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedColor.withValues(alpha: 0.35),
                                    width: AppTheme.borderPrecision,
                                  ),
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
                                icon: Icon(Icons.add, color: textColor?.withValues(alpha: 0.6)),
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
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.withValues(alpha: 0.15), height: 1),
                      const SizedBox(height: 12),
                      _buildLinkedTaskCalendar(textColor, isDark),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),

            const SizedBox(height: 24),

            // SECCIÓN 4: RECORDATORIO PERSONALIZADO (SWISS BENTO)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _hasReminder
                      ? _selectedColor.withValues(alpha: 0.45)
                      : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔔 RECORDATORIO',
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: _hasReminder
                                    ? _selectedColor
                                    : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (_hasSchedule || _targetMode == TaskTargetMode.hours)
                                  ? 'Aviso al finalizar (+10 min si no se ha marcado)'
                                  : 'Recibe un aviso inteligente si aún no lo has completado hoy',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: textColor?.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _hasReminder,
                        activeThumbColor: _selectedColor,
                        onChanged: (val) async {
                          HapticFeedback.selectionClick();
                          setState(() => _hasReminder = val);
                          if (val) {
                            await NotificationService().requestPermissions(
                              includeExactAlarms: true,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (_hasReminder) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                    ),
                    const SizedBox(height: 12),
                    if (_hasSchedule || _targetMode == TaskTargetMode.hours) ...[
                      Builder(
                        builder: (context) {
                          final activeEndTime = _endTime ??
                              (_schedules.isNotEmpty ? _schedules.first.endTime : null);
                          String titleText = 'AVISO POST-ACTIVIDAD (+10 MIN)';
                          if (activeEndTime != null && _schedules.length <= 1) {
                            final endTotal =
                                (activeEndTime.hour * 60 + activeEndTime.minute + 10) % 1440;
                            final postHh =
                                (endTotal ~/ 60).toString().padLeft(2, '0');
                            final postMm =
                                (endTotal % 60).toString().padLeft(2, '0');
                            titleText = 'AVISO POST-ACTIVIDAD · $postHh:$postMm';
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedColor.withValues(alpha: 0.35),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                  color: _selectedColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        titleText,
                                        style: AppTheme.monoStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: _selectedColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Te recordaremos 10 min después de finalizar este horario si aún no lo marcaste como completado.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          color: isDark
                                              ? AppTheme.obsidianTextSecondary
                                              : AppTheme.boneTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HORA DEL AVISO',
                            style: AppTheme.monoStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: textColor?.withValues(alpha: 0.5),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _reminderTime,
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
                              if (picked != null) {
                                setState(() => _reminderTime = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _selectedColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _selectedColor.withValues(alpha: 0.45),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_rounded, size: 13, color: _selectedColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
                                    style: AppTheme.monoStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in const [
                            TimeOfDay(hour: 8, minute: 0),
                            TimeOfDay(hour: 14, minute: 0),
                            TimeOfDay(hour: 20, minute: 0),
                            TimeOfDay(hour: 22, minute: 0),
                          ])
                            Builder(
                              builder: (context) {
                                final isSelected = _reminderTime.hour == preset.hour &&
                                    _reminderTime.minute == preset.minute;
                                final label =
                                    '${preset.hour.toString().padLeft(2, '0')}:${preset.minute.toString().padLeft(2, '0')}';
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _reminderTime = preset);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _selectedColor.withValues(alpha: 0.16)
                                          : (isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? _selectedColor
                                            : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: AppTheme.monoStyle(
                                        fontSize: 10.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? _selectedColor
                                            : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

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

            // Botones de acción secundaria si se está editando
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _duplicateTask,
                    icon: Icon(
                      Icons.copy_rounded,
                      color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                      size: 16,
                    ),
                    label: Text(
                      'Duplicar Tarea',
                      style: TextStyle(
                        color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '·',
                    style: TextStyle(
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _deleteTask,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                    label: const Text(
                      'Eliminar Tarea',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  ],
),
);
  }

  Widget _buildTabOption(TaskTargetMode mode, String label) {
    final isSelected = _targetMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _targetMode = mode;
            if (mode == TaskTargetMode.hours && !_hasSchedule) {
              _hasSchedule = true;
              if (_startTime == null && _endTime == null && _schedules.isEmpty) {
                _startTime = const TimeOfDay(hour: 8, minute: 0);
                _endTime = const TimeOfDay(hour: 16, minute: 0);
              }
            }
          });
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

  Widget _buildLinkedTaskCalendar(Color? textColor, bool isDark) {
    final calMonth = _calendarMonth ??= DateTime(DateTime.now().year, DateTime.now().month, 1);
    final year = calMonth.year;
    final month = calMonth.month;
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}';
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayWeekday = DateTime(year, month, 1).weekday; // 1 = Lunes .. 7 = Domingo
    final leadingEmptyCells = firstDayWeekday - 1;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rowsCount = (totalCells / 7).ceil();
    final todayIso = DateTime.now().toIso8601String().split('T').first;

    // Asegurar sincronización con bloques existentes incluso tras Hot Reload
    if (_didSyncAssignedDates != true) {
      _didSyncAssignedDates = true;
      final blocks = ref.read(scheduleProvider);
      final targetHabitId = widget.habitToEdit?.id ?? widget.blockToEdit?.habitId ?? _linkedHabitId;
      final currentTitle = _nameController.text.trim().toLowerCase();
      final mergedAssigned = <String>{..._assignedDates};
      final mergedCompleted = <String>{..._completedDates};
      for (final b in blocks) {
        final matchesBlock = (widget.blockToEdit != null && b.id == widget.blockToEdit!.id) ||
            (targetHabitId != null && b.habitId == targetHabitId) ||
            _schedules.any((s) => s.id == b.id) ||
            (currentTitle.isNotEmpty && b.title.trim().toLowerCase() == currentTitle);
        if (matchesBlock) {
          mergedAssigned.addAll(b.assignedDates);
          mergedCompleted.addAll(b.completedDates);
          for (final d in b.assignedDates) {
            if (d.compareTo(todayIso) < 0) mergedCompleted.add(d);
          }
        }
      }
      _assignedDates = mergedAssigned.toList();
      _completedDates = mergedCompleted.toList();
    }

    final completedInMonth = _completedDates.where((d) => d.startsWith(monthPrefix)).toSet();
    final assignedInMonth = _assignedDates.where((d) => d.startsWith(monthPrefix)).toSet();
    final pendingCount = assignedInMonth.where((d) => !completedInMonth.contains(d)).length;
    final completedCount = completedInMonth.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera: Título + Navegación de Mes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 15,
                  color: _selectedColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Calendario del mes',
                  style: TextStyle(
                    color: textColor?.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _calendarMonth = DateTime(year, month - 1, 1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: AppTheme.radiusXs,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: textColor?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_monthNames[month - 1]} $year',
                    style: AppTheme.monoStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: textColor?.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _calendarMonth = DateTime(year, month + 1, 1);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      borderRadius: AppTheme.radiusXs,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: textColor?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Resumen rápido: Completados vs Pendientes
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.2),
                borderRadius: AppTheme.radiusXs,
                border: Border.all(
                  color: _selectedColor.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: Text(
                '$completedCount completados',
                style: AppTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: _selectedColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.07),
                borderRadius: AppTheme.radiusXs,
                border: Border.all(
                  color: _selectedColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Text(
                '$pendingCount por completar',
                style: AppTheme.monoStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: textColor?.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Cabecera de días de la semana (L M X J V S D)
        Row(
          children: List.generate(7, (i) {
            final isWeekend = i >= 5;
            return Expanded(
              child: Center(
                child: Text(
                  _weekdaysShort[i],
                  style: AppTheme.monoStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isWeekend
                        ? _selectedColor.withValues(alpha: 0.75)
                        : textColor?.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),

        // Cuadrícula de días del mes (enlazada con el Calendario General)
        Column(
          children: List.generate(rowsCount, (rowIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: List.generate(7, (colIndex) {
                  final cellIndex = rowIndex * 7 + colIndex;
                  final dayNum = cellIndex - leadingEmptyCells + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 36));
                  }

                  final dateIso = '$monthPrefix-${dayNum.toString().padLeft(2, '0')}';
                  final isCompleted = completedInMonth.contains(dateIso);
                  final isAssigned = assignedInMonth.contains(dateIso);
                  final isPending = isAssigned && !isCompleted;
                  final isToday = dateIso == todayIso;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (!isAssigned && !isCompleted) {
                              // 1. Sin asignar -> Asignado / Pendiente (más opaco)
                              _assignedDates.add(dateIso);
                            } else if (isPending) {
                              // 2. Pendiente -> Completado (coloreado vivo)
                              _completedDates.add(dateIso);
                            } else {
                              // 3. Completado -> Sin asignar
                              _completedDates.remove(dateIso);
                              _assignedDates.remove(dateIso);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? _selectedColor.withValues(alpha: isDark ? 0.88 : 0.92)
                                : isPending
                                    ? _selectedColor.withValues(alpha: isDark ? 0.16 : 0.14)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.03)
                                        : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCompleted
                                  ? _selectedColor
                                  : isPending
                                      ? _selectedColor.withValues(alpha: isDark ? 0.42 : 0.38)
                                      : isToday
                                          ? (isDark ? Colors.white38 : Colors.black38)
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.07)
                                              : Colors.black.withValues(alpha: 0.07)),
                              width: isCompleted ? 1.5 : (isPending || isToday ? 1.1 : 0.8),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: AppTheme.monoStyle(
                                  fontSize: 12,
                                  fontWeight: isCompleted
                                      ? FontWeight.w800
                                      : isPending
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color: isCompleted
                                      ? Colors.white
                                      : isPending
                                          ? _selectedColor.withValues(alpha: isDark ? 0.65 : 0.72)
                                          : textColor?.withValues(alpha: 0.38),
                                ),
                              ),
                              if (isCompleted)
                                const Positioned(
                                  top: 2,
                                  right: 3,
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                )
                              else if (isPending)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedColor.withValues(alpha: 0.65),
                                        width: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHabitLinkSelector(List<Habit> habits, Color? textColor, bool isDark) {
    Habit? linkedHabit;
    if (_linkedHabitId != null) {
      linkedHabit = habits.cast<Habit?>().firstWhere((h) => h?.id == _linkedHabitId, orElse: () => null);
    } else if (widget.habitToEdit != null && _schedules.isNotEmpty) {
      linkedHabit = widget.habitToEdit;
    }

    final bool isAlreadyLinked = linkedHabit != null;
    final habitColor = linkedHabit?.color ?? _selectedColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Vincular a un Hábito Existente',
                  style: TextStyle(
                    color: textColor?.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isAlreadyLinked) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: habitColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: habitColor.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, size: 11, color: habitColor),
                        const SizedBox(width: 3),
                        Text(
                          'VINCULADO',
                          style: AppTheme.monoStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: habitColor,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (isAlreadyLinked && widget.habitToEdit == null)
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
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          isAlreadyLinked
              ? 'Este horario suma automáticamente al objetivo de "${linkedHabit.name}".'
              : 'Selecciona si este horario es una variante de un hábito existente:',
          style: TextStyle(
            color: isAlreadyLinked ? habitColor : textColor?.withValues(alpha: 0.5),
            fontSize: 11.5,
            fontWeight: isAlreadyLinked ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              // Solo mostrar "➕ Hábito independiente" si NO está ya vinculado
              if (!isAlreadyLinked) ...[
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
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white70 : Colors.black87,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '➕ Hábito independiente',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Chips de hábitos existentes
              ...habits.map((h) {
                final isSelected = (linkedHabit?.id == h.id) || (_linkedHabitId == h.id);
                final hColor = h.color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (isSelected && widget.habitToEdit == null) {
                          _linkedHabitId = null;
                          _showInOrbit = true;
                        } else {
                          _linkedHabitId = h.id;
                          _selectedColor = hColor;
                          if (widget.habitToEdit == null) {
                            _showInOrbit = false; // Ya está en la órbita a través de su hábito
                          }
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? hColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? hColor
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
                              color: hColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            h.name,
                            style: TextStyle(
                              color: isSelected ? hColor : textColor,
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_rounded, size: 13, color: hColor),
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

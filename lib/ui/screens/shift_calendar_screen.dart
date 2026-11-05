import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/schedule_block.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/schedule_poster_service.dart';
import '../theme/app_theme.dart';
import '../widgets/unified_task_sheet.dart';

/// Pantalla de Planificación de Turnos Rotativos en Calendario Mensual.
/// Permite pintar días con turnos específicos (mañanas, noches, guardias)
/// adaptándose a horarios cambiantes mes a mes.
class ShiftCalendarScreen extends ConsumerStatefulWidget {
  const ShiftCalendarScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ShiftCalendarScreen> createState() => _ShiftCalendarScreenState();
}

class _ShiftCalendarScreenState extends ConsumerState<ShiftCalendarScreen> {
  late DateTime _selectedMonth;
  String? _activeShiftId; // ID del bloque seleccionado para pintar o null para modo libre/borrar
  bool _isEraseMode = false;
  String? _lastDraggedDateIso; // Control de drag-to-paint para no re-aplicar en la misma celda

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  static const _weekdaysShort = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  void _goToCurrentMonth() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      _selectedMonth = DateTime(now.year, now.month, 1);
    });
  }

  void _confirmDeleteShift(ScheduleBlock block) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar "${block.title}"?',
          style: AppTheme.displayStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
        content: Text(
          'Se eliminará este horario (${block.formattedTimeRange}) y sus asignaciones del calendario.',
          style: AppTheme.bodyStyle(
            fontSize: 13,
            color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Eliminar Horario'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(scheduleProvider.notifier).deleteBlock(block.id);
      setState(() {
        if (_activeShiftId == block.id) {
          _activeShiftId = null;
        }
      });
    }
  }

  void _createNewShift() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const UnifiedTaskSheet(defaultEnableSchedule: true),
        ),
      ),
    );
  }

  List<ScheduleBlock> _getShiftsForDate(List<ScheduleBlock> blocks, String dateIso) {
    return blocks.where((b) => b.assignedDates.contains(dateIso)).toList();
  }

  void _showDayTasksSheet(
    BuildContext context,
    String dateIso,
    int day,
    List<ScheduleBlock> initialShifts,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final liveBlocks = ref.watch(scheduleProvider);
            final dayShifts = liveBlocks.where((b) => b.assignedDates.contains(dateIso)).toList();
            final monthName = _monthNames[_selectedMonth.month - 1];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DÍA $day DE $monthName'.toUpperCase(),
                              style: AppTheme.monoStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.dynamicAccent(isDark),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dayShifts.length} ${dayShifts.length == 1 ? "tarea asignada" : "tareas asignadas"}',
                              style: AppTheme.displayStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (dayShifts.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              ref.read(scheduleProvider.notifier).clearShiftOnDate(dateIso);
                              Navigator.of(ctx).pop();
                            },
                            icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.redAccent),
                            label: Text(
                              'Borrar todo',
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                    ),
                    const SizedBox(height: 10),
                    if (dayShifts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No quedan tareas asignadas a este día.',
                            style: AppTheme.bodyStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: dayShifts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = dayShifts[index];
                            final shiftColor = s.color;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: shiftColor.withValues(alpha: isDark ? 0.12 : 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: shiftColor.withValues(alpha: 0.4),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: shiftColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s.title,
                                              style: AppTheme.displayStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${s.formattedTimeRange} · ${s.formattedDuration}',
                                              style: AppTheme.monoStyle(
                                                fontSize: 11,
                                                color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        tooltip: 'Quitar de este día',
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          ref.read(scheduleProvider.notifier).toggleShiftOnDate(s.id, dateIso);
                                          if (dayShifts.length <= 1) {
                                            Navigator.of(ctx).pop();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  if (s.hasMonthlyHourTarget) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Extra: ${s.getMonthlyExtraHours(_selectedMonth).toStringAsFixed(0)}h',
                                          style: AppTheme.monoStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        _buildSheetExtraHourChip(s.id, -1.0, '-1h', isDark),
                                        const SizedBox(width: 4),
                                        _buildSheetExtraHourChip(s.id, 1.0, '+1h', isDark),
                                        const SizedBox(width: 4),
                                        _buildSheetExtraHourChip(s.id, 2.0, '+2h', isDark),
                                        const SizedBox(width: 4),
                                        _buildSheetExtraHourChip(s.id, 4.0, '+4h', isDark),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetExtraHourChip(String blockId, double delta, String label, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(scheduleProvider.notifier).addExtraHours(blockId, delta, _selectedMonth);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          borderRadius: AppTheme.radiusXs,
          border: Border.all(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            width: AppTheme.borderPrecision,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.monoStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: delta > 0 ? (isDark ? Colors.white : Colors.black87) : Colors.redAccent,
          ),
        ),
      ),
    );
  }

  void _handleDragAt(
    Offset localPosition,
    BoxConstraints constraints,
    int firstDayWeekday,
    int daysInMonth,
  ) {
    final gridWidth = constraints.maxWidth;
    const crossSpacing = 6.0;
    const mainSpacing = 6.0;
    final colWidth = (gridWidth - (6 * crossSpacing)) / 7.0;
    final cellHeight = colWidth / 0.95;

    final dx = localPosition.dx;
    final dy = localPosition.dy;
    if (dx < 0 || dx >= gridWidth || dy < 0) return;

    final col = (dx / (colWidth + crossSpacing)).floor();
    if (col < 0 || col >= 7) return;
    final colRemainder = dx - col * (colWidth + crossSpacing);
    if (colRemainder > colWidth) return;

    final row = (dy / (cellHeight + mainSpacing)).floor();
    if (row < 0) return;
    final rowRemainder = dy - row * (cellHeight + mainSpacing);
    if (rowRemainder > cellHeight) return;

    final index = row * 7 + col;
    final day = index - (firstDayWeekday - 1) + 1;
    if (day < 1 || day > daysInMonth) return;

    final dateIso = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    if (dateIso == _lastDraggedDateIso) return;
    _lastDraggedDateIso = dateIso;

    HapticFeedback.selectionClick();
    if (_isEraseMode) {
      ref.read(scheduleProvider.notifier).clearShiftOnDate(dateIso);
    } else if (_activeShiftId != null) {
      final blocks = ref.read(scheduleProvider);
      final activeBlock = blocks.cast<ScheduleBlock?>().firstWhere(
            (b) => b?.id == _activeShiftId,
            orElse: () => null,
          );
      if (activeBlock != null && !activeBlock.assignedDates.contains(dateIso)) {
        ref.read(scheduleProvider.notifier).toggleShiftOnDate(_activeShiftId!, dateIso);
      }
    }
  }

  void _openPosterPreview(bool isDark, List<ScheduleBlock> blocks, String userName) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => _PosterPreviewDialog(
        month: _selectedMonth,
        blocks: blocks,
        userName: userName,
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blocks = ref.watch(scheduleProvider);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final todayIso = now.toIso8601String().split('T').first;

    // Si no hay ningún turno activo seleccionado, preseleccionamos el primero si existe
    if (_activeShiftId == null && !_isEraseMode && blocks.isNotEmpty) {
      _activeShiftId = blocks.first.id;
    }

    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final firstDayWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday; // 1 = Lunes

    // Calcular estadísticas del mes en curso
    final monthPrefix = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    int totalAssignedShifts = 0;
    double totalEstimatedHours = 0.0;

    for (final b in blocks) {
      final inMonth = b.assignedDates.where((d) => d.startsWith(monthPrefix)).length;
      totalAssignedShifts += inMonth;
      totalEstimatedHours += inMonth * (b.durationInMinutes / 60.0);
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
      appBar: AppBar(
        title: Text(
          'Planificador de Horarios',
          style: AppTheme.displayStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.photo_camera_back_rounded,
              size: 20,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
            tooltip: 'Exportar Póster PNG',
            onPressed: () => _openPosterPreview(isDark, blocks, settings.userName),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // 1. Selector de Mes con Atajo a Hoy
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 22),
                            onPressed: _prevMonth,
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                            style: AppTheme.displayStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.obsidianTextPrimary
                                  : AppTheme.boneTextPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 22),
                            onPressed: _nextMonth,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _goToCurrentMonth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: AppTheme.radiusXs,
                            border: Border.all(
                              color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                              width: AppTheme.borderPrecision,
                            ),
                          ),
                          child: Text(
                            'Hoy',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.obsidianTextPrimary
                                  : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Paleta de Horarios (Selector de qué horario pintar)
                Text(
                  'Elige un horario y toca los días:',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Opciones de turnos existentes
                      ...blocks.map((block) {
                        final isSelected = !_isEraseMode && _activeShiftId == block.id;
                        final shiftColor = block.color;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isEraseMode = false;
                                _activeShiftId = block.id;
                              });
                            },
                            onLongPress: () => _confirmDeleteShift(block),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? shiftColor.withValues(alpha: 0.22)
                                    : (isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface),
                                borderRadius: AppTheme.radiusSm,
                                border: Border.all(
                                  color: isSelected
                                      ? shiftColor
                                      : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: shiftColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    block.title,
                                    style: AppTheme.displayStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isDark
                                          ? AppTheme.obsidianTextPrimary
                                          : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    block.formattedTimeRange,
                                    style: AppTheme.monoStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? AppTheme.obsidianTextMuted
                                          : AppTheme.boneTextMuted,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _confirmDeleteShift(block),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 13,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // Opción: Borrar / Libre
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isEraseMode = true;
                              _activeShiftId = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isEraseMode
                                  ? (isDark ? Colors.white24 : Colors.black12)
                                  : (isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface),
                              borderRadius: AppTheme.radiusSm,
                              border: Border.all(
                                color: _isEraseMode
                                    ? (isDark ? Colors.white70 : Colors.black87)
                                    : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                                width: _isEraseMode ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.backspace_outlined,
                                  size: 13,
                                  color: isDark
                                      ? AppTheme.obsidianTextSecondary
                                      : AppTheme.boneTextSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Libre / Borrar',
                                  style: AppTheme.displayStyle(
                                    fontSize: 12,
                                    fontWeight: _isEraseMode ? FontWeight.w700 : FontWeight.w500,
                                    color: isDark
                                        ? AppTheme.obsidianTextPrimary
                                        : AppTheme.boneTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Botón: Crear Nuevo Turno
                      GestureDetector(
                        onTap: _createNewShift,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                            borderRadius: AppTheme.radiusSm,
                            border: Border.all(
                              color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppTheme.dynamicAccent(isDark),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Nuevo Horario',
                                style: AppTheme.displayStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.dynamicAccent(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Cuadrícula de Calendario Mensual
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Column(
                    children: [
                      // Cabecera L M X J V S D
                      Row(
                        children: List.generate(7, (i) {
                          return Expanded(
                            child: Center(
                              child: Text(
                                _weekdaysShort[i],
                                style: AppTheme.monoStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: (i >= 5)
                                      ? (isDark ? Colors.white38 : Colors.black38)
                                      : (isDark
                                          ? AppTheme.obsidianTextSecondary
                                          : AppTheme.boneTextSecondary),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),

                      // Días del Mes con soporte de Drag-to-Paint (Pintado por Arrastre Continuo)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanStart: (details) {
                              _handleDragAt(details.localPosition, constraints, firstDayWeekday, daysInMonth);
                            },
                            onPanUpdate: (details) {
                              _handleDragAt(details.localPosition, constraints, firstDayWeekday, daysInMonth);
                            },
                            onPanEnd: (_) => _lastDraggedDateIso = null,
                            onPanCancel: () => _lastDraggedDateIso = null,
                            child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (firstDayWeekday - 1) + daysInMonth,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          if (index < firstDayWeekday - 1) {
                            return const SizedBox.shrink(); // Huecos previos
                          }
                          final day = index - (firstDayWeekday - 1) + 1;
                          final dateIso = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                          final assignedShifts = _getShiftsForDate(blocks, dateIso);
                          final isToday = dateIso == todayIso;

                          final hasShifts = assignedShifts.isNotEmpty;
                          final isMulti = assignedShifts.length >= 2;
                          final primaryShift = hasShifts ? assignedShifts.first : null;
                          final primaryColor = primaryShift?.color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (_isEraseMode) {
                                ref.read(scheduleProvider.notifier).clearShiftOnDate(dateIso);
                              } else if (_activeShiftId != null) {
                                ref.read(scheduleProvider.notifier).toggleShiftOnDate(_activeShiftId!, dateIso);
                              }
                            },
                            onLongPress: hasShifts
                                ? () {
                                    HapticFeedback.mediumImpact();
                                    _showDayTasksSheet(context, dateIso, day, assignedShifts, isDark);
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                color: hasShifts
                                    ? (isMulti
                                        ? primaryColor!.withValues(alpha: isDark ? 0.12 : 0.08)
                                        : primaryColor!.withValues(alpha: isDark ? 0.22 : 0.16))
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.03)
                                        : Colors.black.withValues(alpha: 0.02)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: hasShifts
                                      ? (isToday ? AppTheme.dynamicAccent(isDark) : primaryColor!)
                                      : (isToday
                                          ? AppTheme.dynamicAccent(isDark)
                                          : (isDark
                                              ? AppTheme.obsidianBorder.withValues(alpha: 0.5)
                                              : AppTheme.boneBorder.withValues(alpha: 0.5))),
                                  width: (isToday || hasShifts) ? 1.4 : 0.8,
                                ),
                              ),
                              padding: const EdgeInsets.all(3.5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Fila superior: Número de día + Punto(s) cromático(s)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$day',
                                        style: AppTheme.monoStyle(
                                          fontSize: 10.5,
                                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                          color: isToday
                                              ? AppTheme.dynamicAccent(isDark)
                                              : (hasShifts
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark
                                                      ? AppTheme.obsidianTextPrimary
                                                      : AppTheme.boneTextPrimary)),
                                        ),
                                      ),
                                      if (!hasShifts)
                                        const SizedBox.shrink()
                                      else if (!isMulti)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      else
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (int i = 0; i < assignedShifts.length && i < 3; i++) ...[
                                              if (i > 0) const SizedBox(width: 2),
                                              Container(
                                                width: 4.5,
                                                height: 4.5,
                                                decoration: BoxDecoration(
                                                  color: assignedShifts[i].color,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),

                                  // Cuerpo de la celda
                                  if (!hasShifts)
                                    const SizedBox.shrink()
                                  else if (!isMulti)
                                    Text(
                                      primaryShift!.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.displayStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (int i = 0; i < assignedShifts.length && i < 2; i++) ...[
                                          if (i > 0) const SizedBox(height: 1.5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.8),
                                            decoration: BoxDecoration(
                                              color: assignedShifts[i].color.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(2.5),
                                              border: Border(
                                                left: BorderSide(
                                                  color: assignedShifts[i].color,
                                                  width: 2.2,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              assignedShifts[i].title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.monoStyle(
                                                fontSize: 7.5,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (assignedShifts.length > 2)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 1),
                                            child: Text(
                                              '+${assignedShifts.length - 2}',
                                              textAlign: TextAlign.right,
                                              style: AppTheme.monoStyle(
                                                fontSize: 7,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Resumen Mensual
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$totalAssignedShifts días planificados',
                            style: AppTheme.displayStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.obsidianTextPrimary
                                  : AppTheme.boneTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${totalEstimatedHours.toStringAsFixed(0)} horas estimadas para este mes',
                            style: AppTheme.monoStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.obsidianTextMuted
                                  : AppTheme.boneTextMuted,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.accentPhosphor
                              : AppTheme.boneTextPrimary,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusSm,
                          ),
                        ),
                        child: Text(
                          'Listo',
                          style: AppTheme.displayStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterPreviewDialog extends ConsumerStatefulWidget {
  final DateTime month;
  final List<ScheduleBlock> blocks;
  final String userName;
  final bool isDark;

  const _PosterPreviewDialog({
    required this.month,
    required this.blocks,
    required this.userName,
    required this.isDark,
  });

  @override
  ConsumerState<_PosterPreviewDialog> createState() => _PosterPreviewDialogState();
}

class _PosterPreviewDialogState extends ConsumerState<_PosterPreviewDialog> {
  late Set<String> _selectedBlockIds;
  bool _showTelemetryFooter = true;
  Uint8List? _pngBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedBlockIds = widget.blocks.map((b) => b.id).toSet();
    _generatePoster();
  }

  Future<void> _generatePoster() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bytes = await SchedulePosterService.renderMonthlyPosterPng(
        month: widget.month,
        blocks: widget.blocks,
        userName: widget.userName,
        isDark: widget.isDark,
        includedBlockIds: _selectedBlockIds,
        showTelemetryFooter: _showTelemetryFooter,
      );
      if (mounted) {
        setState(() {
          _pngBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Dialog(
      backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del diálogo
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PÓSTER // PERSONALIZADOR SUIZO',
                        style: AppTheme.monoStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.dynamicAccent(isDark),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cuadrante Exportable 1080p',
                        style: AppTheme.displayStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),

            // Controles de Personalización (Filtro de tareas y Toggle de Resumen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.015),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TAREAS VISIBLES EN PÓSTER:',
                        style: AppTheme.monoStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _showTelemetryFooter = !_showTelemetryFooter;
                          });
                          _generatePoster();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: _showTelemetryFooter
                                ? AppTheme.dynamicAccent(isDark).withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _showTelemetryFooter
                                  ? AppTheme.dynamicAccent(isDark)
                                  : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showTelemetryFooter ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 12,
                                color: _showTelemetryFooter
                                    ? AppTheme.dynamicAccent(isDark)
                                    : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Resumen de horas',
                                style: AppTheme.monoStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: _showTelemetryFooter
                                      ? AppTheme.dynamicAccent(isDark)
                                      : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Chip "Todas"
                        _buildFilterChip(
                          label: 'Todas',
                          isSelected: _selectedBlockIds.length == widget.blocks.length,
                          color: AppTheme.dynamicAccent(isDark),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_selectedBlockIds.length == widget.blocks.length) {
                                if (widget.blocks.isNotEmpty) {
                                  _selectedBlockIds = {widget.blocks.first.id};
                                }
                              } else {
                                _selectedBlockIds = widget.blocks.map((b) => b.id).toSet();
                              }
                            });
                            _generatePoster();
                          },
                        ),
                        for (final b in widget.blocks) ...[
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            label: b.title,
                            isSelected: _selectedBlockIds.contains(b.id),
                            color: b.color,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (_selectedBlockIds.contains(b.id)) {
                                  if (_selectedBlockIds.length > 1) {
                                    _selectedBlockIds.remove(b.id);
                                  }
                                } else {
                                  _selectedBlockIds.add(b.id);
                                }
                              });
                              _generatePoster();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),

            // Previsualización interactiva con zoom y estado de carga
            Flexible(
              child: Container(
                constraints: const BoxConstraints(minHeight: 280, maxHeight: 440),
                color: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_pngBytes != null)
                      InteractiveViewer(
                        minScale: 0.7,
                        maxScale: 3.5,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _pngBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    if (_isLoading)
                      Container(
                        color: Colors.black38,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.dynamicAccent(isDark),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Actualizando...',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
              ),
            ),
            Divider(height: 1, thickness: 1, color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),

            // Botonera inferior: Compartir y Descargar
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cerrar',
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: (_pngBytes == null || _isLoading)
                            ? null
                            : () async {
                                HapticFeedback.lightImpact();
                                await SchedulePosterService.sharePosterPng(
                                  bytes: _pngBytes!,
                                  month: widget.month,
                                );
                              },
                        icon: const Icon(Icons.share_rounded, size: 15),
                        label: Text(
                          'Compartir',
                          style: AppTheme.displayStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (_pngBytes == null || _isLoading)
                            ? null
                            : () async {
                                HapticFeedback.mediumImpact();
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);
                                nav.pop();
                                final savedPath = await SchedulePosterService.savePosterPng(
                                  bytes: _pngBytes!,
                                  month: widget.month,
                                );
                                if (savedPath != null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      backgroundColor: isDark
                                          ? AppTheme.obsidianSurfaceElevated
                                          : AppTheme.boneSurfaceElevated,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isDark
                                              ? AppTheme.obsidianBorderHover
                                              : AppTheme.boneBorder,
                                        ),
                                      ),
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.photo_library_rounded,
                                            size: 20,
                                            color: AppTheme.dynamicAccent(isDark),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Guardado con éxito en la Galería',
                                                  style: AppTheme.displayStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? AppTheme.obsidianTextPrimary
                                                        : AppTheme.boneTextPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  savedPath,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: AppTheme.monoStyle(
                                                    fontSize: 10.5,
                                                    color: isDark
                                                        ? AppTheme.obsidianTextMuted
                                                        : AppTheme.boneTextMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          'Descargar PNG',
                          style: AppTheme.displayStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dynamicAccent(isDark),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.22 : 0.16)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? color : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.monoStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

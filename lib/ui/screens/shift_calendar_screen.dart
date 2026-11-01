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

  ScheduleBlock? _getShiftForDate(List<ScheduleBlock> blocks, String dateIso) {
    for (final b in blocks) {
      if (b.assignedDates.contains(dateIso)) return b;
    }
    return null;
  }

  Future<void> _openPosterPreview(bool isDark, List<ScheduleBlock> blocks, String userName) async {
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.bentoCard(
            isLight: !isDark,
            borderRadius: AppTheme.radiusMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.dynamicAccent(isDark),
              ),
              const SizedBox(height: 16),
              Text(
                'Generando Póster 1080x1440...',
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final pngBytes = await SchedulePosterService.renderMonthlyPosterPng(
        month: _selectedMonth,
        blocks: blocks,
        userName: userName,
        isDark: isDark,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PÓSTER // ALTA RESOLUCIÓN',
                            style: AppTheme.monoStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.dynamicAccent(isDark),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Previsualización 1080x1440',
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
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                ),
                Flexible(
                  child: Container(
                    color: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.5,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            pngBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Cerrar',
                          style: AppTheme.bodyStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                                ),
                              ),
                              content: Text(
                                'Póster renderizado en 1080x1440 px listo para captura de pantalla limpia.',
                                style: AppTheme.bodyStyle(
                                  fontSize: 12.5,
                                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: Text(
                          'Listo',
                          style: AppTheme.displayStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dynamicAccent(isDark),
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Error al generar el póster: $e'),
        ),
      );
    }
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
                  'Elige un horario y toca los días del calendario:',
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

                      // Días del Mes
                      GridView.builder(
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
                          final assignedShift = _getShiftForDate(blocks, dateIso);
                          final isToday = dateIso == todayIso;

                          final shiftColor = assignedShift?.color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (_isEraseMode) {
                                ref.read(scheduleProvider.notifier).clearShiftOnDate(dateIso);
                              } else if (_activeShiftId != null) {
                                ref.read(scheduleProvider.notifier).toggleShiftOnDate(_activeShiftId!, dateIso);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                color: assignedShift != null
                                    ? shiftColor!.withValues(alpha: isDark ? 0.22 : 0.16)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.03)
                                        : Colors.black.withValues(alpha: 0.02)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: assignedShift != null
                                      ? shiftColor!
                                      : (isToday
                                          ? AppTheme.dynamicAccent(isDark)
                                          : (isDark
                                              ? AppTheme.obsidianBorder.withValues(alpha: 0.5)
                                              : AppTheme.boneBorder.withValues(alpha: 0.5))),
                                  width: (isToday || assignedShift != null) ? 1.4 : 0.8,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$day',
                                        style: AppTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                          color: isToday
                                              ? AppTheme.dynamicAccent(isDark)
                                              : (assignedShift != null
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark
                                                      ? AppTheme.obsidianTextPrimary
                                                      : AppTheme.boneTextPrimary)),
                                        ),
                                      ),
                                      if (assignedShift != null)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: shiftColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (assignedShift != null)
                                    Flexible(
                                      child: Text(
                                        assignedShift.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.displayStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: shiftColor,
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                ],
                              ),
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

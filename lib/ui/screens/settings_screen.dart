import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../core/app_version.dart';
import '../widgets/achievements_sheet.dart';
import '../widgets/release_notes_sheet.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  late String _themeMode;
  bool _allowPopOnce = false;
  bool _isExitDialogOpen = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    _nameController.text = settings.userName;
    _themeMode = settings.themeMode;
    _refreshNotificationStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationStatus();
    }
  }

  Future<void> _refreshNotificationStatus() async {
    final status = await NotificationService().getPermissionStatus();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = status.notificationsEnabled;
    });
  }

  Future<void> _requestNotificationPermissions() async {
    HapticFeedback.lightImpact();
    await NotificationService().requestPermissions(includeExactAlarms: true);
    await _refreshNotificationStatus();
    if (!mounted) return;
    var settings = ref.read(settingsProvider);
    if (_notificationsEnabled && !settings.notificationsEnabled) {
      settings = settings.copyWith(notificationsEnabled: true);
      await ref.read(settingsProvider.notifier).updateSettings(settings);
    } else {
      await NotificationService().syncAllTaskReminders(
        habits: ref.read(habitsProvider),
        blocks: ref.read(scheduleProvider),
        globalEnabled: _notificationsEnabled && settings.notificationsEnabled,
        postActivityReminderEnabled: settings.postActivityReminderEnabled,
        vacationDates: settings.vacationDates.toSet(),
      );
    }
  }

  bool get _hasUnsavedChanges {
    final settings = ref.read(settingsProvider);
    return _nameController.text.trim() != settings.userName.trim() ||
        _themeMode != settings.themeMode;
  }

  void _handleBackPress() {
    HapticFeedback.selectionClick();
    if (_hasUnsavedChanges) {
      _confirmExit();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmExit() async {
    if (_isExitDialogOpen) return;
    _isExitDialogOpen = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);
    final dialogBg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F5F2);
    final borderCol = isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: dialogBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderCol, width: 1.0),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[ AJUSTES // SIN GUARDAR ]',
                style: AppTheme.monoStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cambios sin guardar',
                style: AppTheme.displayStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'Has modificado tus ajustes. ¿Quieres guardar los cambios antes de salir?',
            style: AppTheme.bodyStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(dialogCtx).pop();
                if (mounted) {
                  setState(() => _allowPopOnce = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pop();
                  });
                }
              },
              child: Text(
                'Descartar',
                style: AppTheme.monoStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(dialogCtx).pop();
                _saveSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.accentPhosphor : AppTheme.boneTextPrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Guardar cambios',
                style: AppTheme.monoStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    _isExitDialogOpen = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  String _getUserInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'OH';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _handleConfigureVacations() async {
    HapticFeedback.selectionClick();
    final db = ref.read(databaseProvider);
    if (!db.getHasSeenVacationTutorial()) {
      final proceed = await _showVacationTutorialModal(openPickerAfter: true);
      if (!mounted || proceed != true) return;
    }
    await _pickVacationDates();
  }

  Future<bool?> _showVacationTutorialModal({required bool openPickerAfter}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F5F2);
    final cardBg = isDark ? const Color(0xFF1A1A1D) : Colors.white;
    final borderCol = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8D5CE);
    final textPrimary = isDark ? const Color(0xFFF4F3EF) : const Color(0xFF0A0A0A);
    final textSecondary = isDark ? const Color(0xFF9E9C96) : const Color(0xFF52514E);
    final accent = AppTheme.dynamicAccent(isDark);

    const steps = [
      (
        code: '01 / 03',
        icon: Icons.shield_rounded,
        title: 'Escudo de Rachas',
        body:
            'Tus rachas están a salvo. En los días marcados como vacaciones, tus anillos congelan la racha para que descanses sin perder tu constancia.',
      ),
      (
        code: '02 / 03',
        icon: Icons.notifications_off_rounded,
        title: 'Silencio Inteligente',
        body:
            'Cero interrupciones. Durante tus fechas de vacaciones, los recordatorios de tus hábitos se silencian automáticamente.',
      ),
      (
        code: '03 / 03',
        icon: Icons.date_range_rounded,
        title: 'Selección Flexible',
        body:
            'Puedes marcar días sueltos o semanas completas en el selector y desactivarlos cuando vuelvas a la rutina.',
      ),
    ];

    int stepIndex = 0;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final current = steps[stepIndex];
            final isLast = stepIndex == steps.length - 1;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderCol, width: 1.0),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: borderCol,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '[ MODO VACACIONES // ${current.code} ]',
                              style: AppTheme.monoStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(steps.length, (idx) {
                                final active = idx == stepIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  margin: const EdgeInsets.only(left: 5),
                                  width: active ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: active ? accent : borderCol,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol, width: 1.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 1.0,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(current.icon, size: 20, color: accent),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                current.title,
                                style: AppTheme.displayStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                current.body,
                                style: AppTheme.bodyStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (stepIndex > 0)
                              OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => stepIndex--);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: borderCol, width: 1.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'Atrás',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            if (stepIndex > 0) const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  HapticFeedback.selectionClick();
                                  if (!isLast) {
                                    setModalState(() => stepIndex++);
                                  } else {
                                    await ref
                                        .read(databaseProvider)
                                        .setHasSeenVacationTutorial(true);
                                    if (modalCtx.mounted) {
                                      Navigator.of(modalCtx).pop(true);
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isDark ? AppTheme.accentPhosphor : AppTheme.boneTextPrimary,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  isLast
                                      ? (openPickerAfter ? 'Entendido, configurar' : 'Entendido')
                                      : 'Siguiente',
                                  style: AppTheme.monoStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
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
  }

  Future<void> _pickVacationDates() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'DÍAS DE DESCANSO (RACHAS PROTEGIDAS)',
      cancelText: 'CANCELAR',
      confirmText: 'GUARDAR',
      builder: (context, child) {
        return Theme(
          data: isDark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      List<DateTime> dates = [];
      DateTime current = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        dates.add(current);
        current = DateTime(current.year, current.month, current.day + 1);
      }
      await ref.read(settingsProvider.notifier).addVacationDates(dates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
            content: Text(
              '${dates.length} días de descanso programados',
              style: AppTheme.bodyStyle(
                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  void _clearVacations() {
    HapticFeedback.lightImpact();
    ref.read(settingsProvider.notifier).clearVacationDates();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
        content: Text(
          'Días de descanso restablecidos',
          style: AppTheme.bodyStyle(
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteReminder(ActiveTaskReminderInfo item, bool isDark) async {
    HapticFeedback.lightImpact();
    if (item.habitId != null) {
      final habits = ref.read(habitsProvider);
      final idx = habits.indexWhere((h) => h.id == item.habitId);
      if (idx != -1) {
        await ref.read(habitsProvider.notifier).updateHabit(
              habits[idx].copyWith(hasReminder: false),
            );
      }
    } else if (item.blockId != null) {
      final blocks = ref.read(scheduleProvider);
      final idx = blocks.indexWhere((b) => b.id == item.blockId);
      if (idx != -1) {
        await ref.read(scheduleProvider.notifier).updateBlock(
              blocks[idx].copyWith(hasReminder: false),
            );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isDark
            ? AppTheme.obsidianSurfaceElevated
            : AppTheme.boneSurfaceElevated,
        content: Text(
          'Recordatorio eliminado',
          style: AppTheme.bodyStyle(
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _saveSettings() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduce un nombre o alias válido')),
      );
      return;
    }

    final current = ref.read(settingsProvider);
    final updated = current.copyWith(
      userName: name,
      avatarEmoji: '',
      avatarColorValue: 0,
      themeMode: _themeMode,
      isFirstTime: false,
    );

    ref.read(settingsProvider.notifier).updateSettings(updated);
    HapticFeedback.mediumImpact();
    setState(() => _allowPopOnce = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);
    final initials = _getUserInitials(_nameController.text);

    return PopScope(
      canPop: _allowPopOnce || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExit();
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
          onPressed: _handleBackPress,
        ),
        title: Text(
          'Ajustes y Perfil',
          style: AppTheme.displayStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                width: AppTheme.borderPrecision,
              ),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TARJETA DE PERFIL LIMPIA (Solo Iniciales + Nombre)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar con Iniciales
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.accentPhosphor.withValues(alpha: 0.12)
                              : AppTheme.accentCobalt.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: AppTheme.displayStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      // Nombre de usuario
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TU NOMBRE / ALIAS',
                              style: AppTheme.monoStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _nameController,
                              style: AppTheme.displayStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                hintText: 'Escribe tu nombre...',
                                hintStyle: AppTheme.bodyStyle(
                                  fontSize: 18,
                                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Perfil de Usuario · OrbitHabit',
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // 2. MODO VISUAL / TEMA
                _buildSectionHeader('Tema Visual', isDark),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildThemeOption(
                        id: 'dark',
                        label: 'Obsidiana',
                        subtitle: 'Fondo oscuro',
                        bgColor: const Color(0xFF09090B),
                        isSelected: _themeMode == 'dark',
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _themeMode = 'dark');
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildThemeOption(
                        id: 'light',
                        label: 'Hueso',
                        subtitle: 'Fondo claro',
                        bgColor: const Color(0xFFF7F7F8),
                        isSelected: _themeMode == 'light',
                        isDark: isDark,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _themeMode = 'light');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // 3. PAUSA DE RACHAS (VACACIONES)
                _buildSectionHeader('Días de Descanso', isDark),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Modo Vacaciones',
                                    style: AppTheme.bodyStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _showVacationTutorialModal(openPickerAfter: false);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      '[ ? ]',
                                      style: AppTheme.monoStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              settings.vacationDates.isEmpty
                                  ? 'Sin días pausados'
                                  : '${settings.vacationDates.length} días protegidos',
                              style: AppTheme.bodyStyle(
                                fontSize: 12,
                                color: settings.vacationDates.isNotEmpty
                                    ? accent
                                    : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          if (settings.vacationDates.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                              onPressed: _clearVacations,
                            ),
                          ElevatedButton(
                            onPressed: _handleConfigureVacations,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                              foregroundColor: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                                  width: 1.0,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: Text(
                              'Configurar',
                              style: AppTheme.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. NOTIFICACIONES Y RECORDATORIOS
                _buildSectionHeader('Notificaciones Diarias', isDark),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final activeReminders = NotificationService().buildActiveRemindersList(
                      habits: ref.watch(habitsProvider),
                      blocks: ref.watch(scheduleProvider),
                    );
                    final borderColor =
                        isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder;
                    final primaryText = isDark
                        ? AppTheme.obsidianTextPrimary
                        : AppTheme.boneTextPrimary;
                    final secondaryText = isDark
                        ? AppTheme.obsidianTextMuted
                        : AppTheme.boneTextSecondary;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_notificationsEnabled) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB91C1C).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFB91C1C).withValues(alpha: 0.35),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.notifications_off_outlined,
                                        size: 16,
                                        color: Color(0xFFB91C1C),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Permisos de notificación desactivados',
                                          style: AppTheme.bodyStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Concede permiso para activar tus recordatorios',
                                    style: AppTheme.bodyStyle(
                                      fontSize: 11.5,
                                      color: secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: _requestNotificationPermissions,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB91C1C),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '[ Conceder permisos ]',
                                        style: AppTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Interruptor 1: Notificaciones activas
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: _notificationsEnabled ? 1.0 : 0.45,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notificaciones activas',
                                        style: AppTheme.bodyStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Activa o pausa todos los avisos de la app',
                                        style: AppTheme.bodyStyle(
                                          fontSize: 11.5,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _notificationsEnabled && settings.notificationsEnabled,
                                  activeThumbColor: accent,
                                  onChanged: _notificationsEnabled
                                      ? (val) async {
                                          HapticFeedback.selectionClick();
                                          await ref
                                              .read(settingsProvider.notifier)
                                              .updateSettings(
                                                settings.copyWith(notificationsEnabled: val),
                                              );
                                          if (val) {
                                            await NotificationService().requestPermissions(
                                              includeExactAlarms: true,
                                            );
                                            await _refreshNotificationStatus();
                                          }
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Divider(height: 1, thickness: 1, color: borderColor),
                          const SizedBox(height: 10),

                          // Interruptor 2: Recordatorio post-actividad
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 160),
                            opacity: (_notificationsEnabled && settings.notificationsEnabled)
                                ? 1.0
                                : 0.45,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Recordatorio post-actividad',
                                        style: AppTheme.bodyStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Te avisa 10 min después de terminar un horario si olvidaste marcarlo',
                                        style: AppTheme.bodyStyle(
                                          fontSize: 11.5,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _notificationsEnabled &&
                                      settings.notificationsEnabled &&
                                      settings.postActivityReminderEnabled,
                                  activeThumbColor: accent,
                                  onChanged: (_notificationsEnabled && settings.notificationsEnabled)
                                      ? (val) async {
                                          HapticFeedback.selectionClick();
                                          await ref
                                              .read(settingsProvider.notifier)
                                              .updateSettings(
                                                settings.copyWith(
                                                  postActivityReminderEnabled: val,
                                                ),
                                              );
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, thickness: 1, color: borderColor),
                          const SizedBox(height: 12),

                          // Lista integrada RECORDATORIOS CONFIGURADOS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'RECORDATORIOS CONFIGURADOS',
                                style: AppTheme.monoStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: secondaryText,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.30),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  '${activeReminders.length}',
                                  style: AppTheme.monoStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (activeReminders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.obsidianSurfaceElevated
                                    : AppTheme.boneSurfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor, width: 1.0),
                              ),
                              child: Text(
                                'No hay recordatorios individuales activos',
                                style: AppTheme.bodyStyle(
                                  fontSize: 11.5,
                                  color: secondaryText,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: activeReminders.map((item) {
                                final itemColor = Color(item.colorValue);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppTheme.obsidianSurfaceElevated
                                        : AppTheme.boneSurfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor, width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: itemColor,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.bodyStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryText,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.scheduleLabel,
                                              style: AppTheme.monoStyle(
                                                fontSize: 10.5,
                                                color: secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: itemColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(5),
                                          border: Border.all(
                                            color: itemColor.withValues(alpha: 0.35),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: AppTheme.monoStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: itemColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        key: Key('delete_reminder_${item.id}'),
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _deleteReminder(item, isDark),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB91C1C)
                                                .withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFB91C1C)
                                                  .withValues(alpha: 0.28),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Text(
                                            '✕',
                                            style: AppTheme.monoStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 5. MEDALLAS Y LOGROS
                _buildSectionHeader('Tus Medallas', isDark),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => const FractionallySizedBox(
                        heightFactor: 0.85,
                        child: AchievementsSheet(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.emoji_events_rounded, color: accent, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Ver Medallas y Logros',
                              style: AppTheme.bodyStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 5B. NOVEDADES DE LA VERSIÓN
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ReleaseNotesSheet.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF84A59D).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF84A59D),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Novedades de la versión (v$kCurrentAppVersion)',
                                      style: AppTheme.bodyStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppTheme.obsidianTextPrimary
                                            : AppTheme.boneTextPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Consulta los últimos cambios y mejoras',
                                      style: AppTheme.bodyStyle(
                                        fontSize: 11.5,
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
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // 7. BOTÓN GUARDAR CAMBIOS
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppTheme.accentPhosphor : AppTheme.boneTextPrimary,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Guardar Cambios',
                      style: AppTheme.displayStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'ORBITHABIT · v$kCurrentAppVersion',
                    style: AppTheme.monoStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: AppTheme.displayStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
      ),
    );
  }

  Widget _buildThemeOption({
    required String id,
    required String label,
    required String subtitle,
    required Color bgColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final accent = AppTheme.dynamicAccent(isDark);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white24 : AppTheme.boneBorder,
                      width: 1.5,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTheme.displayStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTheme.bodyStyle(
                fontSize: 11,
                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

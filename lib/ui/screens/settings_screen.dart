import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../widgets/achievements_sheet.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  late int _notificationHour;
  late int _notificationMinute;
  late String _themeMode;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController.text = settings.userName;
    _notificationHour = settings.notificationHour;
    _notificationMinute = settings.notificationMinute;
    _themeMode = settings.themeMode;
  }

  @override
  void dispose() {
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

  Future<void> _selectNotificationTime() async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notificationHour, minute: _notificationMinute),
      builder: (context, child) {
        return Theme(
          data: isDark ? AppTheme.buildDarkTheme() : AppTheme.buildLightTheme(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _notificationHour = picked.hour;
        _notificationMinute = picked.minute;
      });
    }
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
        current = current.add(const Duration(days: 1));
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

  void _saveSettings() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updated = UserSettings(
      userName: name,
      avatarEmoji: '',
      avatarColorValue: 0,
      notificationHour: _notificationHour,
      notificationMinute: _notificationMinute,
      themeMode: _themeMode,
      isFirstTime: false,
      vacationDates: ref.read(settingsProvider).vacationDates,
    );

    ref.read(settingsProvider.notifier).updateSettings(updated);
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);
    final initials = _getUserInitials(_nameController.text);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo Vacaciones',
                            style: AppTheme.bodyStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
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
                      Row(
                        children: [
                          if (settings.vacationDates.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: Colors.redAccent),
                              onPressed: _clearVacations,
                            ),
                          ElevatedButton(
                            onPressed: _pickVacationDates,
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

                // 4. RECORDATORIO DIARIO
                _buildSectionHeader('Notificaciones Diarias', isDark),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hora del Recordatorio',
                            style: AppTheme.bodyStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')}',
                            style: AppTheme.monoStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _selectNotificationTime,
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
                          'Cambiar Hora',
                          style: AppTheme.bodyStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 36),

                // 6. BOTÓN GUARDAR CAMBIOS
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
              ],
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

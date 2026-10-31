import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/backup_service.dart';
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

                // 6. DATOS, BACKUP Y LABORATORIO
                _buildSectionHeader('Datos, Backup y Laboratorio', isDark),
                const SizedBox(height: 12),
                _buildDataManagementSection(isDark),
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

  Widget _buildDataManagementSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildActionRow(
            isDark: isDark,
            icon: Icons.file_upload_outlined,
            iconColor: AppTheme.accentPhosphor,
            title: 'Exportar Copia de Seguridad',
            subtitle: 'Copia tus hábitos y turnos en JSON al portapapeles',
            onTap: () => _exportBackup(isDark),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          ),
          _buildActionRow(
            isDark: isDark,
            icon: Icons.file_download_outlined,
            iconColor: Colors.blueAccent,
            title: 'Restaurar Copia de Seguridad',
            subtitle: 'Importa tus datos pegando un JSON exportado',
            onTap: () => _showImportBackupDialog(isDark),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          ),
          _buildActionRow(
            isDark: isDark,
            icon: Icons.bolt_rounded,
            iconColor: Colors.amberAccent,
            title: 'Cargar Órbita Demo',
            subtitle: 'Inyecta turnos rotativos y hábitos de muestra',
            onTap: () => _loadDemoData(isDark),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          ),
          _buildActionRow(
            isDark: isDark,
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.redAccent,
            title: 'Purgar Todos los Datos',
            subtitle: 'Borra todos los hábitos, bloques y vacaciones',
            isDanger: true,
            onTap: () => _wipeAllData(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.displayStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDanger
                          ? Colors.redAccent
                          : (isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _exportBackup(bool isDark) {
    HapticFeedback.mediumImpact();
    final habits = ref.read(habitsProvider);
    final blocks = ref.read(scheduleProvider);
    final settings = ref.read(settingsProvider);
    final jsonStr = BackupService.exportToJson(
      habits: habits,
      blocks: blocks,
      settings: settings,
    );
    Clipboard.setData(ClipboardData(text: jsonStr));
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
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.accentPhosphor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copia JSON copiada al portapapeles',
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportBackupDialog(bool isDark) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          ),
        ),
        title: Text(
          'Restaurar Backup JSON',
          style: AppTheme.displayStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pega a continuación el código JSON que exportaste previamente:',
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              style: AppTheme.monoStyle(
                fontSize: 11,
                color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '{\n  "version": 1,\n  "habits": [...]\n}',
                hintStyle: AppTheme.monoStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                ),
                filled: true,
                fillColor: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              try {
                final data = BackupService.parseFromJson(text);
                await ref.read(habitsProvider.notifier).replaceAllHabits(data.habits);
                await ref.read(scheduleProvider.notifier).replaceAllBlocks(data.blocks);
                await ref.read(settingsProvider.notifier).updateSettings(
                  ref.read(settingsProvider).copyWith(vacationDates: data.vacationDates),
                );
                if (!mounted) return;
                Navigator.of(ctx).pop();
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Text(
                      'Backup restaurado: ${data.habits.length} hábitos y ${data.blocks.length} turnos.',
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                      ),
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Text(
                      'Error al restaurar: Formato JSON no válido',
                      style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.accentPhosphor : AppTheme.boneTextPrimary,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'Restaurar',
              style: AppTheme.displayStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDemoData(bool isDark) async {
    HapticFeedback.mediumImpact();
    final demo = DemoSeederService.generateDemoData(DateTime.now());
    await ref.read(habitsProvider.notifier).replaceAllHabits(demo.habits);
    await ref.read(scheduleProvider.notifier).replaceAllBlocks(demo.blocks);
    if (!mounted) return;
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
        content: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppTheme.accentPhosphor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Órbita Demo cargada (${demo.habits.length} hábitos, ${demo.blocks.length} turnos)',
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _wipeAllData(bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
          ),
        ),
        title: Text(
          '¿Eliminar todos los datos?',
          style: AppTheme.displayStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Esta acción borrará irreversiblemente todos tus hábitos, bloques de turnos y vacaciones configuradas.',
          style: AppTheme.bodyStyle(
            fontSize: 13,
            color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'Eliminar Todo',
              style: AppTheme.displayStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(habitsProvider.notifier).replaceAllHabits([]);
      await ref.read(scheduleProvider.notifier).replaceAllBlocks([]);
      await ref.read(settingsProvider.notifier).clearVacationDates();
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Todos los datos han sido purgados.',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
          ),
        ),
      );
    }
  }
}

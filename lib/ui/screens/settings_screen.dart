import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_settings.dart';
import '../../providers/settings_provider.dart';
import 'manage_habits_screen.dart';
import '../widgets/achievements_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  late String _selectedEmoji;
  late int _selectedColorValue;
  late int _notificationHour;
  late int _notificationMinute;
  late String _themeMode;

  final List<String> _emojis = ['🧘', '🌿', '🌊', '⛰️', '🌸', '☀️', '🍵', '🕯️', '🕊️'];

  final List<Color> _palette = const [
    Color(0xFF84A59D), // Verde Salvia
    Color(0xFFB5A6C9), // Azul Lavanda
    Color(0xFFF2C6B4), // Melocotón Suave
    Color(0xFFE5D08F), // Mostaza / Arena
    Color(0xFF9EA1D4), // Periwinkle
    Color(0xFFE5989B), // Rosa Empolvado
    Color(0xFFA8C2D3), // Gris Invierno
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController.text = settings.userName;
    _selectedEmoji = settings.avatarEmoji;
    _selectedColorValue = settings.avatarColorValue;
    _notificationHour = settings.notificationHour;
    _notificationMinute = settings.notificationMinute;
    _themeMode = settings.themeMode;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notificationHour, minute: _notificationMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(_selectedColorValue), // Header color
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
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
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecciona tus días de descanso',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(_selectedColorValue),
              onPrimary: Colors.white,
              onSurface: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      List<DateTime> dates = [];
      DateTime current = picked.start;
      // Normalizamos las horas al inicio del día por si acaso
      current = DateTime(current.year, current.month, current.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        dates.add(current);
        current = current.add(const Duration(days: 1));
      }
      await ref.read(settingsProvider.notifier).addVacationDates(dates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Modo Vacaciones programado! 🏖️')),
        );
      }
    }
  }

  void _clearVacations() {
    ref.read(settingsProvider.notifier).clearVacationDates();
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vacaciones borradas 🧹')),
    );
  }

  void _saveSettings() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updated = UserSettings(
      userName: name,
      avatarEmoji: _selectedEmoji,
      avatarColorValue: _selectedColorValue,
      notificationHour: _notificationHour,
      notificationMinute: _notificationMinute,
      themeMode: _themeMode,
      isFirstTime: false,
      vacationDates: ref.read(settingsProvider).vacationDates,
    );

    ref.read(settingsProvider.notifier).updateSettings(updated);
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes Zen', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Vista Previa del Avatar
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Color(_selectedColorValue),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(_selectedColorValue).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedEmoji,
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Previsualización del Avatar',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor?.withOpacity(0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 2. Campo del Nombre
            Text(
              'Tu Nombre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              maxLength: 16,
              decoration: InputDecoration(
                hintText: 'Introduce tu nombre...',
                hintStyle: TextStyle(color: textColor?.withOpacity(0.4)),
                counterText: '',
                fillColor: cardColor,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(_selectedColorValue), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 3. Logros y Trofeos
            Text(
              'Tus Logros',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, color: const Color(0xFFFFD700)), // Gold color
                        const SizedBox(width: 12),
                        const Text('Ver Medallas', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    Icon(Icons.chevron_right_rounded, color: textColor?.withOpacity(0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 4. Emojis Zen
            Text(
              'Icono de tu Avatar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  final emoji = _emojis[index];
                  final isSelected = _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedEmoji = emoji);
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(_selectedColorValue).withOpacity(0.15) : cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Color(_selectedColorValue) : Colors.grey.withOpacity(0.15),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),

            // 4. Color de Fondo del Avatar
            Text(
              'Color del Avatar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _palette.map((color) {
                final isSelected = _selectedColorValue == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorValue = color.value);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3.5) : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // 5. Configuración de Alarma
            Text(
              'Recordatorio Diario',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, color: Color(_selectedColorValue)),
                        const SizedBox(width: 12),
                        const Text('Notificar a las:', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    Text(
                      '${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(_selectedColorValue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 6. Selección de Temas (Claro, Oscuro, Sage)
            Text(
              'Tema Visual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Row(
                  children: [
                    _ThemeCapsule(
                      label: 'Automático',
                      themeKey: 'system',
                      isActive: _themeMode == 'system',
                      activeColor: Color(_selectedColorValue),
                      onTap: () => setState(() => _themeMode = 'system'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeCapsule(
                      label: 'Crema',
                      themeKey: 'light',
                      isActive: _themeMode == 'light',
                      activeColor: Color(_selectedColorValue),
                      onTap: () => setState(() => _themeMode = 'light'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ThemeCapsule(
                      label: 'Pizarra',
                      themeKey: 'dark',
                      isActive: _themeMode == 'dark',
                      activeColor: Color(_selectedColorValue),
                      onTap: () => setState(() => _themeMode = 'dark'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeCapsule(
                      label: 'OLED',
                      themeKey: 'oled',
                      isActive: _themeMode == 'oled',
                      activeColor: Color(_selectedColorValue),
                      onTap: () => setState(() => _themeMode = 'oled'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeCapsule(
                      label: 'Bosque',
                      themeKey: 'sage',
                      isActive: _themeMode == 'sage',
                      activeColor: Color(_selectedColorValue),
                      onTap: () => setState(() => _themeMode = 'sage'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 7. Modo Vacaciones
            Text(
              'Modo Descanso 🏖️',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _pickVacationDates();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight_takeoff_rounded, color: Color(_selectedColorValue)),
                        const SizedBox(width: 12),
                        const Text('Programar Vacaciones', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    Icon(Icons.date_range_rounded, color: textColor?.withOpacity(0.4)),
                  ],
                ),
              ),
            ),
            if (ref.watch(settingsProvider).vacationDates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearVacations,
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                  label: const Text('Borrar días de descanso', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // 8. Gestión de Hábitos
            Text(
              'Hábitos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor?.withOpacity(0.8)),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageHabitsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_road_rounded, color: Color(_selectedColorValue)),
                        const SizedBox(width: 12),
                        const Text('Reordenar, Editar y Eliminar', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    Icon(Icons.chevron_right_rounded, color: textColor?.withOpacity(0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // 9. Botón de Guardado
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(_selectedColorValue),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Guardar Ajustes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),


          ],
        ),
      ),
    );
  }
}

class _ThemeCapsule extends StatelessWidget {
  final String label;
  final String themeKey;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ThemeCapsule({
    required this.label,
    required this.themeKey,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          onTap();
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withOpacity(0.12) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? activeColor : Colors.grey.withOpacity(0.15),
              width: isActive ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? activeColor : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

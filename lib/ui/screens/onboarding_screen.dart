import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/user_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/habit_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/backup_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de Onboarding con Estética Swiss Precision (Neo-Bento).
/// Presenta los fundamentos de OrbitHabit:
/// Slide 1: Rueda Orbital Mensual de 31 días.
/// Slide 2: Reloj 24H en tiempo real y Cuadrante de Turnos.
/// Slide 3: Perfil del Operador, Selector de Tema (Obsidiana / Hueso) y Carga Demo.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController(text: 'Arturo');
  int _currentPage = 0;

  String _themeMode = 'dark';
  bool _loadDemoData = false;
  String _selectedEmoji = '🧘';
  int _selectedColorValue = 0xFF84A59D;

  final List<String> _emojis = ['🧘', '⚡', '🌙', '🌊', '⛰️', '🎯', '🪐', '🕯️', '🕊️'];

  final List<Color> _palette = const [
    Color(0xFF84A59D), // Verde Salvia
    Color(0xFFB5A6C9), // Lavanda Técnico
    Color(0xFFF2C6B4), // Melocotón Suizo
    Color(0xFFE5D08F), // Arena
    Color(0xFF9EA1D4), // Azul Periwinkle
    Color(0xFFE5989B), // Rosa Fósforo
    Color(0xFFA8C2D3), // Cobalto Nórdico
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding(bool asGuest) async {
    HapticFeedback.heavyImpact();

    final name = asGuest
        ? 'Arturo'
        : (_nameController.text.trim().isEmpty ? 'Arturo' : _nameController.text.trim());
    final emoji = asGuest ? '🧘' : _selectedEmoji;
    final color = asGuest ? 0xFF84A59D : _selectedColorValue;
    final theme = asGuest ? 'dark' : _themeMode;

    final updatedSettings = UserSettings(
      userName: name,
      avatarEmoji: emoji,
      avatarColorValue: color,
      notificationHour: 21,
      notificationMinute: 0,
      themeMode: theme,
      isFirstTime: false,
      vacationDates: [],
    );

    await ref.read(settingsProvider.notifier).updateSettings(updatedSettings);

    if (!asGuest && _loadDemoData) {
      final demo = DemoSeederService.generateDemoData(DateTime.now());
      await ref.read(habitsProvider.notifier).replaceAllHabits(demo.habits);
      await ref.read(scheduleProvider.notifier).replaceAllBlocks(demo.blocks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeMode == 'dark';
    final accent = AppTheme.dynamicAccent(isDark);
    final primaryColor = Color(_selectedColorValue);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.obsidianCanvas : AppTheme.boneCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior: Salto rápido como Invitado
            SizedBox(
              height: 48,
              child: Visibility(
                visible: _currentPage < 2,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: TextButton(
                      onPressed: () => _finishOnboarding(true),
                      child: Text(
                        'Omitir / Invitado',
                        style: AppTheme.monoStyle(
                          color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Contenedor principal con PageView y Keys estables para tests
            Expanded(
              key: const ValueKey('onboarding_pageview_expanded'),
              child: PageView(
                key: const ValueKey('onboarding_pageview'),
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  HapticFeedback.selectionClick();
                },
                children: [
                  // SLIDE 1: Rueda Orbital Mensual
                  _buildSlide(
                    isDark: isDark,
                    accent: accent,
                    technicalTag: '01 // ÓRBITA MENSUAL',
                    title: 'Sintoniza tu Vida',
                    description:
                        'Bienvenido a OrbitHabit.\nUna forma circular, nítida y orgánica de observar tu constancia. Cada hábito es un anillo concéntrico de 31 días donde el espacio limpio es descanso real y los días completados brillan con precisión.',
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: OnboardingArtPainter(
                        step: 1,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        accentColor: accent,
                      ),
                    ),
                  ),

                  // SLIDE 2: Reloj 24H y Cuadrante de Turnos
                  _buildSlide(
                    isDark: isDark,
                    accent: accent,
                    technicalTag: '02 // RELOJ 24H & TURNOS',
                    title: 'El Método Orbital',
                    description:
                        'Esfera polar de 24 horas y cuadrante de turnos.\nMapea tus rutinas en tiempo real, sincroniza turnos nocturnos que cruzan la medianoche sin desfases y planifica meses completos con un solo toque.',
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: OnboardingArtPainter(
                        step: 2,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        accentColor: accent,
                      ),
                    ),
                  ),

                  // SLIDE 3: Configuración del Operador
                  _buildProfileSetupSlide(isDark, accent, primaryColor),
                ],
              ),
            ),

            // Barra inferior con Paginación y Botón Siguiente
            Visibility(
              visible: _currentPage < 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isSelected = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 24 : 8,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent
                              : (isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorderHover),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.radiusSm,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Siguiente',
                          style: AppTheme.displayStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required bool isDark,
    required Color accent,
    required String technicalTag,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 36),
          Text(
            technicalTag,
            style: AppTheme.monoStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.displayStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupSlide(bool isDark, Color accent, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera del Operador
          Center(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _selectedEmoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '03 // PERFIL DE TELEMETRÍA',
                  style: AppTheme.monoStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configuración del Operador',
                  style: AppTheme.displayStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. Campo de Nombre
          Text(
            'Nombre o Alias',
            style: AppTheme.displayStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            maxLength: 16,
            style: AppTheme.displayStyle(
              fontSize: 14,
              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Tu nombre...',
              hintStyle: AppTheme.bodyStyle(
                fontSize: 13,
                color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
              ),
              counterText: '',
              filled: true,
              fillColor: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusSm,
                borderSide: BorderSide(
                  color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.radiusSm,
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Selector de Emoji
          Text(
            'Icono de Avatar',
            style: AppTheme.displayStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
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
                    duration: const Duration(milliseconds: 180),
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.15) : (isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface),
                      borderRadius: AppTheme.radiusXs,
                      border: Border.all(
                        color: isSelected ? accent : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Selector de Color de Acento
          Text(
            'Color de Acento',
            style: AppTheme.displayStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _palette.map((color) {
                final isSelected = _selectedColorValue == color.value;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorValue = color.value);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? (isDark ? Colors.white : Colors.black) : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Selector de Tema (Obsidiana vs Hueso)
          Text(
            'Tema Visual Inicial',
            style: AppTheme.displayStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _themeMode = 'dark');
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurface,
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(
                        color: _themeMode == 'dark' ? accent : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                        width: _themeMode == 'dark' ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF09090B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Obsidiana',
                            style: AppTheme.displayStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ),
                        if (_themeMode == 'dark')
                          Icon(Icons.check_circle_rounded, size: 16, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _themeMode = 'light');
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: !isDark ? AppTheme.boneSurfaceElevated : AppTheme.obsidianSurface,
                      borderRadius: AppTheme.radiusSm,
                      border: Border.all(
                        color: _themeMode == 'light' ? accent : (isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder),
                        width: _themeMode == 'light' ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400, width: 1.0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hueso',
                            style: AppTheme.displayStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ),
                        if (_themeMode == 'light')
                          Icon(Icons.check_circle_rounded, size: 16, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Toggle Opcional: Cargar Órbita Demo
          GestureDetector(
            onTap: () {
              setState(() => _loadDemoData = !_loadDemoData);
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: AppTheme.bentoCard(
                isLight: !isDark,
                borderRadius: AppTheme.radiusSm,
                borderColor: _loadDemoData ? accent.withValues(alpha: 0.5) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 20,
                    color: _loadDemoData ? accent : (isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cargar datos de demostración',
                          style: AppTheme.displayStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Inyecta turnos rotativos y hábitos para explorar la app de inmediato',
                          style: AppTheme.bodyStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _loadDemoData,
                    activeColor: accent,
                    onChanged: (val) {
                      setState(() => _loadDemoData = val);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 5. Botón de Inicialización Final
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _finishOnboarding(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                elevation: 0,
              ),
              child: Text(
                'Inicializar Sistema',
                style: AppTheme.displayStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.black : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Pintor vectorial con estética de anteproyecto técnico suizo (Blueprint)
class OnboardingArtPainter extends CustomPainter {
  final int step;
  final bool isDark;
  final Color primaryColor;
  final Color accentColor;

  OnboardingArtPainter({
    required this.step,
    required this.isDark,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final gridLineColor = isDark ? const Color(0x18FFFFFF) : const Color(0xFFE2E4E8);

    final linePaint = Paint()
      ..color = gridLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (step == 1) {
      // 1. Rueda Orbital con retícula y arcos técnicos
      final r1 = size.width * 0.44;
      final r2 = size.width * 0.34;
      final r3 = size.width * 0.24;

      canvas.drawCircle(center, r1, linePaint);
      canvas.drawCircle(center, r2, linePaint);
      canvas.drawCircle(center, r3, linePaint);

      // Cruces técnicas en los ejes
      _drawCross(canvas, center.dx, center.dy - r1, accentColor);
      _drawCross(canvas, center.dx, center.dy + r1, accentColor);
      _drawCross(canvas, center.dx - r1, center.dy, accentColor);
      _drawCross(canvas, center.dx + r1, center.dy, accentColor);

      // Arcos orbitales completados iluminados
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6.0;

      // Anillo exterior (accent)
      arcPaint.color = accentColor;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r1), -math.pi * 0.6, math.pi * 0.9, false, arcPaint);

      // Anillo medio (primaryColor)
      arcPaint.color = primaryColor;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r2), -math.pi * 0.2, math.pi * 1.1, false, arcPaint);

      // Anillo interior (salvia/lavanda)
      arcPaint.color = const Color(0xFF9EA1D4);
      canvas.drawArc(Rect.fromCircle(center: center, radius: r3), math.pi * 0.4, math.pi * 0.7, false, arcPaint);

      // Núcleo central
      final corePaint = Paint()..color = accentColor.withValues(alpha: 0.15);
      canvas.drawCircle(center, 18, corePaint);
      final dotPaint = Paint()..color = accentColor;
      canvas.drawCircle(center, 4, dotPaint);
    } else {
      // 2. Reloj 24H y Dial Circadiano
      final r = size.width * 0.42;
      canvas.drawCircle(center, r, linePaint);
      canvas.drawCircle(center, r * 0.75, linePaint);

      // Marcas radiales de las 24 horas
      final tickPaint = Paint()
        ..color = gridLineColor
        ..strokeWidth = 1.2;
      for (int h = 0; h < 24; h++) {
        final angle = -math.pi / 2 + (h / 24.0) * 2 * math.pi;
        final isMajor = h % 6 == 0;
        final inner = r - (isMajor ? 8.0 : 4.0);
        final p1 = Offset(center.dx + inner * math.cos(angle), center.dy + inner * math.sin(angle));
        final p2 = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        tickPaint.strokeWidth = isMajor ? 1.5 : 0.8;
        canvas.drawLine(p1, p2, tickPaint);
      }

      // Bloque de Mañana (07:00 a 15:00)
      final morningPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round
        ..color = accentColor;
      final startAngle1 = -math.pi / 2 + (7.0 / 24.0) * 2 * math.pi;
      final sweepAngle1 = (8.0 / 24.0) * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.88), startAngle1, sweepAngle1, false, morningPaint);

      // Bloque Nocturno (23:00 a 07:00) cruzando medianoche
      final nightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9EA1D4);
      final startAngle2 = -math.pi / 2 + (23.0 / 24.0) * 2 * math.pi;
      final sweepAngle2 = (8.0 / 24.0) * 2 * math.pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.88), startAngle2, sweepAngle2, false, nightPaint);

      // Satélite indicador en vivo
      const nowAngle = -math.pi / 2 + (14.0 / 24.0) * 2 * math.pi;
      final satPos = Offset(center.dx + r * 0.88 * math.cos(nowAngle), center.dy + r * 0.88 * math.sin(nowAngle));
      final satGlowPaint = Paint()..color = accentColor.withValues(alpha: 0.3);
      canvas.drawCircle(satPos, 8, satGlowPaint);
      final satDotPaint = Paint()..color = isDark ? Colors.white : Colors.black;
      canvas.drawCircle(satPos, 3.5, satDotPaint);
    }
  }

  void _drawCross(Canvas canvas, double x, double y, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    const s = 4.0;
    canvas.drawLine(Offset(x - s, y), Offset(x + s, y), paint);
    canvas.drawLine(Offset(x, y - s), Offset(x, y + s), paint);
  }

  @override
  bool shouldRepaint(covariant OnboardingArtPainter oldDelegate) {
    return oldDelegate.step != step ||
        oldDelegate.isDark != isDark ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/user_settings.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final _nameController = TextEditingController(text: 'Arturo');
  int _currentPage = 0;

  String _selectedEmoji = '🧘';
  int _selectedColorValue = 0xFF84A59D; // Verde Salvia

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
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishOnboarding(bool asGuest) {
    HapticFeedback.heavyImpact();
    
    // Save to Hive and trigger reactive root fade transition
    final updatedSettings = UserSettings(
      userName: asGuest ? 'Arturo' : _nameController.text.trim(),
      avatarEmoji: asGuest ? '🧘' : _selectedEmoji,
      avatarColorValue: asGuest ? 0xFF84A59D : _selectedColorValue,
      notificationHour: 21,
      notificationMinute: 0,
      themeMode: 'light', // Starts Crema light
      isFirstTime: false,  // Disables onboarding guard
      vacationDates: [],
    );

    ref.read(settingsProvider.notifier).updateSettings(updatedSettings);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(_selectedColorValue);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F3), // Crema Zen
      body: SafeArea(
        child: Column(
          children: [
            // Top Skip / Guest button wrapped in fixed height SizedBox and Visibility to keep tree stable
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
                        'Entrar como Invitado',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF707A8A).withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main PageView Slides with stable keys
            Expanded(
              key: const ValueKey('onboarding_pageview_expanded'),
              child: PageView(
                key: const ValueKey('onboarding_pageview'),
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                  HapticFeedback.selectionClick();
                },
                children: [
                  // Slide 1: Welcome
                  _buildSlide(
                    title: 'Sintoniza tu Vida',
                    description: 'Bienvenido a OrbitHabit.\nUna forma distinta, circular y orgánica de observar tu constancia. Sin presiones, a tu propio ritmo.',
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: OnboardingArtPainter(step: 1, primaryColor: const Color(0xFF84A59D)),
                    ),
                  ),
                  // Slide 2: Concept
                  _buildSlide(
                    title: 'El Método Orbital',
                    description: 'Cada hábito es un color, cada día una órbita completada.\nObserva tu consistencia mensual con un gráfico sutil, armónico y equilibrado.',
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: OnboardingArtPainter(step: 2, primaryColor: const Color(0xFF84A59D)),
                    ),
                  ),
                  // Slide 3: Initial Profile Configuration (Zen & Frictionless)
                  _buildProfileSetupSlide(primaryColor),
                ],
              ),
            ),

            // Indicator dots & button section wrapped in Visibility to preserve tree structure
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
                        width: isSelected ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF84A59D) : const Color(0xFF707A8A).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF84A59D), // Salvia
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Siguiente',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  Widget _buildSlide({required String title, required String description, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          child,
          const SizedBox(height: 48),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF707A8A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFF707A8A).withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupSlide(Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _selectedEmoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Personaliza tu Órbita',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF707A8A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dinos tu nombre y configura tu avatar Zen.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF707A8A).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Name input field
          Text(
            'Tu Nombre',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF707A8A).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: GoogleFonts.outfit(color: const Color(0xFF707A8A)),
            maxLength: 16,
            decoration: InputDecoration(
              hintText: 'Cómo te llamas...',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF707A8A).withOpacity(0.4)),
              counterText: '',
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Emoji selector
          Text(
            'Icono de tu Avatar',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF707A8A).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
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
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor.withOpacity(0.12) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? primaryColor : Colors.grey.withOpacity(0.15),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Color selector
          Text(
            'Color de tu Órbita',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF707A8A).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _palette.map((color) {
              final isSelected = _selectedColorValue == color.value;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedColorValue = color.value);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 3.0) : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _finishOnboarding(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Comenzar mi Viaje 🌿',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingArtPainter extends CustomPainter {
  final int step;
  final Color primaryColor;

  OnboardingArtPainter({required this.step, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width * 0.5, size.height * 0.5);

    if (step == 1) {
      // Concentric ripple circles (expanding orbits)
      final fillPaint = Paint()
        ..color = primaryColor.withOpacity(0.08)
        ..style = PaintingStyle.fill;

      paint.color = primaryColor.withOpacity(0.12);
      canvas.drawCircle(center, size.width * 0.4, paint);
      
      paint.color = primaryColor.withOpacity(0.24);
      canvas.drawCircle(center, size.width * 0.28, paint);

      canvas.drawCircle(center, size.width * 0.16, fillPaint);
      paint.color = primaryColor;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(center, size.width * 0.08, paint);
    } else if (step == 2) {
      // Balanced horseshoe OrbitTracker mockup
      paint.color = primaryColor.withOpacity(0.08);
      canvas.drawCircle(center, size.width * 0.38, paint);

      final rect = Rect.fromCircle(center: center, radius: size.width * 0.3);
      const startAngle = math.pi;
      const sweepAngle = math.pi * 1.5;

      paint.color = primaryColor.withOpacity(0.15);
      paint.strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      final cellPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle + 0.2, 0.4, false, cellPaint);
      
      cellPaint.color = primaryColor.withOpacity(0.5);
      canvas.drawArc(rect, startAngle + 0.8, 0.5, false, cellPaint);

      paint.style = PaintingStyle.fill;
      paint.color = primaryColor.withOpacity(0.12);
      canvas.drawCircle(center, size.width * 0.1, paint);
    }
  }

  @override
  // Return false because these are static, highly optimized vector illustrations.
  // This guarantees 0 redrawing/repainting cycles on the PageView scroll!
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

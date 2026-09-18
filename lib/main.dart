import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/database_service.dart';
import 'providers/habit_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dbService = DatabaseService();
  await dbService.init();

  // Precache Zen sounds in RAM on startup (sin bloquear la carga)
  SoundService().init();

  // Inicializamos notificaciones sin bloquear la app
  final notifService = NotificationService();
  notifService.init().then((_) {
    notifService.requestPermissions().then((_) {
      notifService.scheduleDailyReminder(hour: 21, minute: 0);
    });
  }).catchError((error) {
    print("Error inicializando notificaciones: $error");
  });

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(dbService),
      ],
      child: const OrbitHabitApp(),
    ),
  );
}

class OrbitHabitApp extends ConsumerWidget {
  const OrbitHabitApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    ThemeMode appThemeMode = ThemeMode.system;
    ThemeData lightTheme = _buildLightTheme();
    ThemeData darkTheme = _buildDarkTheme(); // Pizarra

    if (settings.themeMode == 'light') {
      appThemeMode = ThemeMode.light;
    } else if (settings.themeMode == 'dark') {
      appThemeMode = ThemeMode.dark;
    } else if (settings.themeMode == 'oled') {
      appThemeMode = ThemeMode.dark;
      darkTheme = _buildOledTheme();
    } else if (settings.themeMode == 'sage') {
      appThemeMode = ThemeMode.light;
      lightTheme = _buildSageTheme();
      darkTheme = _buildSageTheme(); 
    } else {
      appThemeMode = ThemeMode.system;
    }

    return MaterialApp(
      title: 'OrbitHabit',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appThemeMode,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: settings.isFirstTime
            ? const OnboardingScreen(key: ValueKey('onboarding'))
            : const HomeScreen(key: ValueKey('home')),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F7F3), // Crema Zen
      cardColor: const Color(0xFFFFFFFF),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF707A8A), // Gris azulado pizarroso
        displayColor: const Color(0xFF707A8A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF707A8A)),
        titleTextStyle: TextStyle(color: Color(0xFF707A8A), fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1C1F26), // Pizarra Oscuro
      cardColor: const Color(0xFF252932),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFE2E8F0),
        displayColor: const Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE2E8F0)),
        titleTextStyle: TextStyle(color: Color(0xFFE2E8F0), fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  ThemeData _buildSageTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFE2E7DF), // Bosque Salvia
      cardColor: const Color(0xFFECF1EB),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: const Color(0xFF4A5545), // Gris bosque oscuro
        displayColor: const Color(0xFF4A5545),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF4A5545)),
        titleTextStyle: TextStyle(color: Color(0xFF4A5545), fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  ThemeData _buildOledTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000), // Negro OLED Puro
      cardColor: const Color(0xFF121212), // Gris muy oscuro
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFE2E8F0),
        displayColor: const Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE2E8F0)),
        titleTextStyle: TextStyle(color: Color(0xFFE2E8F0), fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }
}

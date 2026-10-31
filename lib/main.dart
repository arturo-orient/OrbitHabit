import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/database_service.dart';
import 'providers/habit_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dbService = DatabaseService();
  await dbService.init();

  // Precache Zen sounds in RAM on startup (sin bloquear la carga)
  SoundService().init();

  // Inicializamos notificaciones solo en plataformas soportadas (móvil)
  if (!kIsWeb) {
    final notifService = NotificationService();
    notifService.init().then((_) {
      notifService.requestPermissions().then((_) {
        notifService.scheduleDailyReminder(hour: 21, minute: 0);
      });
    }).catchError((error) {
      print("Error inicializando notificaciones: $error");
    });
  }

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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
    return AppTheme.buildLightTheme();
  }

  ThemeData _buildDarkTheme() {
    return AppTheme.buildDarkTheme();
  }

  ThemeData _buildSageTheme() {
    return AppTheme.buildLightTheme();
  }

  ThemeData _buildOledTheme() {
    return AppTheme.buildDarkTheme();
  }
}

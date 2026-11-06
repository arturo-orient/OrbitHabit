import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orbithabit/data/database_service.dart';
import 'package:orbithabit/domain/models/habit.dart';
import 'package:orbithabit/domain/models/schedule_block.dart';
import 'package:orbithabit/domain/models/user_settings.dart';
import 'package:orbithabit/providers/habit_provider.dart';
import 'package:orbithabit/providers/schedule_provider.dart';
import 'package:orbithabit/providers/settings_provider.dart';
import 'package:orbithabit/services/schedule_poster_service.dart';
import 'package:orbithabit/ui/screens/home_screen.dart';
import 'package:orbithabit/ui/screens/settings_screen.dart';
import 'package:orbithabit/ui/screens/shift_calendar_screen.dart';
import 'package:orbithabit/ui/screens/statistics_screen.dart';
import 'package:orbithabit/ui/theme/app_theme.dart';
import 'package:orbithabit/ui/widgets/custom_color_picker_dialog.dart';
import 'package:orbithabit/ui/widgets/unified_task_sheet.dart';

class ScreenshotFakeDb extends DatabaseService {
  final Map<String, dynamic> _settings = {};
  final Map<String, Habit> _habits = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveHabit(Habit habit) async {
    _habits[habit.id] = habit;
  }

  @override
  Future<void> replaceAllHabits(List<Habit> habits) async {
    _habits.clear();
    for (final h in habits) {
      _habits[h.id] = h;
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    _habits.remove(id);
  }

  @override
  List<Habit> getAllHabits() => _habits.values.toList();

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }
}

Future<ByteData> _loadFontFileSync(String path) {
  final bytes = File(path).readAsBytesSync();
  return Future.value(ByteData.view(bytes.buffer));
}

Future<void> _registerSystemFontsForScreenshots() async {
  GoogleFonts.config.allowRuntimeFetching = false;

  const materialIconsPath =
      r'C:\Users\Artur\Desktop\APPS\Aplicacion\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf';
  const segoeRegPath = r'C:\Windows\Fonts\segoeui.ttf';
  const segoeBoldPath = r'C:\Windows\Fonts\segoeuib.ttf';
  const segoeSemiPath = r'C:\Windows\Fonts\seguisb.ttf';
  const consolaRegPath = r'C:\Windows\Fonts\consola.ttf';
  const consolaBoldPath = r'C:\Windows\Fonts\consolab.ttf';

  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(_loadFontFileSync(materialIconsPath));
  await iconLoader.load();

  final weights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];

  final sansFamilies = <String>{
    'Roboto',
    'FlutterTest',
    '.SF UI Text',
    '.SF Pro Text',
  };
  final monoFamilies = <String>{};

  for (final w in weights) {
    final dFam = AppTheme.displayStyle(fontWeight: w).fontFamily;
    final bFam = AppTheme.bodyStyle(fontWeight: w).fontFamily;
    final mFam = AppTheme.monoStyle(fontWeight: w).fontFamily;
    final oFam = GoogleFonts.outfit(fontWeight: w).fontFamily;
    if (dFam != null) sansFamilies.add(dFam);
    if (bFam != null) sansFamilies.add(bFam);
    if (oFam != null) sansFamilies.add(oFam);
    if (mFam != null) monoFamilies.add(mFam);
  }

  for (final fam in sansFamilies) {
    final isBold =
        fam.contains('700') || fam.contains('800') || fam.contains('900');
    final isSemi = fam.contains('600') || fam.contains('500');
    final fontPath = isBold
        ? segoeBoldPath
        : (isSemi && File(segoeSemiPath).existsSync()
            ? segoeSemiPath
            : segoeRegPath);
    final loader = FontLoader(fam)..addFont(_loadFontFileSync(fontPath));
    if (fam == 'Roboto' || fam == 'FlutterTest') {
      loader.addFont(_loadFontFileSync(segoeBoldPath));
    }
    await loader.load();
  }

  for (final fam in monoFamilies) {
    final isBold =
        fam.contains('700') || fam.contains('800') || fam.contains('600');
    final fontPath = isBold ? consolaBoldPath : consolaRegPath;
    final loader = FontLoader(fam)..addFont(_loadFontFileSync(fontPath));
    await loader.load();
  }
}

Future<void> _captureBoundaryToFile(
    GlobalKey boundaryKey, String outputPath) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes, flush: true);
}

void main() {
  testWidgets('Genera capturas profesionales v1.2.6 para el README de GitHub',
      (WidgetTester tester) async {
    const regenFlag = bool.fromEnvironment('REGEN_SCREENSHOTS');
    const segoeRegPath = r'C:\Windows\Fonts\segoeui.ttf';
    if (!regenFlag && File('assets/img/08_poster_mensual.png').existsSync()) {
      return;
    }
    if (!File(segoeRegPath).existsSync()) {
      return;
    }

    await tester.runAsync(() async {
      await _registerSystemFontsForScreenshots();
    });

    tester.view.physicalSize = const Size(960, 1880);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final todayIso =
        '$monthPrefix-${now.day.toString().padLeft(2, '0')}';

    Set<String> buildDates(List<int> days) {
      return days
          .map((d) => '$monthPrefix-${d.toString().padLeft(2, '0')}')
          .toSet();
    }

    final habitWork = Habit(
      id: 'h_work',
      name: 'Hospital // Turnos',
      colorValue: 0xFF84DCC6,
      targetDays: 18,
      orderIndex: 0,
      hasMonthlyTarget: false,
      completedDates: buildDates([1, 2, 3, 4, 5, 6]),
    );

    final habitGym = Habit(
      id: 'h_gym',
      name: 'Entrenamiento & Fuerza',
      colorValue: 0xFFE57A77,
      targetDays: 20,
      orderIndex: 1,
      completedDates: buildDates([1, 2, 4, 5, 6]),
      subTasks: [
        SubTask(
          id: 'st_1',
          title: 'Movilidad articular 10m',
          completedDates: {todayIso},
          orderIndex: 0,
        ),
        SubTask(
          id: 'st_2',
          title: 'Press banca & Dominadas',
          completedDates: {todayIso},
          orderIndex: 1,
        ),
        const SubTask(
          id: 'st_3',
          title: 'Estiramientos y Core',
          completedDates: {},
          orderIndex: 2,
        ),
      ],
    );

    final habitRead = Habit(
      id: 'h_read',
      name: 'Lectura Profunda',
      colorValue: 0xFFB5A6C9,
      targetDays: 25,
      orderIndex: 2,
      completedDates: buildDates([1, 2, 3, 4, 5, 6]),
    );

    final habitZen = Habit(
      id: 'h_zen',
      name: 'Mindfulness & Pausa',
      colorValue: 0xFFFFD166,
      targetDays: 25,
      orderIndex: 3,
      completedDates: buildDates([1, 3, 4, 5]),
    );

    final shiftMorning = ScheduleBlock(
      id: 'b_morning',
      title: 'Turno Mañana',
      startHour: 7,
      startMinute: 0,
      endHour: 15,
      endMinute: 0,
      colorValue: 0xFF84DCC6,
      habitId: 'h_work',
      daysOfWeek: const [1, 2, 3, 4, 5],
      hasMonthlyHourTarget: true,
      monthlyTargetHours: 120,
      assignedDates: [
        ...buildDates([1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13, 16, 17, 18]),
      ],
      completedDates: [
        ...buildDates([1, 2, 3, 4, 5, 6]),
      ],
    );

    final shiftNight = ScheduleBlock(
      id: 'b_night',
      title: 'Guardia Noche',
      startHour: 22,
      startMinute: 0,
      endHour: 6,
      endMinute: 0,
      colorValue: 0xFF9EA1D4,
      habitId: 'h_work',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      hasMonthlyHourTarget: true,
      monthlyTargetHours: 120,
      assignedDates: [
        ...buildDates([7, 14, 15, 21, 22, 25, 26]),
      ],
      completedDates: const [],
    );

    final blockGym = ScheduleBlock(
      id: 'b_gym',
      title: 'Entrenamiento & Fuerza',
      startHour: 17,
      startMinute: 30,
      endHour: 19,
      endMinute: 0,
      colorValue: 0xFFE57A77,
      habitId: 'h_gym',
      daysOfWeek: const [1, 2, 3, 4, 5, 6],
      assignedDates: [
        ...buildDates([2, 4, 6, 9, 11, 13, 16, 18, 20]),
      ],
      completedDates: [todayIso],
    );

    final blockRead = ScheduleBlock(
      id: 'b_read',
      title: 'Lectura Profunda',
      startHour: 20,
      startMinute: 30,
      endHour: 21,
      endMinute: 30,
      colorValue: 0xFFB5A6C9,
      habitId: 'h_read',
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      assignedDates: [todayIso],
      completedDates: [todayIso],
    );

    final allHabits = [habitWork, habitGym, habitRead, habitZen];
    final allBlocks = [shiftMorning, shiftNight, blockGym, blockRead];

    final fakeDb = ScreenshotFakeDb();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(fakeDb)],
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).updateSettings(
          UserSettings(
            userName: 'Arturo',
            avatarEmoji: '🪐',
            avatarColorValue: 0xFF84DCC6,
            notificationHour: 21,
            notificationMinute: 0,
            themeMode: 'dark',
            isFirstTime: false,
            vacationDates: const [],
          ),
        );
    await container.read(habitsProvider.notifier).replaceAllHabits(allHabits);
    await container.read(scheduleProvider.notifier).replaceAllBlocks(allBlocks);

    final boundaryKey = GlobalKey();

    Widget wrapScreen(Widget child) {
      return UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildDarkTheme(),
            home: child,
          ),
        ),
      );
    }

    // 1. Captura 01: Rueda Orbital Mensual
    await tester.pumpWidget(wrapScreen(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 900));
    final subTaskChip = find.textContaining('SUBTAREAS');
    if (subTaskChip.evaluate().isNotEmpty) {
      await tester.tap(subTaskChip.first);
      await tester.pump(const Duration(milliseconds: 350));
    }
    await tester.runAsync(() async {
      await _captureBoundaryToFile(boundaryKey, 'assets/img/01_rueda_orbital.png');
    });

    // 2. Captura 02: Reloj Orbital 24H
    final tab24h = find.text('24H');
    await tester.tap(tab24h.first);
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      await _captureBoundaryToFile(boundaryKey, 'assets/img/02_reloj_24h.png');
    });

    // 3. Captura 03: Pantalla Calendario (Multi-Tarea)
    await tester.pumpWidget(wrapScreen(const ShiftCalendarScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await _captureBoundaryToFile(
          boundaryKey, 'assets/img/03_planificador_turnos.png');
    });

    // 4. Captura 04: Creador/Editor Unificado con Subtareas e Indicador Vinculado
    await tester.pumpWidget(
      wrapScreen(
        Scaffold(
          backgroundColor: AppTheme.obsidianCanvas,
          body: Center(
            child: UnifiedTaskSheet(
              habitToEdit: habitGym,
              blockToEdit: blockGym,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await _captureBoundaryToFile(boundaryKey, 'assets/img/04_crear_tarea.png');
    });

    // 5. Captura 05: Selector Cromático HSV/HEX
    await tester.pumpWidget(
      wrapScreen(
        const Scaffold(
          backgroundColor: AppTheme.obsidianCanvas,
          body: Center(
            child: CustomColorPickerDialog(
              initialColor: Color(0xFF84DCC6),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await _captureBoundaryToFile(
          boundaryKey, 'assets/img/05_selector_color.png');
    });

    // 6. Captura 06: Estadísticas & Telemetría
    await tester.pumpWidget(wrapScreen(const StatisticsScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await _captureBoundaryToFile(
          boundaryKey, 'assets/img/06_estadisticas_rachas.png');
    });

    // 7. Captura 07: Ajustes Zen & Perfil
    await tester.pumpWidget(wrapScreen(const SettingsScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      await _captureBoundaryToFile(boundaryKey, 'assets/img/07_ajustes_zen.png');
    });

    // 8. Captura 08: Póster Mensual Exportable 1080p
    await tester.runAsync(() async {
      final posterBytes = await SchedulePosterService.renderMonthlyPosterPng(
        month: now,
        blocks: allBlocks,
        userName: 'Arturo',
        isDark: true,
        showTelemetryFooter: true,
      );
      File('assets/img/08_poster_mensual.png')
          .writeAsBytesSync(posterBytes, flush: true);
    });

    expect(File('assets/img/01_rueda_orbital.png').existsSync(), isTrue);
    expect(File('assets/img/08_poster_mensual.png').existsSync(), isTrue);
  });
}

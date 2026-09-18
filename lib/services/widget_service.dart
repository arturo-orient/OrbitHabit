import 'package:home_widget/home_widget.dart';
import '../domain/models/habit.dart';

class WidgetService {
  static const String androidWidgetName = 'OrbitWidgetProvider';
  // iOS widget name (for future, standard is 'OrbitWidget')
  static const String iosWidgetName = 'OrbitWidget'; 

  /// Updates the home screen widget with the current habits for today
  static Future<void> updateWidget(List<Habit> activeHabits) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Filtramos los que aplican a hoy
      final todayHabits = activeHabits.where((h) => h.activeWeekdays.contains(now.weekday)).toList();
      
      String content;
      int progressPercent = 0;
      
      if (todayHabits.isEmpty) {
        content = '✨ Día libre. ¡A relajarse!';
        progressPercent = 100; // Día libre = 100% de éxito
      } else {
        int completedCount = 0;
        final buffer = StringBuffer();
        
        for (final habit in todayHabits) {
          final isDone = habit.completedDates.contains(todayStr);
          if (isDone) completedCount++;
          
          buffer.writeln('${isDone ? '✅' : '⏳'} ${habit.name}');
        }
        
        progressPercent = ((completedCount / todayHabits.length) * 100).toInt();
        content = buffer.toString().trim();
      }

      // Guardamos la info en SharedPreferences (que lee el lado nativo)
      await HomeWidget.saveWidgetData<String>('widget_title', 'ÓRBITA ZEN');
      await HomeWidget.saveWidgetData<String>('widget_content', content);
      await HomeWidget.saveWidgetData<int>('widget_progress', progressPercent);
      
      // Disparamos la actualización visual
      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        iOSName: iosWidgetName,
      );
    } catch (e) {
      // Print silent error since widgets shouldn't crash the app
      print('Error actualizando widget: $e');
    }
  }
}

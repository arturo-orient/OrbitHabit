import 'dart:math' as math;
import '../../utils/streak_utils.dart';
import 'habit.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final double progress; // Range: 0.0 to 1.0
  final String progressText; // E.g. "3 / 7 días"
  final bool isUnlocked;
  final int colorValue; // Pastel representation color

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.progressText,
    required this.isUnlocked,
    required this.colorValue,
  });

  /// Dynamically computes the status of all 12 trophies based on the active habits
  static List<Achievement> calculate(List<Habit> habits, [List<String> vacationDates = const []]) {
    // 1. Calculate general statistics
    final int habitsCount = habits.length;
    
    int maxStreakAcrossAll = 0;
    int totalCompletions = 0;
    final Map<String, int> dailyCompletionsCount = {};

    bool hasJan1 = false;
    bool hasFeb29 = false;
    bool hasOct31 = false;
    bool hasDec25 = false;
    bool hasFeb14 = false;
    bool hasMay04 = false;
    bool hasFriday13 = false;
    bool hasSaturday = false;
    bool hasSunday = false;
    bool hasMonday = false;
    bool hasIndividual100 = false;
    bool has66Streak = false;

    final Set<int> uniqueColors = {};

    for (final habit in habits) {
      uniqueColors.add(habit.color.value);
      
      final maxStreak = StreakUtils.calculateMaxStreak(habit, vacationDates);
      if (maxStreak > maxStreakAcrossAll) {
        maxStreakAcrossAll = maxStreak;
      }
      if (maxStreak >= 66) has66Streak = true;
      if (habit.completedDates.length >= 100) hasIndividual100 = true;
      
      totalCompletions += habit.completedDates.length;

      for (final date in habit.completedDates) {
        dailyCompletionsCount[date] = (dailyCompletionsCount[date] ?? 0) + 1;
        if (date.endsWith('-01-01')) hasJan1 = true;
        if (date.endsWith('-02-29')) hasFeb29 = true;
        if (date.endsWith('-10-31')) hasOct31 = true;
        if (date.endsWith('-12-25')) hasDec25 = true;
        if (date.endsWith('-02-14')) hasFeb14 = true;
        if (date.endsWith('-05-04')) hasMay04 = true;
        
        final dt = DateTime.tryParse(date);
        if (dt != null) {
          if (dt.weekday == 1) hasMonday = true;
          if (dt.weekday == 6) hasSaturday = true;
          if (dt.weekday == 7) hasSunday = true;
          if (dt.day == 13 && dt.weekday == 5) hasFriday13 = true;
        }
      }
    }

    final int maxHabitsCompletedInASingleDay = dailyCompletionsCount.isEmpty 
        ? 0 
        : dailyCompletionsCount.values.reduce(math.max);

    final bool hasRainbow = habitsCount >= 5 && uniqueColors.length >= 5;
    final bool hasVacation = vacationDates.isNotEmpty;
    final bool hasWeekendWarrior = hasSaturday && hasSunday;
    final bool hasJackpot = totalCompletions >= 77;

    // 2. Define the achievements list
    return [
      // 1. 🌱 Primeros Pasos
      _buildTrophy(
        id: 'first_steps',
        title: 'Primeros Pasos',
        description: 'Completa al menos un día en cualquiera de tus hábitos.',
        progress: totalCompletions > 0 ? 1.0 : 0.0,
        progressText: '${totalCompletions > 0 ? 1 : 0} / 1',
        isUnlocked: totalCompletions > 0,
        color: 0xFF84A59D, // Verde Salvia
      ),
      // 2. 🛹 Doble Tracción
      _buildTrophy(
        id: 'double_traction',
        title: 'Doble Tracción',
        description: 'Completa 2 hábitos diferentes en un mismo día.',
        progress: (maxHabitsCompletedInASingleDay / 2.0).clamp(0.0, 1.0),
        progressText: '${math.min(maxHabitsCompletedInASingleDay, 2)} / 2',
        isUnlocked: maxHabitsCompletedInASingleDay >= 2,
        color: 0xFF9EA1D4, // Periwinkle
      ),
      // 3. 🔥 Trilogía Constante
      _buildTrophy(
        id: 'streak_3',
        title: 'Trilogía Constante',
        description: 'Consigue una racha máxima de 3 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 3.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 3 días',
        isUnlocked: maxStreakAcrossAll >= 3,
        color: 0xFFE5989B, // Rosa Empolvado
      ),
      // 4. 🖐️ Cinco de Oro
      _buildTrophy(
        id: 'streak_5',
        title: 'Cinco de Oro',
        description: 'Alcanza una racha máxima de 5 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 5.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 5 días',
        isUnlocked: maxStreakAcrossAll >= 5,
        color: 0xFFE5D08F, // Mostaza / Arena
      ),
      // 5. ⚡ Semana Perfecta
      _buildTrophy(
        id: 'streak_7',
        title: 'Semana Perfecta',
        description: 'Alcanza una racha máxima de 7 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 7.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 7 días',
        isUnlocked: maxStreakAcrossAll >= 7,
        color: 0xFF84A59D, // Verde Salvia
      ),
      // 6. 🏹 Quincena Templada
      _buildTrophy(
        id: 'streak_15',
        title: 'Quincena Templada',
        description: 'Logra una racha máxima de 15 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 15.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 15 días',
        isUnlocked: maxStreakAcrossAll >= 15,
        color: 0xFFB5A6C9, // Azul Lavanda
      ),
      // 7. 🪐 Racha Celestial
      _buildTrophy(
        id: 'streak_30',
        title: 'Racha Celestial',
        description: 'Consigue una racha máxima de 30 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 30.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 30 días',
        isUnlocked: maxStreakAcrossAll >= 30,
        color: 0xFFA8C2D3, // Gris Invierno
      ),
      // 8. ☀️ Órbita Solar
      _buildTrophy(
        id: 'streak_90',
        title: 'Órbita Solar',
        description: 'Consigue una racha legendaria de 90 días en cualquier hábito.',
        progress: (maxStreakAcrossAll / 90.0).clamp(0.0, 1.0),
        progressText: '$maxStreakAcrossAll / 90 días',
        isUnlocked: maxStreakAcrossAll >= 90,
        color: 0xFFF2C6B4, // Melocotón Suave
      ),
      // 9. 👑 Constelación Completa
      _buildTrophy(
        id: 'habits_5',
        title: 'Constelación Completa',
        description: 'Mantén creados 5 o más hábitos simultáneamente.',
        progress: (habitsCount / 5.0).clamp(0.0, 1.0),
        progressText: '$habitsCount / 5 hábitos',
        isUnlocked: habitsCount >= 5,
        color: 0xFFB5A6C9, // Azul Lavanda
      ),
      // 10. 🚀 Universo en Expansión
      _buildTrophy(
        id: 'habits_8',
        title: 'Universo en Expansión',
        description: 'Ten creados 8 hábitos a la vez (máximo permitido).',
        progress: (habitsCount / 8.0).clamp(0.0, 1.0),
        progressText: '$habitsCount / 8 hábitos',
        isUnlocked: habitsCount >= 8,
        color: 0xFF9EA1D4, // Periwinkle
      ),
      // 11. 🌟 Órbitas Múltiples
      _buildTrophy(
        id: 'orbits_multiple_3',
        title: 'Órbitas Múltiples',
        description: 'Completa 3 hábitos diferentes en un mismo día.',
        progress: (maxHabitsCompletedInASingleDay / 3.0).clamp(0.0, 1.0),
        progressText: '${math.min(maxHabitsCompletedInASingleDay, 3)} / 3',
        isUnlocked: maxHabitsCompletedInASingleDay >= 3,
        color: 0xFFF2C6B4, // Melocotón Suave
      ),
      // 12. 💎 Leyenda de la Constancia
      _buildTrophy(
        id: 'total_200',
        title: 'Leyenda de la Constancia',
        description: 'Consigue 200 completados totales sumando todos tus hábitos.',
        progress: (totalCompletions / 200.0).clamp(0.0, 1.0),
        progressText: '$totalCompletions / 200 completados',
        isUnlocked: totalCompletions >= 200,
        color: 0xFFE5D08F, // Mostaza / Arena
      ),
      
      // --- EASTER EGGS ORIGINALES ---
      
      // 13. Arcoíris Zen
      _buildTrophy(
        id: 'ee_rainbow',
        title: hasRainbow ? '🌈 Arcoíris Zen' : '???',
        description: hasRainbow ? 'Organiza tu vida a todo color (5 hábitos con colores distintos).' : 'Logro secreto. Experimenta un poco con la paleta de colores.',
        progress: hasRainbow ? 1.0 : 0.0,
        progressText: hasRainbow ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasRainbow,
        color: 0xFFE5989B,
      ),
      // 14. Billete al Caribe
      _buildTrophy(
        id: 'ee_vacation',
        title: hasVacation ? '🌴 Billete al Caribe' : '???',
        description: hasVacation ? 'Activaste el Modo Descanso por primera vez. ¡A relajarse!' : 'Logro secreto. A veces no hacer nada también es un logro.',
        progress: hasVacation ? 1.0 : 0.0,
        progressText: hasVacation ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasVacation,
        color: 0xFF4FC3F7, // Azul piscina
      ),
      // 15. Propósito de Año Nuevo
      _buildTrophy(
        id: 'ee_newyear',
        title: hasJan1 ? '🎆 Magia de Enero' : '???',
        description: hasJan1 ? 'Completaste un hábito el 1 de Enero. ¡Empezando fuerte el año!' : 'Logro secreto. El primer día del calendario tiene magia.',
        progress: hasJan1 ? 1.0 : 0.0,
        progressText: hasJan1 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasJan1,
        color: 0xFFFFD700,
      ),
      // 16. Salto Cuántico
      _buildTrophy(
        id: 'ee_leapyear',
        title: hasFeb29 ? '🐸 Salto Cuántico' : '???',
        description: hasFeb29 ? 'Completaste un hábito un 29 de Febrero. ¡Pasa una vez cada 4 años!' : 'Logro secreto. Solo ocurre una vez cada 1460 días.',
        progress: hasFeb29 ? 1.0 : 0.0,
        progressText: hasFeb29 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasFeb29,
        color: 0xFF84A59D,
      ),

      // --- LOS 10 NUEVOS EASTER EGGS ---

      // 17. Halloween
      _buildTrophy(
        id: 'ee_halloween',
        title: hasOct31 ? '🎃 Truco o Trato' : '???',
        description: hasOct31 ? 'Cumpliste tu hábito en la noche de brujas (31 Oct).' : 'Logro secreto. Los fantasmas te observan este otoño.',
        progress: hasOct31 ? 1.0 : 0.0,
        progressText: hasOct31 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasOct31,
        color: 0xFFFF8A65, // Naranja
      ),
      // 18. Navidad
      _buildTrophy(
        id: 'ee_xmas',
        title: hasDec25 ? '🎄 Espíritu Navideño' : '???',
        description: hasDec25 ? 'Completaste un hábito el 25 de Diciembre. ¡Feliz Navidad!' : 'Logro secreto. Huele a turrón y a fuerza de voluntad.',
        progress: hasDec25 ? 1.0 : 0.0,
        progressText: hasDec25 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasDec25,
        color: 0xFF81C784, // Verde festivo
      ),
      // 19. San Valentín
      _buildTrophy(
        id: 'ee_valentine',
        title: hasFeb14 ? '💖 Amor Propio' : '???',
        description: hasFeb14 ? 'Cuidar de ti es el mejor regalo (14 Feb).' : 'Logro secreto. El mes de Cupido empieza por cuidarse uno mismo.',
        progress: hasFeb14 ? 1.0 : 0.0,
        progressText: hasFeb14 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasFeb14,
        color: 0xFFF06292, // Rosa intenso
      ),
      // 20. Star Wars
      _buildTrophy(
        id: 'ee_starwars',
        title: hasMay04 ? '⚔️ La Fuerza' : '???',
        description: hasMay04 ? 'Que la constancia te acompañe (4 de Mayo).' : 'Logro secreto. Una fecha muy galáctica.',
        progress: hasMay04 ? 1.0 : 0.0,
        progressText: hasMay04 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasMay04,
        color: 0xFF64B5F6, // Azul sable
      ),
      // 21. Viernes 13
      _buildTrophy(
        id: 'ee_friday13',
        title: hasFriday13 ? '🐈‍⬛ Superstición' : '???',
        description: hasFriday13 ? 'Completaste un hábito un Viernes 13. ¡Adiós maldición!' : 'Logro secreto. Cuidado con pasar por debajo de una escalera.',
        progress: hasFriday13 ? 1.0 : 0.0,
        progressText: hasFriday13 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasFriday13,
        color: 0xFF607D8B, // Azul grisáceo
      ),
      // 22. Ciencia del Hábito
      _buildTrophy(
        id: 'ee_science66',
        title: has66Streak ? '🧠 Cableado Neuronal' : '???',
        description: has66Streak ? '66 días seguidos. Científicamente, ya es un hábito.' : 'Logro secreto. La ciencia dice que necesitas un número exacto de días.',
        progress: has66Streak ? 1.0 : 0.0,
        progressText: has66Streak ? '¡Descubierto!' : 'Oculto',
        isUnlocked: has66Streak,
        color: 0xFFBA68C8, // Morado
      ),
      // 23. Jackpot
      _buildTrophy(
        id: 'ee_jackpot77',
        title: hasJackpot ? '🎰 Jackpot' : '???',
        description: hasJackpot ? 'Alcanzaste 77 completados totales. ¡Pleno al siete!' : 'Logro secreto. El número de la suerte por excelencia, pero doble.',
        progress: hasJackpot ? 1.0 : 0.0,
        progressText: hasJackpot ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasJackpot,
        color: 0xFFFFD54F, // Oro brillante
      ),
      // 24. Lunes al Sol
      _buildTrophy(
        id: 'ee_monday',
        title: hasMonday ? '☕ Lunes al Sol' : '???',
        description: hasMonday ? 'Venciste a la pereza del primer día de la semana.' : 'Logro secreto. El día que más café requiere para arrancar.',
        progress: hasMonday ? 1.0 : 0.0,
        progressText: hasMonday ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasMonday,
        color: 0xFFA1887F, // Marrón café
      ),
      // 25. Guerrero Fin de Semana
      _buildTrophy(
        id: 'ee_weekend',
        title: hasWeekendWarrior ? '🏕️ Guerrero Finde' : '???',
        description: hasWeekendWarrior ? 'Completaste hábitos tanto en Sábado como en Domingo.' : 'Logro secreto. Cuando todos descansan, tú sigues avanzando.',
        progress: hasWeekendWarrior ? 1.0 : 0.0,
        progressText: hasWeekendWarrior ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasWeekendWarrior,
        color: 0xFF4DB6AC, // Verde agua
      ),
      // 26. Centurión
      _buildTrophy(
        id: 'ee_centurion',
        title: hasIndividual100 ? '💯 Centurión' : '???',
        description: hasIndividual100 ? 'Un hábito llegó a los 100 completados. Una máquina.' : 'Logro secreto. La legión romana antigua te respetaría.',
        progress: hasIndividual100 ? 1.0 : 0.0,
        progressText: hasIndividual100 ? '¡Descubierto!' : 'Oculto',
        isUnlocked: hasIndividual100,
        color: 0xFFE0E0E0, // Plata
      ),
    ];
  }

  static Achievement _buildTrophy({
    required String id,
    required String title,
    required String description,
    required double progress,
    required String progressText,
    required bool isUnlocked,
    required int color,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      progress: progress,
      progressText: progressText,
      isUnlocked: isUnlocked,
      colorValue: color,
    );
  }
}

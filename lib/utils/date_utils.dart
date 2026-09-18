class OrbitDateUtils {
  /// Devuelve el número exacto de días para un mes y año específicos,
  /// teniendo en cuenta años bisiestos.
  static int getDaysInMonth(int year, int month) {
    // Al pedir el día 0 del mes siguiente, DateTime nos devuelve el último día del mes actual.
    return DateTime(year, month + 1, 0).day;
  }

  /// Devuelve la fecha actual sin horas, minutos ni segundos (a las 00:00:00).
  /// Útil para comparar fechas estáticas de hábitos completados.
  static DateTime getTodayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Verifica si dos fechas son exactamente el mismo día.
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Verifica si una fecha es futura respecto al día de hoy (truncando la hora)
  static bool isFutureDate(DateTime date) {
    final today = getTodayDateOnly();
    final compareDate = DateTime(date.year, date.month, date.day);
    return compareDate.isAfter(today);
  }
}

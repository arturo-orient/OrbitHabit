# ORBITHABIT — DOSSIER INTEGRAL DE PRODUCTO, ARQUITECTURA Y AUDITORÍA
> **Versión del Documento:** 1.0 (Producción v1.1.3)  
> **Objetivo:** Documento técnico y funcional de referencia para auditorías multidimensionales con Inteligencia Artificial, análisis de UX/UI, viabilidad para Google Play Store y revisión de portafolio profesional.

---

## 1. RESUMEN EJECUTIVO Y PROPUESTA DE VALOR

### 1.1. ¿Qué es OrbitHabit?
**OrbitHabit** es una aplicación móvil nativa de alto rendimiento desarrollada en **Flutter (Dart)** diseñada para la gestión integral de **hábitos personales, rutinas diarias y planificación de turnos laborales complejos (rotativos, nocturnos y partidos)**.

A diferencia de las aplicaciones convencionales de hábitos (que asumen una vida monótona de 9:00 a 17:00 de lunes a viernes), OrbitHabit nace para resolver la fricción real a la que se enfrentan profesionales con horarios atípicos (personal sanitario, operarios industriales, hostelería, servicios de emergencia, freelancers y estudiantes de alto rendimiento).

### 1.2. Principios Fundamentales de Producto
1. **100% Offline-First y Cero Fricción:** No requiere inicio de sesión, ni registro por correo, ni sincronización forzada en servidores de terceros. Todo el almacenamiento es local, ultraveloz y respeta estrictamente la privacidad del usuario.
2. **Dirección Artística Suiza e Industrial ("Anti-AI Slop"):** Huye deliberadamente de las plantillas genéricas de color morado/índigo con gradientes repetitivos. Su interfaz está inspirada en la precisión técnica de Linear, Teenage Engineering y la relojería analógica de lujo, con fondos obsidiana/carbón (`#0F0F11`), tipografía técnica monoespaciada para telemetría numérica y bordes quirúrgicos de 1px.
3. **Dualidad Temporal (Mes / Día):** Permite al usuario alternar con un solo toque entre una visión macro-orbital mensual (**Modo Órbita**) y un cronograma circadiano horario (**Modo 24H**).
4. **Agrupación Inteligente de Trabajo:** Permite unificar múltiples turnos diferentes (Mañana, Tarde, Noche, Refuerzo) bajo una sola meta mensual de horas trabajadas y un único anillo orbital, evitando el caos visual y el conteo duplicado de horas.

---

## 2. ARQUITECTURA DE INTERFAZ Y EXPERIENCIA DE USUARIO (UX/UI)

### 2.1. Vista 1: Rueda Orbital Mensual (`OrbitTracker`)
* **Metáfora visual:** Un dial concéntrico radial de 31 días (como las órbitas de un sistema planetario o un reloj astronómico).
* **Anillos concéntricos:** Cada hábito o grupo de trabajo activo ocupa un anillo independiente en la rueda.
* **Geometría de los Arcos:** 
  * Los días del mes se disponen en un arco semicircular graduado de 1 a 31.
  * **Día completado:** El segmento se ilumina completamente con el color temático de la tarea.
  * **Día planificado a futuro:** En turnos de trabajo calendarizados para fechas futuras, el segmento se dibuja como una *silueta fantasma* sutil (8% de opacidad) para guiar al usuario sin marcar falsamente el hábito como realizado.
  * **Día seleccionado:** Un selector activo con contraste invertido resalta el día actual o el día tocado por el usuario.
* **Telemetría Central:** En el núcleo de la órbita se computa en tiempo real la tasa de cumplimiento del día seleccionado (ej. `0/2 HOY · 0%` o `COMPLETO`).

### 2.2. Vista 2: Reloj Circadiano Polar de 24 Horas (`OrbitClock24`)
* **Metáfora visual:** Una esfera polar de 360 grados que representa un ciclo circadiano completo de medianoche a medianoche (00:00 a 24:00).
* **Bloques horarios como cuñas polares:** Las actividades programadas (dormir, trabajar, gimnasio, estudio) se proyectan como sectores circulares nítidos con bordes demarcados.
* **Gestión de Turnos Nocturnos que cruzan la medianoche:** Maneja nativamente bloques horarios nocturnos (ej. 23:00 a 07:00), dividiendo matemáticamente el arco entre el final del día y el inicio de la mañana siguiente sin romperse.
* **Aguja de Tiempo Real:** Un indicador luminoso muestra la hora exacta actual y parpadea con elegancia si una tarea está en curso en este preciso minuto.

### 2.3. Vista 3: Módulo de Registro y Hábitos (`HabitProgressCard` y `StaggeredAccordionItem`)
* Lista inferior bajo los diales donde cada hábito o turno se presenta en tarjetas de datos de alta densidad editorial:
  * **Indicador visual de color:** Identificador cromático del hábito.
  * **Nombre y métrica actual:** Muestra el progreso mensual o semanal (ej. `17 turnos · 8h/turno`, `136 / 120H`).
  * **Badges de estado:** Píldoras con tipografía técnica para alertar de horas extras (`+16H EXTRA`), rachas activas (`🔥 7 DÍAS`) o tipo de meta.
  * **Barra de progreso de microprecisión:** Con fondo tenue y relleno sólido en el color asignado.
  * **Botón de acción rápida:** Permite registrar el día de hoy con un solo toque (`REGISTRAR HOY`).

### 2.4. Vista 4: Planificador de Cuadrantes y Turnos (`ShiftCalendarScreen`)
* Cuadrícula mensual estilo calendario de turnos profesionales.
* **Paleta de turnos rápida:** El usuario selecciona el turno que desea pintar (ej. Mañana, Noche, Tarde, Libre) y con solo tocar los días del mes en el calendario los asigna al instante.
* **Cálculo de Horas:** Calcula en tiempo real las horas proyectadas del cuadrante y las horas reales acumuladas según transcurren los días.
* **Gestión de Horas Extra:** Permite añadir horas adicionales directamente sobre turnos finalizados.

### 2.5. Vista 5: Sistema Unificado de Creación/Edición (`UnifiedTaskSheet`)
* Hoja modal unificada que elimina la separación confusa entre "crear hábito" y "crear bloque de horario":
  * Permite definir si una actividad es solo un hábito, un bloque en el reloj 24h, o ambos simultáneamente.
  * Configuración de meta mensual de horas (ideal para control laboral).
  * Frecuencias flexibles (diario, días fijos de la semana como L-M-V, o X días flexibles por semana).
  * Selector de color personalizado (`CustomColorPickerDialog`) con soporte de paletas predefinidas y selector libre HEX con validación de código.

### 2.6. Vista 6: Sala de Trofeos y Logros Dinámicos (`AchievementsSheet`)
* Sistema de gamificación con más de 20 logros calculados procedimentalmente:
  * *Hitos de constancia:* Formación de hábitos (66 días), Club de los 100 registros.
  * *Hitos de calendario:* Completar tareas en Año Nuevo (01-01), San Valentín (14-02), Star Wars Day (04-05), Halloween (31-10), Navidad (25-12) o Viernes 13.
  * *Ilustraciones Vectoriales a Medida:* Cada medalla está dibujada mediante `CustomPainter` matemático (`AchievementArtPainter`), sin imágenes PNG pesadas.
  * *Feedback Sensorial:* Efectos de sonido integrados (`SoundService`) y lluvia de partículas (`ConfettiOverlay`).

---

## 3. ESPECIFICACIÓN TÉCNICA Y MODELO DE DATOS

### 3.1. Stack Tecnológico
* **Framework:** Flutter 3.x / Dart 3.x.
* **Gestión de Estado:** `ChangeNotifier` + `Provider` (`HabitProvider`, `ScheduleProvider`, `SettingsProvider`). Arquitectura reactiva y desacoplada.
* **Base de Datos Local:** **Hive** (Key-Value NoSQL embebido en C/Dart). Lecturas y escrituras sincrónicas en memoria con persistencia en disco ultrarrápida.
* **Notificaciones:** `flutter_local_notifications` y `timezone` para alertas locales programadas.
* **Efectos y Audio:** `audioplayers` para feedback de completado + `HapticFeedback` nativo de Android/iOS.
* **Widgets de Escritorio:** Soporte para widget nativo de pantalla de inicio mediante `home_widget`.

### 3.2. Modelos de Dominio Principales

#### `Habit`
```dart
class Habit {
  final String id;
  final String name;
  final int colorValue; // Formato entero ARGB (0xAARRGGBB)
  final int targetDays; // Meta de días al mes
  final Set<String> completedDates; // Fechas en formato ISO "YYYY-MM-DD"
  final int orderIndex; // Ordenamiento manual en la UI
  
  // Metas numéricas
  final bool isNumeric; // Si requiere un valor (ej. 2000 ml) o es booleano
  final int dailyTarget;
  final String dailyUnit; // ej. "ml", "páginas", "km"
  final Map<String, int> dailyProgress; // Progreso diario por fecha
  
  // Reglas de frecuencia
  final List<int> activeWeekdays; // 1 = Lunes, 7 = Domingo
  final bool hasMonthlyTarget;
  final int frequencyType; // 0 = Días Específicos, 1 = Frecuencia Flexible
  final int targetDaysPerWeek; // ej. 3 días a la semana
}
```

#### `ScheduleBlock`
```dart
class ScheduleBlock {
  final String id;
  final String title;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int colorValue;
  final String? habitId; // Enlace bidireccional opcional con un Habit
  final List<int> daysOfWeek; // Días que aplica de forma recurrente
  final bool hasMonthlyHourTarget; // ¿Computa para bolsa de horas mensual?
  final int monthlyTargetHours; // ej. 120, 140, 160 horas
  final List<String> completedDates; // Días en los que se confirmó el turno
  final List<String> assignedDates; // Días específicos asignados en el calendario
  final double extraHours; // Horas extraordinarias acumuladas
}
```

#### `WorkShiftGroup` (Patrón de Consolidación)
Agrupa lógicamente múltiples `ScheduleBlock` bajo un mismo concepto laboral para la UI:
* Evita que si un usuario tiene turnos de Mañana, Noche y Tarde, se creen 3 anillos concéntricos gigantescos en la rueda orbital.
* Unifica los turnos en un solo anillo interactivo con un acordeón desplegable de desglose (`[ ▾ DESGLOSE DE TURNOS ]`).

---

## 4. CASOS LÍMITE (EDGE CASES) RESUELTOS

1. **El Problema de las Letras Gigantes de Accesibilidad:**
   * *Síntoma:* Si un usuario activaba en los ajustes de Android una escala de fuente grande (130%-150%), los textos rompían los contenedores y los diales radiales sufrían desbordamientos (`RenderFlex overflow`).
   * *Solución implementada:* Inyección de `TextScaler.noScaling` en el builder raíz de `MaterialApp`, garantizando fidelidad milimétrica 1:1 en gráficos técnicos mientras se mantiene legible la tipografía base.
2. **El Problema de los Turnos Futuros y Horas Fantasma:**
   * *Síntoma:* Al planificar el mes que viene en el cuadrante, los días asignados se contaban como si ya se hubieran trabajado, inflando las estadísticas a 120h trabajadas a día 1 del mes.
   * *Solución implementada:* Separación estricta entre `assignedDates` y `completedDates`. Un turno futuro se renderiza únicamente como silueta tenue (8% de opacidad) y sus horas solo se computan como *Planificadas*, nunca como *Reales Trabajadas* hasta que la fecha transcurre o el usuario lo confirma explícitamente.
3. **Persistencia de Color Personalizado:**
   * *Síntoma:* Al escribir un color hexadecimal a mano, en ocasiones no se aplicaba si el canal Alpha no estaba explícitamente forzado a `0xFF000000`.
   * *Solución implementada:* Parser robusto de HEX de 3 y 6 dígitos que inyecta opacidad total y actualiza en cascada tanto el bloque de horario como el hábito asociado en el provider de estado.

---

## 5. RÚBRICA Y GUÍA DE AUDITORÍA PARA INTELIGENCIAS ARTIFICIALES

*Si estás evaluando este documento como una IA externa, somete a OrbitHabit a las siguientes 4 perspectivas analíticas:*

### Perspectiva A: Auditor de Experiencia de Usuario & Onboarding (UX First-Look)
* Evalúa la curva de aprendizaje inicial: ¿Entiende un usuario recién llegado en menos de 10 segundos la diferencia entre la **Rueda Orbital** y el **Reloj 24H**?
* Evalúa los estados vacíos (*Empty States*): Si la app está recién instalada y no tiene datos, ¿qué debería mostrar para incitar a la acción sin frustrar al usuario?

### Perspectiva B: Auditor del Trabajador de Turnos Complejos (Power Worker UX)
* Evalúa la fricción diaria: ¿Cuántos clics requiere registrar un turno nocturno de guardia o añadir 2 horas extras a un día ya transcurrido?
* ¿Cómo se comporta el sistema si un turno de noche empieza a las 22:00 del viernes y termina a las 06:00 del sábado?

### Perspectiva C: Auditor de Hábitos Atómicos y Retención (Habit Tracker Enthusiast)
* Evalúa la psicología de recompensas: ¿Son suficientes los trofeos y el sonido de completado para generar el bucle de hábito (Señal -> Rutina -> Recompensa)?
* ¿Cómo gestiona la culpa del usuario si se pierde un día? ¿Es suficiente el Modo Vacaciones para no romper rachas legítimas?

### Perspectiva D: Auditor Técnico de Publicación en Google Play Store (Release Engineer)
* **Políticas de Datos y Privacidad:** ¿La app necesita declaración de permisos especiales? (Cero permisos invasivos, todo local).
* **Seguridad de Datos del Usuario:** Si el usuario formatea su teléfono o cambia de móvil, ¿hay mecanismo de exportación/importación (Backup JSON)?
* **Requisitos Modernos de Android:** Compatibilidad con Android 14/15, diseño Edge-to-Edge nativo, iconos adaptativos y rendimiento fluido a 60/120 Hz.

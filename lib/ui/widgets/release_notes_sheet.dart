import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_version.dart';
import '../../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Modelo inmutable de un hito destacado en las notas de versión.
class ReleaseHighlightItem {
  final IconData icon;
  final Color accentColor;
  final String badge;
  final String title;
  final String description;

  const ReleaseHighlightItem({
    required this.icon,
    required this.accentColor,
    required this.badge,
    required this.title,
    required this.description,
  });
}

/// Modal Editorial Suizo de "Novedades de la Versión" (What's New / Changelog).
/// Compatible al 100% con Modo Día (#F6F5F2) y Modo Oscuro (#141414),
/// bordes quirúrgicos de 1px y tipografía con contraste editorial.
class ReleaseNotesSheet extends ConsumerStatefulWidget {
  const ReleaseNotesSheet({super.key});

  /// Muestra el cartel de novedades como Modal Bottom Sheet adaptable.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const FractionallySizedBox(
            heightFactor: 0.88,
            child: ReleaseNotesSheet(),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<ReleaseNotesSheet> createState() => _ReleaseNotesSheetState();
}

class _ReleaseNotesSheetState extends ConsumerState<ReleaseNotesSheet> {
  bool _showPreviousVersions = false;

  static const List<ReleaseHighlightItem> _highlights = [
    ReleaseHighlightItem(
      icon: Icons.notifications_active_rounded,
      accentColor: Color(0xFF84A59D),
      badge: 'RECORDATORIOS',
      title: 'Avisos Inteligentes y Post-Actividad (+10 min)',
      description:
          'Recibe recordatorios a hora fija para tus hábitos y avisos automáticos 10 min después de terminar un horario si olvidaste marcarlo, con gestor y borrado individual en Ajustes.',
    ),
    ReleaseHighlightItem(
      icon: Icons.timelapse_rounded,
      accentColor: Color(0xFFFBBF24),
      badge: 'MODO 24H & MÉTRICAS',
      title: 'Reloj 24H Direccional y Telemetría Vectorial',
      description:
          'Arcos continuos sin cortes en medianoche con marcadores claros de inicio (●) ➔ fin (▸|), contraste visual entre pendiente y completado y 3 gráficas interactivas en Estadísticas.',
    ),
    ReleaseHighlightItem(
      icon: Icons.explore_rounded,
      accentColor: Color(0xFF84DCC6),
      badge: 'INTERACTIVO',
      title: 'Nuevo Tutorial Guiado Paso a Paso',
      description:
          'Aprende a usar la Rueda Orbital, el Reloj 24H y el Calendario tocando directamente los elementos iluminados en pantalla.',
    ),
    ReleaseHighlightItem(
      icon: Icons.checklist_rtl_rounded,
      accentColor: Color(0xFFF4978E),
      badge: 'RUTINAS',
      title: 'Subtareas Micro-Segmentadas y Duplicación',
      description:
          'Divide cualquier hábito en pasos pequeños con barra de progreso por tramos, reordena con un toque y duplica tareas complejas al instante.',
    ),
    ReleaseHighlightItem(
      icon: Icons.calendar_month_rounded,
      accentColor: Color(0xFFFFD166),
      badge: 'CALENDARIO',
      title: 'Calendario Multi-Tarea, Ciclos y Póster PNG',
      description:
          'Asigna varios turnos el mismo día, desliza el dedo para pintar semanas enteras, aplica ciclos rotativos y descarga tu póster mensual a medida.',
    ),
    ReleaseHighlightItem(
      icon: Icons.shield_moon_rounded,
      accentColor: Color(0xFFB5A6C9),
      badge: 'RESILIENCIA',
      title: 'Escudo de Guardia Pesada (+12h) y Nuevo Icono',
      description:
          'Los días con jornadas maratonianas (+12h) protegen automáticamente tus rachas personales. Además, estrenamos icono Warm Lo-Fi y diseño más limpio.',
    ),
  ];

  static const List<({String version, String date, String summary})> _previousReleases = [
    (
      version: 'v1.2.6',
      date: 'NOV 2026',
      summary:
          'Tutorial guiado interactivo, subtareas con barra por tramos, calendario multi-turno con póster PNG y corrección de horas duplicadas en meses anteriores.',
    ),
    (
      version: 'v1.2.5',
      date: 'OCT 2026',
      summary:
          'Partición exacta de turnos nocturnos en el Reloj 24H (tramo de noche hoy + madrugada mañana) y cálculo estricto de horas trabajadas reales.',
    ),
    (
      version: 'v1.2.0',
      date: 'OCT 2026',
      summary:
          'Exportador de Póster Mensual PNG a 1080p, selector de colores ampliado con 28 tonos curados y mejoras de rendimiento en la Rueda Orbital.',
    ),
    (
      version: 'v1.1.3',
      date: 'SEP 2026',
      summary:
          'Integración del Reloj Polar de 24 Horas en tiempo real, Bolsa de Horas mensual para trabajo por turnos y copias de seguridad JSON.',
    ),
  ];

  Future<void> _acknowledgeAndClose() async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(settingsProvider.notifier).markReleaseNotesSeen();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F5F2);
    final cardBg = isDark ? const Color(0xFF1A1A1D) : const Color(0xFFFFFFFF);
    final borderCol = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8D5CE);
    final textPrimary = isDark ? const Color(0xFFF4F3EF) : const Color(0xFF0A0A0A);
    final textSecondary = isDark ? const Color(0xFF9E9C96) : const Color(0xFF52514E);
    const badgeAccent = Color(0xFF84A59D);
    final primaryActionBg = AppTheme.dynamicAccent(isDark);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(
          color: borderCol,
          width: 1.0,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Tirador superior minimalista
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderCol,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 1. CABECERA DEL CARTEL
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '[ NOVEDADES // v$kCurrentAppVersion ]',
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeAccent.withValues(alpha: isDark ? 0.18 : 0.16),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: badgeAccent.withValues(alpha: 0.65),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                'NUEVA VERSIÓN · $kCurrentReleaseDate',
                                style: AppTheme.monoStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFFA7C7BF) : const Color(0xFF4B6E66),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _acknowledgeAndClose,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderCol, width: 1.0),
                          ),
                          child: Text(
                            '[ ✕ ]',
                            style: AppTheme.monoStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Qué hay de nuevo en OrbitHabit',
                    style: AppTheme.displayStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hemos pulido cada detalle para que organizar tus hábitos y turnos sea más rápido, visual y cómodo.',
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: borderCol),

            // 2. LISTA DE NOVEDADES DESTACADAS + ACORDEÓN DE VERSIONES ANTERIORES
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < _highlights.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildHighlightCard(
                        item: _highlights[i],
                        isDark: isDark,
                        cardBg: cardBg,
                        borderCol: borderCol,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 3. ACORDEÓN OPCIONAL DE VERSIONES ANTERIORES
                    _buildPreviousVersionsAccordion(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderCol: borderCol,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, thickness: 1, color: borderCol),

            // 4. PIE FIJO DEL CARTEL
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _acknowledgeAndClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryActionBg,
                    foregroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '[ ¡ENTENDIDO, A PROBARLO! ]',
                    style: AppTheme.monoStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightCard({
    required ReleaseHighlightItem item,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderCol,
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: isDark ? 0.16 : 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.accentColor.withValues(alpha: isDark ? 0.55 : 0.65),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: 19,
              color: isDark
                  ? item.accentColor
                  : HSLColor.fromColor(item.accentColor)
                      .withLightness(
                        (HSLColor.fromColor(item.accentColor).lightness * 0.62).clamp(0.22, 0.45),
                      )
                      .toColor(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.accentColor.withValues(alpha: isDark ? 0.14 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: item.accentColor.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        item.badge,
                        style: AppTheme.monoStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? item.accentColor
                              : HSLColor.fromColor(item.accentColor)
                                  .withLightness(
                                    (HSLColor.fromColor(item.accentColor).lightness * 0.55)
                                        .clamp(0.20, 0.42),
                                  )
                                  .toColor(),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: AppTheme.displayStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: AppTheme.bodyStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousVersionsAccordion({
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _showPreviousVersions = !_showPreviousVersions;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showPreviousVersions ? 'Versiones anteriores ▴' : 'Versiones anteriores ▾',
                    style: AppTheme.monoStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    'v1.2.7 · v1.2.5 · v1.2.0 · v1.1.3',
                    style: AppTheme.monoStyle(
                      fontSize: 10,
                      color: textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, thickness: 1, color: borderCol),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _previousReleases.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              _previousReleases[i].version,
                              style: AppTheme.monoStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· ${_previousReleases[i].date}',
                              style: AppTheme.monoStyle(
                                fontSize: 10,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _previousReleases[i].summary,
                          style: AppTheme.bodyStyle(
                            fontSize: 12,
                            height: 1.38,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState:
                _showPreviousVersions ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/backup_service.dart';
import '../theme/app_theme.dart';

/// Modal con la Guía Rápida y Manual Técnico de OrbitHabit.
/// Explica la arquitectura visual (Rueda Orbital, Reloj 24H, Cuadrante y Modo Demo)
/// siguiendo el Manifiesto de Diseño Suizo (Neo-Bento, Obsidian/Bone, Phosphor Accent).
class OrbitGuideSheet extends ConsumerWidget {
  final VoidCallback? onStartTour;

  const OrbitGuideSheet({Key? key, this.onStartTour}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.dynamicAccent(isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.obsidianSurface : AppTheme.boneSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
            width: 1.0,
          ),
          left: BorderSide(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            width: 1.0,
          ),
          right: BorderSide(
            color: isDark ? AppTheme.obsidianBorder : AppTheme.boneBorder,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Indicador de arrastre (Pull handle)
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneBorderHover,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Cabecera Técnica
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MANUAL TÉCNICO // V1.3.0',
                      style: AppTheme.monoStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Guía de Navegación Orbital',
                      style: AppTheme.displayStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? AppTheme.obsidianTextMuted : AppTheme.boneTextMuted,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                if (onStartTour != null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onStartTour!();
                    },
                    icon: const Icon(Icons.explore_rounded, size: 18),
                    label: Text(
                      'INICIAR TOUR GUIADO INTERACTIVO',
                      style: AppTheme.monoStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // TARJETA 01: RUEDA ORBITAL
                _buildGuideCard(
                  isDark: isDark,
                  accent: accent,
                  stepNumber: '01',
                  category: 'VISTA MENSUAL',
                  title: 'La Rueda Orbital',
                  icon: Icons.adjust_rounded,
                  content:
                      'Cada anillo concéntrico representa un hábito o actividad laboral. Los días del 1 al 31 giran en forma de herradura armónica:\n\n'
                      '• Color sólido: Día completado y registrado.\n'
                      '• Silueta tenue (8%): Turno u horario programado en el cuadrante.\n'
                      '• Espacio limpio: Día de descanso (espacio negativo Zen sin artefactos rotos).\n\n'
                      'Toca cualquier día en la rueda para inspeccionar o editar el registro histórico.',
                ),
                const SizedBox(height: 12),

                // TARJETA 02: RELOJ 24H
                _buildGuideCard(
                  isDark: isDark,
                  accent: accent,
                  stepNumber: '02',
                  category: 'CICLO CIRCADIANO',
                  title: 'El Reloj 24 Horas en Vivo',
                  icon: Icons.schedule_rounded,
                  content:
                      'Una esfera polar de 24 horas sincronizada en tiempo real que mapea tus bloques del día:\n\n'
                      '• Frotar o pulsar un arco: Toca cualquier franja horaria para abrir la edición rápida de ese bloque.\n'
                      '• Turnos nocturnos: Cruza la medianoche (ej. 23:00 → 07:00) sin saltos visuales ni desfases matemáticos.\n'
                      '• Núcleo táctil: Pulsa el centro para fichar tu turno o completar tu hábito actual con un solo clic.',
                ),
                const SizedBox(height: 12),

                // TARJETA 03: CUADRANTE DE TURNOS
                _buildGuideCard(
                  isDark: isDark,
                  accent: accent,
                  stepNumber: '03',
                  category: 'PLANIFICADOR',
                  title: 'Cuadrante de Turnos',
                  icon: Icons.calendar_month_rounded,
                  content:
                      'En la vista 24H, pulsa el botón "Cuadrante Turnos" para abrir el calendario mensual:\n\n'
                      '• Elige tu turno activo (Mañana, Tarde, Noche, Guardia) y pulsa los días para pintarlos al instante.\n'
                      '• Modo borrar: Limpia asignaciones con un solo toque.\n'
                      '• Telemetría de horas: Calcula en vivo las horas reales trabajadas frente a las planificadas en el mes.',
                ),
                const SizedBox(height: 12),

                // TARJETA 04: MODO DEMO Y BACKUP
                _buildGuideCard(
                  isDark: isDark,
                  accent: accent,
                  stepNumber: '04',
                  category: 'SEGURIDAD & SIMULACIÓN',
                  title: 'Backup JSON y Datos Demo',
                  icon: Icons.shield_outlined,
                  content:
                      'Tus datos te pertenecen al 100%:\n\n'
                      '• Sin permisos invasivos: En Ajustes puedes exportar e importar tu base de datos completa en JSON a través del portapapeles.\n'
                      '• Cero telemetría externa: Todo funciona localmente con persistencia offline de alta velocidad.',
                ),
                const SizedBox(height: 16),

                // BOTÓN DE ACCIÓN RÁPIDA: CARGAR ÓRBITA DEMO
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.bentoCard(
                    isLight: !isDark,
                    borderRadius: AppTheme.radiusMd,
                    borderColor: accent.withValues(alpha: 0.35),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 18, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            '¿Quieres probar la app con datos reales?',
                            style: AppTheme.displayStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inyecta un mes completo de turnos rotativos (Mañana, Tarde, Noche), horas extra y hábitos orbitales de ejemplo en un solo toque.',
                        style: AppTheme.bodyStyle(
                          fontSize: 11.5,
                          color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            final demo = await DemoSeederService.seedDemoData(ref);

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: isDark ? AppTheme.obsidianSurfaceElevated : AppTheme.boneSurfaceElevated,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDark ? AppTheme.obsidianBorderHover : AppTheme.boneBorder,
                                    ),
                                  ),
                                  content: Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, color: accent, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Órbita Demo inyectada con éxito (${demo.habits.length} hábitos, ${demo.blocks.length} turnos)',
                                          style: AppTheme.bodyStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(Icons.bolt_rounded, size: 16, color: isDark ? Colors.black : Colors.white),
                          label: Text(
                            '⚡ CARGAR ÓRBITA DE EJEMPLO (DEMO)',
                            style: AppTheme.monoStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.black : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.radiusSm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required bool isDark,
    required Color accent,
    required String stepNumber,
    required String category,
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.bentoCard(
        isLight: !isDark,
        borderRadius: AppTheme.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppTheme.radiusXs,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: AppTheme.borderPrecision,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$stepNumber // $category',
                    style: AppTheme.monoStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    title,
                    style: AppTheme.displayStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.obsidianTextPrimary : AppTheme.boneTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTheme.bodyStyle(
              fontSize: 12,
              height: 1.45,
              color: isDark ? AppTheme.obsidianTextSecondary : AppTheme.boneTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

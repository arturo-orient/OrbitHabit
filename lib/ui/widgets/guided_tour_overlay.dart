import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Modelo inmutable para cada paso del Tutorial Interactivo Guiado (7 Pasos).
class GuidedTourStepData {
  final int stepNumber; // 1..7
  final String? customStepLabel; // ej. '3-A', '6-A'
  final String title;
  final String body;
  final GlobalKey? targetKey;
  final bool isInteractiveAction;
  final String? interactiveHint;
  final EdgeInsets spotlightPadding;
  final double spotlightRadius;

  const GuidedTourStepData({
    required this.stepNumber,
    this.customStepLabel,
    required this.title,
    required this.body,
    this.targetKey,
    this.isInteractiveAction = false,
    this.interactiveHint,
    this.spotlightPadding = const EdgeInsets.all(6.0),
    this.spotlightRadius = 8.0,
  });
}

/// Overlay de Tutorial Guiado con recorte Spotlight real (PathOperation.difference),
/// estética Editorial Suiza (Modo Día Hueso #F6F5F2 / Modo Oscuro Carbón #141414)
/// e interacción táctil directa sobre los elementos iluminados.
class GuidedTourOverlay extends StatefulWidget {
  final int currentStepIndex; // 0..6
  final List<GuidedTourStepData> steps;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback? onInteractiveTargetTap;
  final VoidCallback onCreateFirstTask;
  final VoidCallback onExploreWithDemo;
  final VoidCallback onStartFromScratch;

  const GuidedTourOverlay({
    super.key,
    required this.currentStepIndex,
    required this.steps,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.onInteractiveTargetTap,
    required this.onCreateFirstTask,
    required this.onExploreWithDemo,
    required this.onStartFromScratch,
  });

  @override
  State<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<GuidedTourOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _morphController;
  Rect? _fromRect;
  Rect? _targetRect;
  Timer? _retryTimer1;
  Timer? _retryTimer2;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didUpdateWidget(covariant GuidedTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStepIndex != widget.currentStepIndex) {
      _measureTargetWithRetry();
    }
  }

  void _measureTargetWithRetry() {
    _retryTimer1?.cancel();
    _retryTimer2?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureTarget();
      // Re-medir tras completar transiciones de vista (Órbita <-> 24H) o scroll
      _retryTimer1 = Timer(const Duration(milliseconds: 180), () {
        if (mounted) _measureTarget();
      });
      _retryTimer2 = Timer(const Duration(milliseconds: 340), () {
        if (mounted) _measureTarget();
      });
    });
  }

  void _measureTarget() {
    if (!mounted) return;
    final step = widget.steps[widget.currentStepIndex.clamp(0, widget.steps.length - 1)];
    final key = step.targetKey;
    if (key == null || key.currentContext == null) {
      if (_targetRect != null) {
        setState(() {
          _fromRect = _targetRect;
          _targetRect = null;
        });
      }
      return;
    }

    final renderObject = key.currentContext!.findRenderObject();
    final overlayRenderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize && overlayRenderObject is RenderBox) {
      final topLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlayRenderObject);
      final size = renderObject.size;
      final paddedRect = Rect.fromLTRB(
        topLeft.dx - step.spotlightPadding.left,
        topLeft.dy - step.spotlightPadding.top,
        topLeft.dx + size.width + step.spotlightPadding.right,
        topLeft.dy + size.height + step.spotlightPadding.bottom,
      );
      if (_targetRect != paddedRect) {
        final currentAnimatedRect = _currentInterpolatedRect;
        setState(() {
          _fromRect = currentAnimatedRect ?? paddedRect;
          _targetRect = paddedRect;
        });
        _morphController.forward(from: 0.0);
      }
    }
  }

  Rect? get _currentInterpolatedRect {
    if (_targetRect == null) return null;
    if (_fromRect == null) return _targetRect;
    final t = Curves.easeOutCubic.transform(_morphController.value);
    return Rect.lerp(_fromRect, _targetRect, t);
  }

  @override
  void dispose() {
    _retryTimer1?.cancel();
    _retryTimer2?.cancel();
    _pulseController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final stepIndex = widget.currentStepIndex.clamp(0, widget.steps.length - 1);
    final step = widget.steps[stepIndex];
    final totalSteps = widget.steps.length;
    final isLastStep = stepIndex == totalSteps - 1;

    // Paleta estricta del Prompt Maestro
    final scrimColor = isDark
        ? const Color(0xFF0A0A0A).withValues(alpha: 0.78)
        : const Color(0xFF121212).withValues(alpha: 0.65);

    final cardBg = isDark ? const Color(0xFF141414) : const Color(0xFFF6F5F2);
    final cardBorder = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD8D5CE);
    final textPrimary = isDark ? const Color(0xFFF4F3EF) : const Color(0xFF0A0A0A);
    final textSecondary = isDark ? const Color(0xFF9E9C96) : const Color(0xFF52514E);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = constraints.maxHeight;
        final screenWidth = constraints.maxWidth;
        final rect = _targetRect;

        // Posicionamiento inteligente: si el elemento iluminado está en la mitad inferior
        // (targetRect.center.dy > screenHeight * 0.52), colocamos la tarjeta arriba del recorte;
        // si no, debajo, para no tapar nunca el widget enfocado.
        final bool placeCardAbove =
            rect != null && (rect.center.dy > screenHeight * 0.52);

        double? cardTop;
        double? cardBottom;

        if (rect == null) {
          cardBottom = 24.0;
        } else if (placeCardAbove) {
          final desiredBottom = (screenHeight - rect.top) + 14.0;
          final maxAllowedOffset = (screenHeight - 290.0).clamp(16.0, screenHeight);
          cardBottom = desiredBottom.clamp(16.0, maxAllowedOffset);
        } else {
          final desiredTop = rect.bottom + 14.0;
          final maxAllowedOffset = (screenHeight - 290.0).clamp(16.0, screenHeight);
          cardTop = desiredTop.clamp(16.0, maxAllowedOffset);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Pintor del Scrim con recorte Spotlight interpolado suavemente (evenOdd) y borde iluminado pulsante
            SizedBox.expand(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _morphController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SpotlightCutoutPainter(
                      targetRect: _currentInterpolatedRect,
                      spotlightRadius: step.spotlightRadius,
                      scrimColor: scrimColor,
                      accentColor: accent,
                      pulseValue: _pulseController.value,
                    ),
                  );
                },
              ),
            ),

            // 2. Zona interactiva sobre el recorte iluminado (Pasos activos o toque directo)
            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (widget.onInteractiveTargetTap != null) {
                      widget.onInteractiveTargetTap!();
                    } else {
                      widget.onNext();
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),

            // 3. Tarjeta Editorial del Guía con transición fluida entre posiciones y entre pasos
            AnimatedAlign(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              alignment: placeCardAbove ? Alignment.bottomCenter : (rect == null ? Alignment.bottomCenter : Alignment.topCenter),
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: cardTop ?? 16,
                  bottom: cardBottom ?? 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth > 500 ? 480 : screenWidth - 32,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.05),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            )),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.975, end: 1.0).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey<int>(stepIndex),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cardBorder,
                            width: 1.0,
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // Cabecera: [ PASO 0X / 07 ] + [ SALTAR ]
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '[ PASO ${step.customStepLabel ?? step.stepNumber.toString().padLeft(2, '0')} / ${totalSteps.toString().padLeft(2, '0')} ]',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.monoStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                if (!isLastStep)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onSkip();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: cardBorder,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        '[ SALTAR ]',
                                        style: AppTheme.monoStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Barra de progreso minimalista de 7 segmentos con transición animada
                            Row(
                              children: List.generate(totalSteps, (index) {
                                final isCompleted = index <= stepIndex;
                                return Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    height: 3.0,
                                    margin: EdgeInsets.only(right: index < totalSteps - 1 ? 5.0 : 0.0),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? accent
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.12)
                                              : Colors.black.withValues(alpha: 0.10)),
                                      borderRadius: BorderRadius.circular(1.5),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          const SizedBox(height: 14),

                          // Título Editorial
                          Text(
                            step.title,
                            style: AppTheme.displayStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Cuerpo Conciso (2-3 líneas)
                          Text(
                            step.body,
                            style: AppTheme.bodyStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: textSecondary,
                            ),
                          ),

                          // Indicador de Paso Interactivo
                          if (step.isInteractiveAction) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                if (widget.onInteractiveTargetTap != null) {
                                  widget.onInteractiveTargetTap!();
                                } else {
                                  widget.onNext();
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        step.interactiveHint ?? 'Toca el botón iluminado para continuar',
                                        style: AppTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_outward_rounded,
                                      size: 15,
                                      color: accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Controles Inferiores
                          if (isLastStep) ...[
                            // PASO 7: Opciones de Despegue Final (Solo + Crear mi primera tarea y Cerrar tutorial)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onCreateFirstTask();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  '[ + CREAR MI PRIMERA TAREA ]',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  widget.onStartFromScratch();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  side: BorderSide(color: cardBorder, width: 1.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  'Cerrar tutorial',
                                  style: AppTheme.monoStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (stepIndex > 0)
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      widget.onPrevious();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cardBorder, width: 1.0),
                                      ),
                                      child: Text(
                                        '[ ← ANTERIOR ]',
                                        style: AppTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    if (step.isInteractiveAction && widget.onInteractiveTargetTap != null) {
                                      widget.onInteractiveTargetTap!();
                                    } else {
                                      widget.onNext();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '[ SIGUIENTE → ]',
                                      style: AppTheme.monoStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
},
);
  }
}

class _SpotlightCutoutPainter extends CustomPainter {
  final Rect? targetRect;
  final double spotlightRadius;
  final Color scrimColor;
  final Color accentColor;
  final double pulseValue;

  _SpotlightCutoutPainter({
    required this.targetRect,
    required this.spotlightRadius,
    required this.scrimColor,
    required this.accentColor,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreenPath = Path()..addRect(Offset.zero & size);
    final scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;

    if (targetRect == null) {
      canvas.drawPath(fullScreenPath, scrimPaint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(
      targetRect!,
      Radius.circular(spotlightRadius),
    );

    // Recorte quirúrgico compatible con todos los motores gráficos (Web / Mobile)
    final cutoutPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(cutoutPath, scrimPaint);

    // Iluminación interna sutil sobre el elemento enfocado para que resalte en modo oscuro/claro
    final innerGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.09 + (0.07 * pulseValue))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, innerGlowPaint);

    // Resplandor perimetral suave alrededor del recorte
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28 + (0.18 * pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawRRect(rrect, glowPaint);

    // Marco técnico pulsante de 1.8px alrededor del Spotlight
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.80 + (0.20 * pulseValue))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rrect, borderPaint);

    // Halo exterior sutil de precisión
    final outerExpand = 4.0 + (3.0 * pulseValue);
    final outerRRect = RRect.fromRectAndRadius(
      targetRect!.inflate(outerExpand),
      Radius.circular(spotlightRadius + outerExpand),
    );
    final haloPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.30 * (1.0 - pulseValue * 0.4))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(outerRRect, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightCutoutPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.accentColor != accentColor;
  }
}

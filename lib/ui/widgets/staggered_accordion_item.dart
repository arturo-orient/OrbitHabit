import 'package:flutter/material.dart';

/// Despliega las tarjetas en cascada coordinada con apertura de fuelle / acordeón físico
/// sincronizada con el controlador maestro de la pantalla.
class StaggeredAccordionItem extends StatelessWidget {
  final int index;
  final Animation<double> parentAnimation;
  final Widget child;

  const StaggeredAccordionItem({
    Key? key,
    required this.index,
    required this.parentAnimation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Ventana temporal escalonada para cada elemento (10% de desfase entre tarjetas)
    final start = (index * 0.10).clamp(0.0, 0.65);
    final end = (start + 0.35).clamp(0.0, 1.0);

    final itemCurve = CurvedAnimation(
      parent: parentAnimation,
      curve: Interval(start, end, curve: const Cubic(0.16, 1.0, 0.3, 1.0)),
    );

    return AnimatedBuilder(
      animation: itemCurve,
      builder: (context, child) {
        final progress = itemCurve.value;
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0.0, 32.0 * (1.0 - progress)), // Desplazamiento ascendente
            child: Transform(
              transform: Matrix4.identity()
                ..scale(1.0, 0.75 + (0.25 * progress)), // Expansión de fuelle / acordeón
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: child,
      ),
    );
  }
}

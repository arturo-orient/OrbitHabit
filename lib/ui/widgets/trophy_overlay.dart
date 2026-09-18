import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/achievement.dart';
import 'achievement_art_painter.dart';

class TrophyOverlay {
  static void show(BuildContext context, Achievement achievement) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: TrophyOverlayWidget(
          achievement: achievement,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class TrophyOverlayWidget extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismiss;

  const TrophyOverlayWidget({
    Key? key,
    required this.achievement,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<TrophyOverlayWidget> createState() => _TrophyOverlayWidgetState();
}

class _TrophyOverlayWidgetState extends State<TrophyOverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    // PlayStation style: slides in from the top with an elegant elastic/decelerating curve
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Automatically slide out after 3.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(widget.achievement.colorValue);

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              // Sleek dark PlayStation pill design with subtle glass border
              color: const Color(0xFF1E222B).withOpacity(0.96),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
              border: Border.all(
                color: themeColor.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Medal circle on the left with custom painter geometry
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: CustomPaint(
                      painter: AchievementArtPainter(
                        id: widget.achievement.id,
                        isUnlocked: true,
                        themeColor: themeColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                
                // Description details
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏆  LOGRO DESBLOQUEADO',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE5D08F), // Light golden text
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.achievement.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Unlocked sparkle node on the right
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '✓',
                    style: GoogleFonts.outfit(
                      color: themeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

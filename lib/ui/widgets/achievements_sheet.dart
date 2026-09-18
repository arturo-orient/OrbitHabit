import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/achievement.dart';
import '../../providers/habit_provider.dart';
import '../../services/sound_service.dart';
import 'achievement_art_painter.dart';

class AchievementsSheet extends ConsumerWidget {
  const AchievementsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final achievements = Achievement.calculate(habits);

    final int unlockedCount = achievements.where((a) => a.isUnlocked).length;
    final double overallProgress = achievements.isEmpty ? 0.0 : unlockedCount / achievements.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF707A8A);
    final cardBgColor = Theme.of(context).cardColor;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle indicator
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 20),

            // Top Header: Summary progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tus Trofeos Zen',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Celebrando tu constancia y superación personal',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: textColor.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84A59D).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$unlockedCount / ${achievements.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF84A59D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Clean Horizontal Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        value: overallProgress,
                        backgroundColor: textColor.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF84A59D)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // GridView of 2 columns (Album)
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                physics: const BouncingScrollPhysics(),
                itemCount: achievements.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.76, // Height/width ratio
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) {
                  final trophy = achievements[index];
                  return _buildTrophyCard(context, trophy, cardBgColor, textColor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyCard(BuildContext context, Achievement trophy, Color cardBg, Color textColor) {
    final primaryColor = Color(trophy.colorValue);

    return GestureDetector(
      onTap: () {
        if (trophy.isUnlocked) {
          // Zen auditory feedback and haptic tick on tap
          HapticFeedback.selectionClick();
          SoundService().playCheck(); // Native water drop check sound!
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Row(
                children: [
                  const Text('✨ ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      '¡Logro Desbloqueado! "${trophy.title}"',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF707A8A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Text(
                'Logro Bloqueado. ${trophy.description}',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: trophy.isUnlocked 
                  ? primaryColor.withOpacity(0.04) 
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: trophy.isUnlocked 
                ? primaryColor.withOpacity(0.12) 
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Vector Art Medal Space
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: CustomPaint(
                      painter: AchievementArtPainter(
                        id: trophy.id,
                        isUnlocked: trophy.isUnlocked,
                        themeColor: primaryColor,
                      ),
                    ),
                  ),
                  
                  // Unlock Badge (Float top-right of medal area)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: trophy.isUnlocked 
                            ? primaryColor.withOpacity(0.15) 
                            : textColor.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        trophy.isUnlocked ? Icons.check : Icons.lock_outline,
                        size: 12,
                        color: trophy.isUnlocked ? primaryColor : textColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              trophy.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: trophy.isUnlocked 
                    ? textColor 
                    : textColor.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 4),

            // Short Description
            Text(
              trophy.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: textColor.withOpacity(0.35),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // Mini Progress indicator
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      trophy.isUnlocked ? 'Desbloqueado' : 'Progreso',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: trophy.isUnlocked ? primaryColor : textColor.withOpacity(0.3),
                      ),
                    ),
                    Text(
                      trophy.progressText,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: trophy.isUnlocked ? primaryColor : textColor.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      value: trophy.progress,
                      backgroundColor: textColor.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        trophy.isUnlocked ? primaryColor : textColor.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de tokens y temas de autor para OrbitHabit.
/// Inspirado en Neo-Bento con rigor técnico suizo (Swiss Grid).
class AppTheme {
  AppTheme._();

  // ==========================================
  // PALETA CROMÁTICA EXACTA
  // ==========================================

  // Modo Oscuro (Obsidiana)
  static const Color obsidianCanvas = Color(0xFF09090B);
  static const Color obsidianSurface = Color(0xFF121215);
  static const Color obsidianSurfaceElevated = Color(0xFF18181C);
  static const Color obsidianBorder = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color obsidianBorderHover = Color(0x28FFFFFF); // rgba(255, 255, 255, 0.16)
  static const Color obsidianTextPrimary = Color(0xFFF4F4F5);
  static const Color obsidianTextSecondary = Color(0xFF71717A);
  static const Color obsidianTextMuted = Color(0xFF52525B);

  // Modo Claro (Hueso / Papel Suizo de Alta Legibilidad)
  static const Color boneCanvas = Color(0xFFF7F7F8);
  static const Color boneSurface = Color(0xFFFFFFFF);
  static const Color boneSurfaceElevated = Color(0xFFF0F1F3);
  static const Color boneBorder = Color(0xFFE2E4E8);
  static const Color boneBorderHover = Color(0xFFCBD0D6);
  static const Color boneTextPrimary = Color(0xFF09090B); // Negro carbón de máximo contraste
  static const Color boneTextSecondary = Color(0xFF4B5563); // Gris 600 nítido y legible
  static const Color boneTextMuted = Color(0xFF6B7280); // Gris 500

  // Acento Único (Fósforo en Oscuro / Cobalto Suizo en Claro)
  static const Color accentPhosphor = Color(0xFFD4FF00); // Verde Citrón Ácido (Oscuro)
  static const Color accentPhosphorDim = Color(0x1FD4FF00); // 12% opacidad
  static const Color accentPhosphorGlow = Color(0x40D4FF00); // 25% opacidad
  static const Color accentCobalt = Color(0xFF0052FF); // Azul Cobalto de alto contraste (Claro)

  /// Devuelve el color de acento ideal según el tema:
  /// - Modo oscuro: Fósforo Citrón eléctrico (#D4FF00) sobre fondo obsidiana.
  /// - Modo claro: Azul Cobalto de alta gama (#0052FF) con contraste AAA sobre fondo blanco.
  static Color dynamicAccent(bool isDark) => isDark ? accentPhosphor : accentCobalt;

  // Acentos Semánticos Suizos
  static const Color errorRed = Color(0xFFFF453A);
  static const Color successGreen = Color(0xFF32D74B);

  // ==========================================
  // GEOMETRÍA Y BORDES
  // ==========================================
  static const double borderPrecision = 1.0;
  static final BorderRadius radiusXs = BorderRadius.circular(4.0);
  static final BorderRadius radiusSm = BorderRadius.circular(6.0);
  static final BorderRadius radiusMd = BorderRadius.circular(8.0); // Estándar Bento
  static final BorderRadius radiusLg = BorderRadius.circular(12.0);

  // ==========================================
  // DECORACIONES BENTO (CERO SOMBRAS SUCIAS)
  // ==========================================
  static BoxDecoration bentoCard({
    bool isLight = false,
    Color? surfaceColor,
    Color? borderColor,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? (isLight ? boneSurface : obsidianSurface),
      borderRadius: borderRadius ?? radiusMd,
      border: Border.all(
        color: borderColor ?? (isLight ? boneBorder : obsidianBorder),
        width: borderPrecision,
      ),
    );
  }

  // ==========================================
  // TIPOGRAFÍAS DE PRECISIÓN (EDITORIAL & MONO)
  // ==========================================
  static TextStyle displayStyle({
    double fontSize = 24.0,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bodyStyle({
    double fontSize = 14.0,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle monoStyle({
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.0,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ==========================================
  // CONSTRUCCIÓN THEMEDATA NATIVO FLUTTER
  // ==========================================
  static ThemeData buildDarkTheme() {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: displayStyle(fontSize: 32, fontWeight: FontWeight.w700, color: obsidianTextPrimary),
      displayMedium: displayStyle(fontSize: 26, fontWeight: FontWeight.w600, color: obsidianTextPrimary),
      displaySmall: displayStyle(fontSize: 20, fontWeight: FontWeight.w600, color: obsidianTextPrimary),
      headlineMedium: displayStyle(fontSize: 18, fontWeight: FontWeight.w600, color: obsidianTextPrimary),
      bodyLarge: bodyStyle(fontSize: 16, fontWeight: FontWeight.w400, color: obsidianTextPrimary),
      bodyMedium: bodyStyle(fontSize: 14, fontWeight: FontWeight.w400, color: obsidianTextSecondary),
      bodySmall: bodyStyle(fontSize: 12, fontWeight: FontWeight.w400, color: obsidianTextMuted),
      labelLarge: monoStyle(fontSize: 13, fontWeight: FontWeight.w600, color: obsidianTextPrimary),
      labelMedium: monoStyle(fontSize: 11, fontWeight: FontWeight.w500, color: obsidianTextSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianCanvas,
      canvasColor: obsidianCanvas,
      cardColor: obsidianSurface,
      dividerColor: obsidianBorder,
      colorScheme: const ColorScheme.dark(
        surface: obsidianSurface,
        primary: accentPhosphor,
        secondary: accentPhosphor,
        error: errorRed,
        outline: obsidianBorder,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: obsidianTextPrimary, size: 20),
        titleTextStyle: TextStyle(
          color: obsidianTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData buildLightTheme() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: displayStyle(fontSize: 32, fontWeight: FontWeight.w700, color: boneTextPrimary),
      displayMedium: displayStyle(fontSize: 26, fontWeight: FontWeight.w600, color: boneTextPrimary),
      displaySmall: displayStyle(fontSize: 20, fontWeight: FontWeight.w600, color: boneTextPrimary),
      headlineMedium: displayStyle(fontSize: 18, fontWeight: FontWeight.w600, color: boneTextPrimary),
      bodyLarge: bodyStyle(fontSize: 16, fontWeight: FontWeight.w400, color: boneTextPrimary),
      bodyMedium: bodyStyle(fontSize: 14, fontWeight: FontWeight.w400, color: boneTextSecondary),
      bodySmall: bodyStyle(fontSize: 12, fontWeight: FontWeight.w400, color: boneTextMuted),
      labelLarge: monoStyle(fontSize: 13, fontWeight: FontWeight.w600, color: boneTextPrimary),
      labelMedium: monoStyle(fontSize: 11, fontWeight: FontWeight.w500, color: boneTextSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: boneCanvas,
      canvasColor: boneCanvas,
      cardColor: boneSurface,
      dividerColor: boneBorder,
      colorScheme: const ColorScheme.light(
        surface: boneSurface,
        primary: boneTextPrimary,
        secondary: accentCobalt,
        error: errorRed,
        outline: boneBorder,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: boneTextPrimary, size: 20),
        titleTextStyle: TextStyle(
          color: boneTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

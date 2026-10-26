import 'package:flutter/material.dart';

class TempoTheme {
  // Apple System Accent
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemBlueDark = Color(0xFF0A84FF);

  // Pure Apple dark canvas layers
  static const Color obsidian = Color(0xFF0C0D0F);
  static const Color surfaceDark = Color(0xFF16171A);
  static const Color surfaceElevated = Color(0xFF1C1C1E);
  static const Color surfaceGlass = Color(0x1AFFFFFF);

  // Apple Light Theme layers
  static const Color lightCanvas = Color(0xFFF5F5F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xCCFFFFFF);

  // Hairline borders (Soft & unobtrusive)
  static const Color glassBorder = Color(0x14FFFFFF); // 8% white
  static const Color glassBorderFocused = Color(0x2EFFFFFF); // 18% white
  static const Color dividerDark = Color(0x10FFFFFF); // 6% white

  static const Color lightGlassBorder = Color(0x0D000000); // 5% black
  static const Color lightDivider = Color(0x0F000000);

  // Text hierarchy - Dark
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF636366);

  // Text hierarchy - Light
  static const Color lightTextPrimary = Color(0xFF1D1D1F);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightTextMuted = Color(0xFF86868B);

  // Neutral Tag Backgrounds (Apple Monochromatic)
  static const Color neutralTagDark = Color(0xFF2C2C2E);
  static const Color neutralTagLight = Color(0xFFE5E5EA);

  // Curated Apple Pastel Accent Palette (Low-opacity, soft tints)
  static const Color pastelRose = Color(0xFFF87171); // Soft Blush Rose
  static const Color pastelMint = Color(0xFF6EE7B7); // Soft Sage Mint
  static const Color pastelLilac = Color(0xFFA78BFA); // Soft Muted Lavender
  static const Color pastelHoney = Color(0xFFFBBF24); // Soft Warm Honey
  static const Color pastelSky = Color(0xFF0A84FF); // Apple System Blue
  static const Color pastelSlate = Color(0xFF94A3B8); // Soft Oyster Slate
  static const Color pastelIndigo = Color(0xFF818CF8); // Soft Periwinkle

  // Aliases for compatibility
  static const Color emerald = pastelMint;
  static const Color crimson = pastelRose;
  static const Color violet = pastelLilac;
  static const Color amber = pastelHoney;
  static const Color sky = pastelSky;
  static const Color slate = pastelSlate;

  // Background Wallpaper Presets (Generates rich physical depth behind frosted glass)
  static const List<Map<String, dynamic>> backgroundThemes = [
    {
      'id': 'obsidian',
      'name': 'Obsidian',
      'description': 'Pure dark minimal',
      'color1': Color(0xFF0A0B0E),
      'color2': Color(0xFF08090C),
      'accent': Color(0xFF151821),
    },
    {
      'id': 'sonoma',
      'name': 'Sonoma Dusk',
      'description': 'Warm twilight gradient',
      'color1': Color(0xFF1A1224),
      'color2': Color(0xFF2A1525),
      'accent': Color(0xFF431D38),
    },
    {
      'id': 'monterey',
      'name': 'Monterey Waves',
      'description': 'Deep ocean indigo',
      'color1': Color(0xFF0D1728),
      'color2': Color(0xFF12233E),
      'accent': Color(0xFF1B3B6F),
    },
    {
      'id': 'sequoia',
      'name': 'Sequoia Forest',
      'description': 'Misty emerald slate',
      'color1': Color(0xFF0E1A16),
      'color2': Color(0xFF142621),
      'accent': Color(0xFF1D3B32),
    },
    {
      'id': 'aurora',
      'name': 'Nordic Frost',
      'description': 'Subtle cyan & violet glow',
      'color1': Color(0xFF0F1424),
      'color2': Color(0xFF171B33),
      'accent': Color(0xFF232D52),
    },
    {
      'id': 'studio_light',
      'name': 'Studio Light',
      'description': 'Crisp frosted porcelain',
      'color1': Color(0xFFF2F2F7),
      'color2': Color(0xFFE5E5EA),
      'accent': Color(0xFFD1D1D6),
    },
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidian,
      primaryColor: systemBlueDark,
      colorScheme: const ColorScheme.dark(
        primary: systemBlueDark,
        secondary: pastelLilac,
        surface: surfaceElevated,
        error: pastelRose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: '-apple-system',
      fontFamilyFallback: const ['.SF Pro Text', '.SF Pro Display', 'Roboto', 'sans-serif'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: textPrimary),
        headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: textPrimary),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.1, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: textMuted),
      ),
      iconTheme: const IconThemeData(color: textSecondary, size: 18),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: glassBorder, width: 0.8),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightCanvas,
      primaryColor: systemBlue,
      colorScheme: const ColorScheme.light(
        primary: systemBlue,
        secondary: pastelLilac,
        surface: lightSurface,
        error: pastelRose,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
      ),
      fontFamily: '-apple-system',
      fontFamilyFallback: const ['.SF Pro Text', '.SF Pro Display', 'Roboto', 'sans-serif'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: lightTextPrimary),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: lightTextPrimary),
        headlineSmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: lightTextPrimary),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: -0.2, color: lightTextPrimary),
        bodyLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.1, color: lightTextPrimary),
        bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: lightTextSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: lightTextMuted),
      ),
      iconTheme: const IconThemeData(color: lightTextSecondary, size: 18),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightGlassBorder, width: 0.8),
        ),
      ),
    );
  }
}

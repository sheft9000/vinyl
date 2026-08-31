import 'package:flutter/material.dart';

/// Colori fissi dell'app. L'accento invece non e' qui: viene estratto dalla
/// copertina di cio' che stai ascoltando (vedi player/accent.dart).
abstract final class Vinyl {
  static const bg = Color(0xFF07070A);
  static const surface = Color(0xFF121217);
  static const surfaceHigh = Color(0xFF1B1B22);
  static const stroke = Color(0x14FFFFFF);
  static const strokeStrong = Color(0x24FFFFFF);
  static const text = Color(0xFFF5F5F8);
  static const textDim = Color(0xFF9A9AA7);
  static const defaultAccent = Color(0xFF7C5CFF);

  static const radiusCard = 14.0;
  static const radiusSheet = 28.0;
  static const gutter = 20.0;

  /// Ombra morbida e bassa sotto le copertine: e' cio' che da' l'impressione
  /// di superfici lucide appoggiate sul fondo, invece che disegnate su di esso.
  static List<BoxShadow> lift(double strength) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.55 * strength),
          blurRadius: 30 * strength,
          offset: Offset(0, 12 * strength),
        ),
      ];
}

ThemeData buildTheme(Color accent) {
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: Vinyl.bg,
    primary: accent,
    onSurface: Vinyl.text,
  );

  final base = ThemeData(
    useMaterial3: true,
    // Inter ovunque: e' il sostituto di SF Pro. Senza, le schermate
    // ricadono su Roboto e nessuna sembra iOS.
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Vinyl.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Vinyl.text, displayColor: Vinyl.text)
        .copyWith(
          headlineSmall: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.35),
          bodySmall: TextStyle(fontSize: 12.5, color: Vinyl.textDim),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Vinyl.text,
        letterSpacing: -0.3,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: Vinyl.text,
      iconColor: Vinyl.textDim,
      contentPadding: EdgeInsets.symmetric(horizontal: Vinyl.gutter),
    ),
    dividerTheme: const DividerThemeData(
      color: Vinyl.stroke,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Vinyl.surfaceHigh,
      hintStyle: const TextStyle(color: Vinyl.textDim),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Vinyl.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: accent,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Vinyl.surfaceHigh,
      contentTextStyle: const TextStyle(color: Vinyl.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

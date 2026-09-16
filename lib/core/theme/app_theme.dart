import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Every color in the app — no widget may use an inline hex value.
class AppColors {
  // Light (paper & ink)
  static const ivory = Color(0xFFFAF6EE);
  static const parchment = Color(0xFFF3EDDF);
  static const ink = Color(0xFF1F1B16);
  static const muted = Color(0xFF8A8073);
  static const rule = Color(0xFFE5DECF);
  static const accent = Color(0xFF8A6D2F); // antique gold
  static const accentContainer = Color(0xFFE8DDBF);
  static const selected = Color(0xFFEFE6CE);

  // Dark (candlelit study)
  static const nightBg = Color(0xFF171310);
  static const nightSurface = Color(0xFF211B16);
  static const nightInk = Color(0xFFEDE5D8);
  static const nightMuted = Color(0xFF9C9082);
  static const nightRule = Color(0xFF332B23);
  static const nightAccent = Color(0xFFD4B96A);
  static const nightSelected = Color(0xFF3A3226);
}

ThemeData lightTheme(ColorScheme scheme) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ivory,
  );
  return base.copyWith(
    textTheme: _textTheme(base.textTheme, AppColors.ink),
  );
}

ThemeData darkTheme(ColorScheme scheme) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.nightBg,
  );
  return base.copyWith(
    textTheme: _textTheme(base.textTheme, AppColors.nightInk),
  );
}

/// Scripture reads in serif; UI labels in a humanist sans.
TextTheme _textTheme(TextTheme base, Color display) {
  final serif = GoogleFonts.crimsonProTextTheme(base.apply(bodyColor: display));
  return serif.apply(bodyColor: display).copyWith(
        labelLarge: GoogleFonts.inter(
          textStyle: base.labelLarge,
          color: display,
        ),
        labelMedium: GoogleFonts.inter(
          textStyle: base.labelMedium,
          color: display,
        ),
        labelSmall: GoogleFonts.inter(
          textStyle: base.labelSmall,
          color: display,
        ),
      );
}

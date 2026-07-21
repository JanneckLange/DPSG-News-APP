import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// DPSG-Farben und Theme, abgeleitet aus dem offiziellen Corporate-Design-
/// Leitfaden (corporate_design_leitfaden_-_dpsg.pdf, Kapitel 10 "Die
/// Schriftarten in der DPSG" und Kapitel 11 "Farben").
class AppTheme {
  AppTheme._();

  /// "DPSG, Dachzeile, Lilie" — Pantone 533, RGB 0/48/86.
  static const primary = Color(0xFF003056);

  /// "Unterstrich, Wegzeichen" — Pantone 187, RGB 129/10/26.
  static const secondary = Color(0xFF810A1A);

  // Stufenfarben — genutzt z.B. für Topic-Chips, wenn der Topic-Wert einer
  // bekannten Stufe entspricht (siehe stufenfarbeFor).
  static const stufeWoelflinge = Color(0xFFFF6400);
  static const stufeJungpfadfinder = Color(0xFF2F53A7);
  static const stufePfadfinder = Color(0xFF00823C);
  static const stufeRover = Color(0xFFCC1F2F);

  static const _stufenfarben = <String, Color>{
    'Wölflinge': stufeWoelflinge,
    'Jungpfadfinder': stufeJungpfadfinder,
    'Pfadfinder': stufePfadfinder,
    'Rover': stufeRover,
  };

  /// Liefert die offizielle Stufenfarbe fuer [topic], falls bekannt.
  static Color? stufenfarbeFor(String? topic) => _stufenfarben[topic];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: brightness)
          .copyWith(secondary: secondary),
      useMaterial3: true,
    );
    // Arvo nur fuer Headlines/Titel (CI-Akzent). Myriad Pro (Fliesstext laut
    // CI-Leitfaden) ist eine kommerzielle Adobe-Schrift ohne freie
    // Alternative im Projekt - Fliesstext bleibt bewusst beim Systemfont.
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: GoogleFonts.arvo(textStyle: base.textTheme.headlineLarge),
        headlineMedium: GoogleFonts.arvo(textStyle: base.textTheme.headlineMedium),
        headlineSmall: GoogleFonts.arvo(textStyle: base.textTheme.headlineSmall),
        titleLarge: GoogleFonts.arvo(textStyle: base.textTheme.titleLarge),
      ),
    );
  }
}

class AppSpacing {
  AppSpacing._();

  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;

  static const radiusM = 12.0;
  static const radiusL = 16.0;
}

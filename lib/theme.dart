import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Poster-art palette: warm paper, pine, poppy orange, gold.
class P {
  static const poppy = Color(0xFFE8590C);
  static const gold = Color(0xFFE9B44C);
  static const pine = Color(0xFF2E5339);
  static const doneGreen = Color(0xFF3E7C4A);

  // light
  static const bgL = Color(0xFFF5EFDF);
  static const cardL = Color(0xFFFFFDF6);
  static const inkL = Color(0xFF26331F);
  static const ink2L = Color(0xFF6D745C);
  static const lineL = Color(0xFFE5DDC6);

  // dark
  static const bgD = Color(0xFF141B15);
  static const cardD = Color(0xFF1D271F);
  static const inkD = Color(0xFFEDE6D2);
  static const ink2D = Color(0xFFA8B096);
  static const lineD = Color(0xFF2B372C);
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? P.bgD : P.bgL;
  Color get card => isDark ? P.cardD : P.cardL;
  Color get ink => isDark ? P.inkD : P.inkL;
  Color get ink2 => isDark ? P.ink2D : P.ink2L;
  Color get line => isDark ? P.lineD : P.lineL;
}

TextStyle serif(BuildContext c,
        {double size = 20, Color? color, FontWeight weight = FontWeight.w500}) =>
    GoogleFonts.dmSerifDisplay(
        fontSize: size, color: color ?? c.ink, fontWeight: weight);

ThemeData poppyTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? P.bgD : P.bgL;
  final card = dark ? P.cardD : P.cardL;
  final ink = dark ? P.inkD : P.inkL;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: P.poppy,
      brightness: b,
      surface: bg,
      primary: P.poppy,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? P.lineD : P.lineL),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: dark ? P.lineD : P.lineL,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: bg, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: ink,
      displayColor: ink,
    ),
  );
}

/// Season badge chip used everywhere.
class SeasonPill extends StatelessWidget {
  final String text;
  final String kind; // now | hard | best | done
  const SeasonPill(this.text, this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final (bgc, fgc) = switch (kind) {
      'now' => dark
          ? (const Color(0xFF22402A), const Color(0xFF8FCE9A))
          : (const Color(0xFFD9ECDB), const Color(0xFF28632F)),
      'hard' => dark
          ? (const Color(0xFF4A2A12), const Color(0xFFF0A469))
          : (const Color(0xFFFBDCC5), const Color(0xFFA44A08)),
      'done' => dark
          ? (const Color(0xFF22402A), const Color(0xFF8FCE9A))
          : (const Color(0xFFD9ECDB), const Color(0xFF28632F)),
      _ => (context.line, context.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration:
          BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w800, color: fgc)),
    );
  }
}

/// Round tap-to-mark-done circle.
class DoneCircle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  final double size;
  const DoneCircle({super.key, required this.on, required this.onTap, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? P.doneGreen : context.card,
          border: Border.all(
              color: on ? P.doneGreen : context.line, width: 2),
        ),
        child: on
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : null,
      ),
    );
  }
}

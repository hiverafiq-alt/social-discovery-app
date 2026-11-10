import 'package:flutter/material.dart';

abstract final class P {
  static const ink = Color(0xFF090711),
      surface = Color(0xFF15101F),
      plum = Color(0xFF25152F);
  static const violet = Color(0xFF9460F7),
      lilac = Color(0xFFC3A3FF),
      blush = Color(0xFFE982B3);
  static const white = Color(0xFFF8F4FC),
      mist = Color(0xFFB8B1C6),
      teal = Color(0xFF79D8CC);
  static const amber = Color(0xFFF5BE74), line = Color(0xFF342A43);
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ink,
    colorScheme: const ColorScheme.dark(
      primary: lilac,
      secondary: blush,
      surface: surface,
      onPrimary: ink,
      onSurface: white,
      error: amber,
    ),
    useMaterial3: true,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        height: 1.08,
        letterSpacing: -2,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: TextStyle(
        fontSize: 36,
        height: 1.12,
        letterSpacing: -1.3,
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        letterSpacing: -.8,
        fontWeight: FontWeight.w500,
      ),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45),
      labelSmall: TextStyle(
        fontSize: 11,
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    dividerColor: line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        foregroundColor: ink,
        backgroundColor: lilac,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 56),
        foregroundColor: white,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      modalBarrierColor: Color(0x99000000),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: ink,
      indicatorColor: plum,
      height: 76,
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = P.lilac});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
  );
}

class Monogram extends StatelessWidget {
  const Monogram({super.key, this.size = 52});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Social Discovery',
    image: true,
    child: CustomPaint(size: Size(size, size), painter: _MonogramPainter()),
  );
}

class _MonogramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [P.white, P.lilac, P.violet],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    canvas.drawCircle(const Offset(38, 43), 23, p);
    canvas.drawCircle(const Offset(64, 60), 23, Paint()..color = P.lilac);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 20});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: P.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: P.line),
    ),
    child: child,
  );
}

void notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );

Future<T?> sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: child,
          ),
        ),
      ),
    );

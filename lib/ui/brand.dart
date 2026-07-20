import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Markenfarben (aus dem FahrSignal-Logo abgeleitet).
const Color kBrandNavy = Color(0xFF0E1E38);
const Color kBrandBlue = Color(0xFF1E88E5);

/// Regenbogen-Verlauf des Logos (im Uhrzeigersinn ab oben).
const List<Color> kBrandRainbow = [
  Color(0xFFFF3B30), // Rot
  Color(0xFFFF9500), // Orange
  Color(0xFFFFCC00), // Gelb
  Color(0xFF34C759), // Grün
  Color(0xFF00C7BE), // Türkis
  Color(0xFF1E88E5), // Blau
  Color(0xFF8E5BFF), // Violett
  Color(0xFFFF2D9B), // Magenta
];

const String kBrandTagline = 'Verstehen verbindet. Mobilität für alle.';

/// App-Theme aus den Markenfarben – dezent: Navy-Header, Blau als Seed,
/// Regenbogen bleibt den Kategorien vorbehalten.
ThemeData fahrSignalTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandBlue,
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0B1526)
        : const Color(0xFFF5F7FB),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBrandNavy,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

/// Das FahrSignal-Logo (Lenkrad im Regenbogen-Ring) als Vektor.
/// Die Lenkrad-Farbe passt sich dem Theme an (Navy hell / Weiß dunkel),
/// kann aber per [wheelColor]/[dotColor] überschrieben werden.
class FahrSignalLogo extends StatelessWidget {
  final double size;
  final Color? wheelColor;
  final Color? dotColor;
  const FahrSignalLogo({
    super.key,
    required this.size,
    this.wheelColor,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          wheel: wheelColor ?? (dark ? Colors.white : kBrandNavy),
          dot: dotColor ?? (dark ? kBrandNavy : Colors.white),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color wheel;
  final Color dot;
  _LogoPainter({required this.wheel, required this.dot});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final ring = w * 0.11;
    final r = w / 2 - ring / 2 - w * 0.01;

    // Regenbogen-Ring
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [...kBrandRainbow, kBrandRainbow[0]],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, ringPaint);

    // Lenkrad (Speichen)
    final spoke = Paint()
      ..color = wheel
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.115
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Obere „Flügel" (dippen zur Nabe)
    final wing = Path()
      ..moveTo(0.25 * w, 0.40 * w)
      ..quadraticBezierTo(0.5 * w, 0.55 * w, 0.75 * w, 0.40 * w);
    canvas.drawPath(wing, spoke);

    // Untere Speiche
    canvas.drawLine(Offset(0.5 * w, 0.5 * w), Offset(0.5 * w, 0.73 * w), spoke);

    // Nabe
    canvas.drawCircle(c, 0.145 * w, Paint()..color = wheel);
    canvas.drawCircle(c, 0.056 * w, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wortmarke „FahrSignal": „Fahr" in Navy, „Signal" im Regenbogen-Verlauf.
class FahrSignalWordmark extends StatelessWidget {
  final double fontSize;
  const FahrSignalWordmark({super.key, this.fontSize = 34});

  @override
  Widget build(BuildContext context) {
    final navy = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : kBrandNavy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'Fahr',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.5,
          ),
        ),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF00C7BE),
              Color(0xFF34C759),
              Color(0xFFFFCC00),
              Color(0xFFFF9500),
              Color(0xFFFF2D9B),
            ],
          ).createShader(rect),
          child: Text(
            'Signal',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}

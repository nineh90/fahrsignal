import 'package:flutter/material.dart';
import '../domain/command_catalog.dart';

// Amtsnahe Signalfarben.
const _red = Color(0xFFC1121F);
const _black = Color(0xFF111417);
const _grey = Color(0xFF6B6F73);

/// Rendert ein **echtes Verkehrszeichen** (korrekte Form/Farbe) für ein
/// Kommando mit [SignShape]. Wird identisch beim Fahrlehrer (Kachel) und
/// beim Fahrschüler (Anzeige) verwendet.
///
/// Der Katalog kennt nur noch Tempo-Zeichen: das runde Verbotszeichen mit
/// Zahl (VZ 274) und die Aufhebung (VZ 282). Die früheren Gefahrzeichen sind
/// mit der Kategorie „Gefahr" entfallen.
class TrafficSign extends StatelessWidget {
  final CommandDef def;
  final double size;
  const TrafficSign({super.key, required this.def, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: _sign(def, size));
  }
}

Widget _sign(CommandDef def, double s) => switch (def.sign) {
  SignShape.ende => CustomPaint(
    painter: _EndLimitPainter(),
    size: Size.square(s),
  ),
  // Aufschrift kommt aus dem Katalog, damit ein neues Limit dort mit einer
  // Zeile ergänzt werden kann.
  _ => _frame(
    _RingPainter(),
    _fitted(s, 0.24, Text(def.signText, style: _limitText)),
  ),
};

Widget _frame(CustomPainter painter, Widget content) => Stack(
  alignment: Alignment.center,
  children: [
    Positioned.fill(child: CustomPaint(painter: painter)),
    content,
  ],
);

Widget _fitted(double s, double padFactor, Widget child) => Padding(
  padding: EdgeInsets.all(s * padFactor),
  child: FittedBox(fit: BoxFit.scaleDown, child: child),
);

const _limitText = TextStyle(
  color: _black,
  fontWeight: FontWeight.w900,
  fontSize: 100,
  height: 1,
);

// ---- Formen ----

/// Rundes Verbotszeichen: weiße Scheibe mit rotem Rand (VZ 274).
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s / 2 * 0.98;
    final ring = r * 0.20;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r - ring / 2,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Ende sämtlicher Streckenverbote (VZ 282): weiße Scheibe mit grauem Rand
/// und vier grauen Schrägstrichen.
///
/// Bewusst wenige, dicke Striche: das Zeichen erscheint auch als 34-px-Kachel
/// im Sender – eine feine Schraffur verliefe dort zu einer grauen Fläche.
class _EndLimitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s / 2 * 0.98;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..color = _grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );

    // Schrägstriche an der Innenkante der Scheibe abschneiden.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.85)),
    );
    final stroke = Paint()
      ..color = _grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..isAntiAlias = true;
    for (var i = 0; i < 4; i++) {
      final dx = (i - 1.5) * s * 0.30;
      canvas.drawLine(
        Offset(c.dx - r + dx, c.dy + r),
        Offset(c.dx + r + dx, c.dy - r),
        stroke,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

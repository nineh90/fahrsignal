import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/command_catalog.dart';

// Amtsnahe Signalfarben.
const _red = Color(0xFFC1121F);
const _black = Color(0xFF111417);
const _grey = Color(0xFF6B6F73);

/// Rendert das **amtliche Verkehrszeichen** eines Kommandos. Wird identisch
/// beim Fahrlehrer (Kachel) und beim Fahrschüler (Anzeige) verwendet.
///
/// Zwei Wege, beide vom Katalog gesteuert:
/// - `def.vz` → das amtliche Bild aus `assets/signs/` (Richtungspfeile,
///   Kreisverkehr, Ampel, STOP, Parken …).
/// - [SignShape] → gezeichnet, weil die Aufschrift variabel ist: das runde
///   Verbotszeichen mit Zahl (VZ 274) und die Aufhebung (VZ 282).
class TrafficSign extends StatelessWidget {
  final CommandDef def;

  /// **Höhe** des Zeichens. Breite folgt der Form (siehe [_aspect]).
  final double size;
  const TrafficSign({super.key, required this.def, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * _aspect(def.vz),
      height: size,
      child: _sign(def, size),
    );
  }
}

/// Seitenverhältnis (Breite/Höhe) der Zeichen, die nicht quadratisch sind.
/// Der verkehrsberuhigte Bereich ist ein Querformat-Schild; in eine
/// quadratische Box gezwängt schrumpfte es auf zwei Drittel und wäre auf der
/// Kachel nicht mehr zu entziffern.
double _aspect(String vz) => switch (vz) {
  '325-1' => 732 / 489,
  _ => 1,
};

Widget _sign(CommandDef def, double s) {
  if (def.vz.isNotEmpty) return _Plate(asset: def.vzAsset);
  return switch (def.sign) {
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
}

/// Das Zeichen mit einem schmalen weißen Saum **in seiner eigenen Form**.
///
/// Ohne Absetzung verschwände VZ 209 (blauer Kreis) auf der blauen
/// Richtungs-Kachel und erst recht auf dem blauen Empfängerschirm – die
/// amtlichen Zeichen sind dafür gemacht, gegen Himmel und Landschaft zu
/// stehen, nicht gegen eine Fläche ihrer eigenen Farbe. Am Straßenrand
/// übernimmt das der weiße Rand des Schildblechs.
///
/// Der Saum entsteht, indem dasselbe SVG einmal etwas größer und vollflächig
/// weiß dahintergelegt wird. Das folgt jeder Form von selbst – Kreis, Dreieck,
/// Raute, Achteck, Rechteck – statt sie in ein weißes Kästchen zu setzen, das
/// wie ein aufgeklebter Sticker aussieht.
class _Plate extends StatelessWidget {
  final String asset;
  const _Plate({required this.asset});

  /// Wie weit die Silhouette übersteht. 8 % ergeben bei der 34-px-Kachel noch
  /// einen sichtbaren Saum, ohne dass die Form beim Empfänger aufgedunsen
  /// wirkt.
  static const double _bleed = 1.08;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: _bleed,
          child: SvgPicture.asset(
            asset,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        SvgPicture.asset(asset, fit: BoxFit.contain),
      ],
    );
  }
}

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

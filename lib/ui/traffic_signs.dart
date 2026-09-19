import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/command_catalog.dart';

// Amtsnahe Signalfarben, abgelesen an den SVGs in assets/signs/.
const _red = Color(0xFFC1121C);
const _black = Color(0xFF111417);

/// Wie weit die weiße Absetzung übersteht (Anteil der Kantenlänge).
///
/// Jedes Schild braucht sie: die amtlichen Zeichen sind dafür gemacht, gegen
/// Himmel und Landschaft zu stehen, nicht gegen eine Kachel ihrer eigenen
/// Farbe. Am Straßenrand übernimmt das der weiße Rand des Schildblechs.
const double _kBleed = 0.045;

/// Rendert das Bild eines Kommandos – identisch beim Fahrlehrer (Kachel) und
/// beim Fahrschüler (Anzeige).
///
/// Drei Wege, alle vom Katalog gesteuert:
/// - `def.vz` → das **amtliche Bild** aus `assets/signs/`.
/// - [SignShape.limit] → gezeichnetes VZ 274 (die Zahl kommt aus dem Katalog).
/// - sonst → ein **Piktogramm**: das eigene Bild aus `assets/pictos/` oder das
///   Material-Symbol, flach in [color]. Bewusst **kein** Schild: Der TÜV hat
///   klargestellt, dass erfundene Zeichen – auch nur „im Stil der StVO" – nicht
///   gezeigt werden dürfen. Ein Piktogramm ist damit auf einen Blick als
///   Anweisung der Fahrlehrperson erkennbar, ein Schild als amtliches Zeichen.
class TrafficSign extends StatelessWidget {
  final CommandDef def;

  /// **Optische Größe** – nicht die Kantenlänge. Die tatsächliche Box ist je
  /// nach Form etwas größer oder kleiner, damit alle Bilder nebeneinander
  /// gleich groß *wirken* (siehe [_optisch]).
  final double size;

  /// Farbe des Piktogramms – die Vordergrundfarbe der Fläche, auf der es
  /// steht. Amtliche Zeichen ignorieren sie: die haben ihre eigenen Farben.
  final Color color;

  const TrafficSign({
    super.key,
    required this.def,
    required this.size,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final h = size * _optisch(def);
    return SizedBox(
      width: h * _aspect(def),
      height: h,
      child: _sign(def, h, color),
    );
  }
}

/// Optischer Ausgleich: gleiche Kantenlänge heißt nicht gleiche Wirkung.
/// Bei gleicher Breite hat ein Dreieck nur 43 % der Fläche eines Quadrats, ein
/// Kreis 79 %, eine Raute 50 %. Nebeneinander wirken die Schilder dadurch
/// unterschiedlich groß – hier wird das ausgeglichen, indem jede Form ihre Box
/// gegenüber der Referenz (Kreis) anhebt oder senkt.
///
/// Die Zahlen sind an gerenderten Reihen abgeglichen, nicht rein gerechnet:
/// eine reine Flächennormierung ließe das Dreieck aufdringlich groß werden.
double _optisch(CommandDef def) {
  if (def.vz.isNotEmpty) {
    return switch (def.vz) {
      // Dreiecke – die kleinste Fläche bei gleicher Breite.
      '131' || '205' => 1.16,
      // Raute: halbe Fläche des umschriebenen Quadrats.
      '306' => 1.12,
      // Achteck kommt dem Kreis nahe.
      '206' => 1.03,
      // Dreiecke mit schlankem Inhalt.
      '101' || '301' => 1.18,
      // Hochformat (Zeichen + Zusatzzeichen): `size` ist die Höhe, und die
      // Raute obendrauf wäre bei gleicher Höhe nur halb so groß wie allein.
      '306-1002-10' || '306-1002-20' => 1.25,
      // Vollflächige Quadrate wirken am größten und werden zurückgenommen.
      '314' || '274-1' || '274-1-20' || '365-52' => 0.92,
      // Querformat-Schild: tanzt aus der Reihe, bleibt bei voller Höhe.
      _ => 1,
    };
  }
  return switch (def.sign) {
    // Gezeichnete Tempo-Zeichen sind Kreise wie die Referenz.
    SignShape.limit => 1,
    // Piktogramme: eine Glyphe ohne Fläche wirkt neben einem Schild gleicher
    // Kantenlänge kleiner (das Material-Raster lässt rundum Luft, 20 von 24;
    // die eigenen Bilder sind bewusst gleich gebaut). Ohne Ausgleich stünde
    // das Symbol sichtbar kleiner als das Zeichen daneben.
    SignShape.none => 1.14,
  };
}

/// Seitenverhältnis (Breite/Höhe) der Formen, die nicht quadratisch sind.
///
/// Der verkehrsberuhigte Bereich ist ein echtes Querformat-Schild – ins
/// Quadrat gezwängt schrumpfte es auf zwei Drittel und wäre nicht mehr zu
/// entziffern.
double _aspect(CommandDef def) {
  if (def.vz == '325-1') return 732 / 489;
  // Abknickende Vorfahrt: Hauptzeichen mit Zusatzzeichen darunter, wie am
  // Mast – ein Hochformat.
  if (def.vz.startsWith('306-1002')) return 600 / 1057;
  return 1;
}

Widget _sign(CommandDef def, double s, Color color) {
  if (def.vz.isNotEmpty) return _Plate(asset: def.vzAsset);
  return switch (def.sign) {
    // Aufschrift kommt aus dem Katalog, damit ein neues Limit dort mit einer
    // Zeile ergänzt werden kann.
    SignShape.limit => _frame(
      _VerbotPainter(),
      _fitted(s, 0.28, Text(def.signText, style: _limitText)),
    ),
    SignShape.none => _Pictogram(def: def, size: s, color: color),
  };
}

/// Das amtliche Bild mit einem schmalen weißen Saum **in seiner eigenen Form**.
///
/// Der Saum entsteht, indem dasselbe SVG einmal etwas größer und vollflächig
/// weiß dahintergelegt wird. Das folgt jeder Form von selbst – Kreis, Dreieck,
/// Raute, Achteck, Querformat – statt sie in ein weißes Kästchen zu setzen,
/// das wie ein aufgeklebter Sticker aussieht.
class _Plate extends StatelessWidget {
  final String asset;
  const _Plate({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        Transform.scale(
          scale: 1 + 2 * _kBleed,
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

/// Ein Kommando ohne amtliches Zeichen: flaches, einfarbiges Bild.
///
/// Eigene Bilder (`assets/pictos/`) sind einfarbig gezeichnet und werden hier
/// wie ein Symbol in [color] eingefärbt – dieselbe Mechanik, die dem Material-
/// Symbol seine Farbe gibt. Ohne Fläche dahinter: eine weiße Scheibe oder ein
/// weißes Rechteck sähe wieder nach Schild aus.
class _Pictogram extends StatelessWidget {
  final CommandDef def;
  final double size;
  final Color color;
  const _Pictogram({
    required this.def,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (def.picto.isEmpty) return Icon(def.icon, size: size, color: color);
    return SvgPicture.asset(
      def.pictoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
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

// ---- Gezeichnetes Zeichen ----
//
// Rechnet in Anteilen der Kantenlänge und lässt außen [_kBleed] für die weiße
// Absetzung frei.

/// Verbots-/Beschränkungszeichen: weiße Scheibe mit rotem Ring (VZ 274).
///
/// Der weiße Rand außerhalb des roten Rings ist nicht Zierrat: ohne ihn läuft
/// das Zeichen auf der roten Tempo-Kachel und auf dem roten Empfängerschirm
/// in den Grund über.
class _VerbotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2;
    final ring = r * 0.19;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r * (1 - 2 * _kBleed) - ring / 2,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

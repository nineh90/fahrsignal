import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/command_catalog.dart';

// Amtsnahe Signalfarben, abgelesen an den SVGs in assets/signs/.
const _red = Color(0xFFC1121C);
const _blue = Color(0xFF154889);
const _black = Color(0xFF111417);
const _grey = Color(0xFF6B6F73);

/// Wie weit die weiße Absetzung übersteht (Anteil der Kantenlänge).
///
/// Jedes Schild braucht sie: die amtlichen Zeichen sind dafür gemacht, gegen
/// Himmel und Landschaft zu stehen, nicht gegen eine Kachel ihrer eigenen
/// Farbe. Am Straßenrand übernimmt das der weiße Rand des Schildblechs.
const double _kBleed = 0.045;

/// Rendert das Verkehrszeichen eines Kommandos – identisch beim Fahrlehrer
/// (Kachel) und beim Fahrschüler (Anzeige).
///
/// Drei Wege, alle vom Katalog gesteuert:
/// - `def.vz` → das **amtliche Bild** aus `assets/signs/`.
/// - [SignShape] → gezeichnetes Tempo-Schild (die Zahl kommt aus dem Katalog).
/// - sonst → **Nachbau** in der Formensprache der StVO nach [SignStyle]:
///   das Material-Symbol des Kommandos auf blauem Kreis, rotem Ring oder
///   Gefahrendreieck. So spricht der Schülerschirm durchgehend Schildersprache,
///   auch wo es kein amtliches Zeichen gibt („Links einordnen").
class TrafficSign extends StatelessWidget {
  final CommandDef def;

  /// **Optische Größe** – nicht die Kantenlänge. Die tatsächliche Box ist je
  /// nach Form etwas größer oder kleiner, damit alle Schilder nebeneinander
  /// gleich groß *wirken* (siehe [_optisch]).
  final double size;
  const TrafficSign({super.key, required this.def, required this.size});

  @override
  Widget build(BuildContext context) {
    final h = size * _optisch(def);
    return SizedBox(width: h * _aspect(def), height: h, child: _sign(def, h));
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
      // Vollflächiges Quadrat wirkt am größten und wird zurückgenommen.
      '314' => 0.92,
      // Querformat-Schild: tanzt aus der Reihe, bleibt bei voller Höhe.
      _ => 1,
    };
  }
  return switch (def.sign) {
    // Gezeichnete Tempo-Zeichen sind Kreise wie die Referenz.
    SignShape.limit || SignShape.ende => 1,
    SignShape.none => switch (def.signStyle) {
      SignStyle.gefahr => 1.16,
      SignStyle.richt => 0.92,
      SignStyle.vorschrift || SignStyle.verbot => 1,
    },
  };
}

/// Seitenverhältnis (Breite/Höhe) der Formen, die nicht quadratisch sind.
///
/// Das Gefahrendreieck ist breiter als hoch (1 / 0,866); ohne diese Breite
/// bliebe es bei gleicher Höhe deutlich schmaler als ein Kreis. Der
/// verkehrsberuhigte Bereich ist ein echtes Querformat-Schild – ins Quadrat
/// gezwängt schrumpfte es auf zwei Drittel und wäre nicht mehr zu entziffern.
double _aspect(CommandDef def) {
  if (def.vz == '325-1') return 732 / 489;
  if (def.vz.isEmpty &&
      def.sign == SignShape.none &&
      def.signStyle == SignStyle.gefahr) {
    return 1 / 0.866;
  }
  return 1;
}

Widget _sign(CommandDef def, double s) {
  if (def.vz.isNotEmpty) return _Plate(asset: def.vzAsset);
  return switch (def.sign) {
    SignShape.ende => CustomPaint(
      painter: _EndLimitPainter(),
      size: Size.square(s),
    ),
    // Aufschrift kommt aus dem Katalog, damit ein neues Limit dort mit einer
    // Zeile ergänzt werden kann.
    SignShape.limit => _frame(
      _VerbotPainter(),
      _fitted(s, 0.28, Text(def.signText, style: _limitText)),
    ),
    SignShape.none => _DrawnSign(icon: def.icon, style: def.signStyle, size: s),
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

/// Ein Kommando ohne amtliches Zeichen, gezeichnet als Schild seiner Klasse.
class _DrawnSign extends StatelessWidget {
  final IconData icon;
  final SignStyle style;
  final double size;
  const _DrawnSign({
    required this.icon,
    required this.style,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Symbolgröße und -lage folgen der Form: im Dreieck ist oben kaum Platz,
    // deshalb sitzt das Symbol dort kleiner und tiefer – genau wie auf einem
    // echten Gefahrzeichen.
    final (painter, faktor, versatz, farbe) = switch (style) {
      SignStyle.vorschrift => (_VorschriftPainter(), 0.50, 0.0, Colors.white),
      SignStyle.verbot => (_VerbotPainter(), 0.44, 0.0, _black),
      SignStyle.gefahr => (_GefahrPainter(), 0.40, 0.12, _black),
      SignStyle.richt => (_RichtPainter(), 0.56, 0.0, Colors.white),
    };

    return _frame(
      painter,
      Padding(
        padding: EdgeInsets.only(top: size * versatz * 2),
        child: Icon(icon, size: size * faktor, color: farbe),
      ),
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
//
// Alle Painter rechnen in Anteilen der Kantenlänge und lassen außen [_kBleed]
// für die weiße Absetzung frei.

/// Gebotszeichen: blaue Scheibe mit weißem Rand (VZ 209/211/215).
class _VorschriftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, s / 2, Paint()..color = Colors.white);
    canvas.drawCircle(c, s / 2 * (1 - 2 * _kBleed), Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

/// Gefahrzeichen: weißes Dreieck mit der Spitze nach oben, roter Rand
/// (VZ 101).
///
/// Die drei Flächen werden um den **Inkreismittelpunkt** verkleinert, nicht um
/// die Mitte der Box. Nur so ist der rote Rand an allen drei Seiten gleich
/// breit; zentriert auf die Boxmitte wird er unten breiter als oben, und genau
/// das ließ das Zeichen schief aussehen.
class _GefahrPainter extends CustomPainter {
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  /// Inkreisradius eines gleichseitigen Dreiecks als Anteil der Basis
  /// (1 / (2·√3)). Ein um `x` schmalerer Rand kostet damit `x / _rInkreis`
  /// an Basisbreite.
  static const double _rInkreis = 0.2887;

  /// Gleichseitiges Dreieck mit abgerundeten Ecken, Spitze oben, um seinen
  /// Inkreismittelpunkt [mitte] aufgebaut.
  Path _triangle(Offset mitte, double basis, double eckRadius) {
    final h = basis * 0.866;
    // Der Inkreismittelpunkt liegt ein Drittel der Höhe über der Basis.
    final unten = mitte.dy + h / 3;
    final ecken = [
      Offset(mitte.dx, unten - h),
      Offset(mitte.dx + basis / 2, unten),
      Offset(mitte.dx - basis / 2, unten),
    ];

    final path = Path();
    for (var i = 0; i < 3; i++) {
      final hier = ecken[i];
      final ein = _entlang(hier, ecken[(i + 2) % 3], eckRadius);
      final aus = _entlang(hier, ecken[(i + 1) % 3], eckRadius);
      if (i == 0) {
        path.moveTo(ein.dx, ein.dy);
      } else {
        path.lineTo(ein.dx, ein.dy);
      }
      path.quadraticBezierTo(hier.dx, hier.dy, aus.dx, aus.dy);
    }
    return path..close();
  }

  Offset _entlang(Offset von, Offset zu, double abstand) {
    final d = zu - von;
    return von + d / d.distance * abstand.clamp(0, d.distance / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Die Box ist für das Dreieck breiter als hoch (siehe `_aspect`) – es
    // nutzt beide Maße voll aus, sonst bliebe es neben einem Kreis gleicher
    // Höhe deutlich zu klein.
    final basis = size.width;
    final zentrum = Offset(size.width / 2, size.height * 2 / 3);

    // Randstärke am amtlichen Zeichen abgelesen (VZ 101). Beim Dreieck kostet
    // ein Rand von `w` gleich `w / _rInkreis` an Basisbreite – knapp das
    // Dreieinhalbfache. Schon 0,14 ließ vom weißen Innenfeld zu wenig übrig,
    // um das Symbol groß zu zeigen.
    final saum = size.height * _kBleed;
    final rand = size.height * 0.10;
    final b1 = basis - saum / _rInkreis;
    final b2 = b1 - rand / _rInkreis;

    canvas.drawPath(
      _triangle(zentrum, basis, basis * 0.09),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(_triangle(zentrum, b1, b1 * 0.09), Paint()..color = _red);
    canvas.drawPath(
      _triangle(zentrum, b2, b2 * 0.08),
      Paint()..color = Colors.white,
    );
  }
}

/// Richtzeichen: blaues Quadrat mit weißem Rand (VZ 314).
class _RichtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final aussen = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: s,
      height: s,
    );
    final radius = Radius.circular(s * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(aussen, radius),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(aussen.deflate(s * _kBleed), radius),
      Paint()..color = _blue,
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
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      r * (1 - 2 * _kBleed) * 0.94,
      Paint()
        ..color = _grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.13,
    );

    // Schrägstriche an der Innenkante der Scheibe abschneiden.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.84)),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/command_catalog.dart';

// Amtsnahe Signalfarben.
const _red = Color(0xFFC1121F);
const _blue = Color(0xFF0A4EA2);
const _yellow = Color(0xFFF7C600);
const _black = Color(0xFF111417);

/// Rendert ein **echtes Verkehrszeichen** (korrekte Form/Farbe) für ein
/// Zeichen- oder Gefahren-Kommando. Wird identisch beim Fahrlehrer (Kachel)
/// und beim Fahrschüler (Anzeige) verwendet.
class TrafficSign extends StatelessWidget {
  final CommandDef def;
  final double size;
  const TrafficSign({super.key, required this.def, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: _sign(def, size));
  }
}

Widget _sign(CommandDef def, double s) {
  switch (def.key) {
    case 'z_stop':
      return _frame(
        _OctagonPainter(),
        _fitted(s, 0.20, const Text('STOP', style: _stopText)),
      );
    case 'z_vorfahrt_gewaehren':
      return CustomPaint(painter: _InvTrianglePainter(), size: Size.square(s));
    case 'z_vorfahrtstrasse':
      return CustomPaint(painter: _DiamondPainter(), size: Size.square(s));
    case 'z_tempo30':
      return _frame(
        _RingPainter(),
        _fitted(s, 0.26, const Text('30', style: _limitText)),
      );
    case 'z_ueberholverbot':
      return _frame(
        _RingPainter(),
        _fitted(
          s,
          0.24,
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car, color: _red, size: 100),
              SizedBox(width: 6),
              Icon(Icons.directions_car, color: _black, size: 100),
            ],
          ),
        ),
      );
    case 'z_einbahn':
      return Center(
        child: Container(
          width: s,
          height: s * 0.6,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(s * 0.06),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.arrow_forward, color: Colors.white, size: s * 0.42),
        ),
      );
    default:
      // Gefahrzeichen: rotes Dreieck (Spitze oben) mit schwarzem Piktogramm.
      return Stack(
        alignment: const Alignment(0, 0.36),
        children: [
          CustomPaint(painter: _UpTrianglePainter(), size: Size.square(s)),
          _hazardGlyph(def, s * 0.5),
        ],
      );
  }
}

/// Echtes Gefahren-Piktogramm als Vektor, sonst Material-Icon-Fallback.
Widget _hazardGlyph(CommandDef def, double s) {
  final painter = _hazardPainterFor(def.key);
  if (painter != null) {
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: painter),
    );
  }
  return Icon(def.icon, size: s * 0.82, color: _black);
}

CustomPainter? _hazardPainterFor(String key) => switch (key) {
  'achtung' => _ExclamationPainter(),
  'fussgaenger' => _PedestrianPainter(),
  'radfahrer' => _BicyclePainter(),
  'gegenverkehr' => _OncomingPainter(),
  'kinder' => _ChildrenPainter(),
  'tiere' => _DeerPainter(),
  _ => null, // hindernis, glaette → Material-Icon-Fallback
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

const _stopText = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.w900,
  fontSize: 100,
  letterSpacing: -2,
  height: 1,
);
const _limitText = TextStyle(
  color: _black,
  fontWeight: FontWeight.w900,
  fontSize: 100,
  height: 1,
);

// ---- Formen ----

class _OctagonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final r = s / 2;
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = (math.pi / 8) + i * (math.pi / 4);
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = _red);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

class _InvTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.04, s * 0.14)
      ..lineTo(s * 0.96, s * 0.14)
      ..lineTo(s * 0.5, s * 0.92)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.11
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UpTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.06)
      ..lineTo(s * 0.96, s * 0.88)
      ..lineTo(s * 0.04, s * 0.88)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = _red
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.085
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.5, s * 0.03)
      ..lineTo(s * 0.97, s * 0.5)
      ..lineTo(s * 0.5, s * 0.97)
      ..lineTo(s * 0.03, s * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = _yellow);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.10
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _black
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===== Gefahren-Piktogramme (schwarze Silhouetten) =====

Paint _pFill() => Paint()
  ..color = _black
  ..isAntiAlias = true;

Paint _pStroke(double w) => Paint()
  ..color = _black
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

/// Gefahrstelle (VZ 101): Ausrufezeichen.
class _ExclamationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bar = Path()
      ..moveTo(0.41 * w, 0.06 * w)
      ..lineTo(0.59 * w, 0.06 * w)
      ..lineTo(0.555 * w, 0.62 * w)
      ..lineTo(0.445 * w, 0.62 * w)
      ..close();
    canvas.drawPath(bar, _pFill());
    canvas.drawCircle(Offset(0.5 * w, 0.82 * w), 0.09 * w, _pFill());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fußgänger (VZ 133): gehende Figur.
class _PedestrianPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final limb = _pStroke(0.11 * w);
    canvas.drawCircle(Offset(0.52 * w, 0.15 * w), 0.11 * w, _pFill());
    canvas.drawLine(
      Offset(0.52 * w, 0.28 * w),
      Offset(0.49 * w, 0.56 * w),
      limb,
    );
    canvas.drawLine(
      Offset(0.49 * w, 0.56 * w),
      Offset(0.63 * w, 0.9 * w),
      limb,
    );
    canvas.drawLine(
      Offset(0.49 * w, 0.56 * w),
      Offset(0.40 * w, 0.88 * w),
      limb,
    );
    canvas.drawLine(
      Offset(0.52 * w, 0.35 * w),
      Offset(0.66 * w, 0.46 * w),
      limb,
    );
    canvas.drawLine(
      Offset(0.52 * w, 0.35 * w),
      Offset(0.40 * w, 0.50 * w),
      limb,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Radfahrer (VZ 138): Fahrrad.
class _BicyclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final line = _pStroke(0.045 * w);
    final wheel = _pStroke(0.05 * w);
    final rear = Offset(0.27 * w, 0.66 * w);
    final front = Offset(0.73 * w, 0.66 * w);
    final pedal = Offset(0.50 * w, 0.66 * w);
    final seat = Offset(0.44 * w, 0.40 * w);
    final handle = Offset(0.62 * w, 0.40 * w);
    canvas.drawCircle(rear, 0.18 * w, wheel);
    canvas.drawCircle(front, 0.18 * w, wheel);
    final frame = Path()
      ..moveTo(rear.dx, rear.dy)
      ..lineTo(pedal.dx, pedal.dy)
      ..lineTo(seat.dx, seat.dy)
      ..lineTo(rear.dx, rear.dy)
      ..moveTo(seat.dx, seat.dy)
      ..lineTo(handle.dx, handle.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(pedal.dx, pedal.dy);
    canvas.drawPath(frame, line);
    canvas.drawLine(
      Offset(0.39 * w, 0.37 * w),
      Offset(0.48 * w, 0.37 * w),
      wheel,
    );
    canvas.drawLine(
      Offset(0.60 * w, 0.34 * w),
      Offset(0.68 * w, 0.34 * w),
      wheel,
    );
    canvas.drawLine(
      Offset(0.62 * w, 0.34 * w),
      Offset(0.62 * w, 0.40 * w),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gegenverkehr (VZ 125): Pfeil hoch (schwarz) + Pfeil runter (rot).
class _OncomingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    _arrowUp(canvas, w, 0.35, _black);
    _arrowDown(canvas, w, 0.65, _red);
  }

  void _arrowUp(Canvas c, double w, double cx, Color col) {
    final shaft = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09 * w
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx * w, 0.30 * w), Offset(cx * w, 0.86 * w), shaft);
    final head = Path()
      ..moveTo(cx * w, 0.10 * w)
      ..lineTo((cx - 0.12) * w, 0.34 * w)
      ..lineTo((cx + 0.12) * w, 0.34 * w)
      ..close();
    c.drawPath(head, Paint()..color = col);
  }

  void _arrowDown(Canvas c, double w, double cx, Color col) {
    final shaft = Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.09 * w
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx * w, 0.14 * w), Offset(cx * w, 0.70 * w), shaft);
    final head = Path()
      ..moveTo(cx * w, 0.90 * w)
      ..lineTo((cx - 0.12) * w, 0.66 * w)
      ..lineTo((cx + 0.12) * w, 0.66 * w)
      ..close();
    c.drawPath(head, Paint()..color = col);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Kinder (VZ 136): zwei gehende Kinder (stilisiert, wie der Fußgänger).
class _ChildrenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // hinteres, kleineres Kind zuerst, dann das vordere (größere).
    _walker(canvas, w, cx: 0.36, topY: 0.20, h: 0.56);
    _walker(canvas, w, cx: 0.62, topY: 0.12, h: 0.70);
  }

  void _walker(
    Canvas c,
    double w, {
    required double cx,
    required double topY,
    required double h,
  }) {
    final hgt = h * w;
    final x = cx * w;
    final y = topY * w;
    final limb = _pStroke(0.15 * hgt);
    final headR = 0.13 * hgt;
    final headC = Offset(x, y + headR);
    c.drawCircle(headC, headR, _pFill());
    final hip = Offset(x - 0.02 * hgt, y + 0.60 * hgt);
    c.drawLine(Offset(x, y + 0.26 * hgt), hip, limb); // Rumpf
    c.drawLine(hip, Offset(x + 0.17 * hgt, y + 0.98 * hgt), limb); // Bein vor
    c.drawLine(
      hip,
      Offset(x - 0.15 * hgt, y + 0.96 * hgt),
      limb,
    ); // Bein zurück
    final sh = Offset(x, y + 0.37 * hgt);
    c.drawLine(sh, Offset(x + 0.18 * hgt, y + 0.53 * hgt), limb); // Arm vor
    c.drawLine(sh, Offset(x - 0.16 * hgt, y + 0.57 * hgt), limb); // Arm zurück
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wildwechsel (VZ 142): springendes Reh (stilisiert).
class _DeerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final leg = _pStroke(0.045 * w);

    // Beine mit Knick (springende Haltung), hinter dem Körper.
    void bent(
      double x1,
      double y1,
      double x2,
      double y2,
      double x3,
      double y3,
    ) {
      canvas.drawPath(
        Path()
          ..moveTo(x1 * w, y1 * w)
          ..lineTo(x2 * w, y2 * w)
          ..lineTo(x3 * w, y3 * w),
        leg,
      );
    }

    // Hinterbeine (nach hinten gestreckt), Vorderbeine (nach vorn).
    bent(0.33, 0.52, 0.24, 0.65, 0.29, 0.83);
    bent(0.30, 0.52, 0.19, 0.67, 0.22, 0.85);
    bent(0.55, 0.52, 0.66, 0.65, 0.61, 0.83);
    bent(0.51, 0.53, 0.62, 0.68, 0.56, 0.85);

    // Körper (gefüllt): gestreckt, Rücken leicht gebogen, nach rechts springend.
    final body = Path()
      ..moveTo(0.22 * w, 0.50 * w)
      ..quadraticBezierTo(0.34 * w, 0.37 * w, 0.53 * w, 0.41 * w)
      ..quadraticBezierTo(0.60 * w, 0.43 * w, 0.60 * w, 0.50 * w)
      ..quadraticBezierTo(0.57 * w, 0.55 * w, 0.44 * w, 0.55 * w)
      ..quadraticBezierTo(0.30 * w, 0.56 * w, 0.24 * w, 0.54 * w)
      ..close();
    canvas.drawPath(body, _pFill());

    // Hals + Kopf + Schnauze.
    canvas.drawLine(
      Offset(0.57 * w, 0.46 * w),
      Offset(0.72 * w, 0.29 * w),
      _pStroke(0.08 * w),
    );
    canvas.drawCircle(Offset(0.75 * w, 0.25 * w), 0.05 * w, _pFill());
    canvas.drawLine(
      Offset(0.78 * w, 0.26 * w),
      Offset(0.85 * w, 0.28 * w),
      _pStroke(0.032 * w),
    );

    // Schwanz.
    canvas.drawLine(
      Offset(0.23 * w, 0.49 * w),
      Offset(0.16 * w, 0.43 * w),
      leg,
    );

    // Geweih (zwei Stangen mit Sprossen).
    final ant = _pStroke(0.028 * w);
    canvas.drawLine(
      Offset(0.74 * w, 0.21 * w),
      Offset(0.70 * w, 0.08 * w),
      ant,
    );
    canvas.drawLine(
      Offset(0.72 * w, 0.13 * w),
      Offset(0.64 * w, 0.11 * w),
      ant,
    );
    canvas.drawLine(
      Offset(0.70 * w, 0.08 * w),
      Offset(0.74 * w, 0.04 * w),
      ant,
    );
    canvas.drawLine(
      Offset(0.77 * w, 0.20 * w),
      Offset(0.82 * w, 0.10 * w),
      ant,
    );
    canvas.drawLine(
      Offset(0.80 * w, 0.14 * w),
      Offset(0.86 * w, 0.12 * w),
      ant,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

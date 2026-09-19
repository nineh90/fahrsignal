#!/usr/bin/env python3
"""Erzeugt die eigenen Piktogramme in assets/pictos/ – alle aus denselben
Bausteinen, damit sie wie eine Familie wirken und zur Strichstärke der
Material-Symbole passen (2 von 24 ≈ 8–9 von 100).

    python3 tool/pictos.py            # schreibt alle SVGs
    python3 tool/pictos.py --sheet    # zusätzlich /tmp/fs/pictos.png (Inkscape + ImageMagick)

Regeln (Auskunft TÜV 09/2026, siehe CLAUDE.md „Verkehrszeichen"):
- Ein Piktogramm darf **nicht** wie ein Verkehrszeichen aussehen: keine
  umrandete Scheibe, kein Dreieck mit Rand, keine Schildfläche.
- Einfarbig („white"), die App färbt es über einen ColorFilter ein. Kein `#`
  in der Datei – der Test prüft das.
- Raster 100×100, Inhalt bis an den Rand (die App gleicht die Größe gegen die
  Schilder selbst aus).
"""
import math
import os
import subprocess
import sys

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'pictos')
SW = 11  # Strichstärke – etwas kräftiger als Material (2/24), die Kachel zeigt 42 px

# ---------------------------------------------------------------- Bausteine

def stroke(d, w=SW, extra=''):
    return (f'<path d="{d}" fill="none" stroke="white" stroke-width="{w}" '
            f'stroke-linecap="round" stroke-linejoin="round" {extra}/>')


def fill(d, extra=''):
    return f'<path d="{d}" fill="white" {extra}/>'


def rect(x, y, w, h, r=0):
    return (f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" '
            f'rx="{n(r)}" fill="white"/>')


def circle(cx, cy, r, w=None):
    if w is None:
        return f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="white"/>'
    return (f'<circle cx="{n(cx)}" cy="{n(cy)}" r="{n(r)}" fill="none" stroke="white" '
            f'stroke-width="{n(w)}"/>')


def group(inner, transform):
    return f'<g transform="{transform}">{"".join(inner)}</g>'


def n(v):
    """Zahl für den Pfad: kurz und ohne Rundungsmüll (13.600000000000001)."""
    return f'{v:.2f}'.rstrip('0').rstrip('.')


def rrect_path(x, y, w, h, r):
    """Abgerundetes Rechteck als Pfad (für evenodd-Aussparungen). Der Radius
    wird auf die halbe Kante begrenzt – sonst entstehen negative Kanten und
    im Pfad steht `v--0.24`, was flutter_svg (zu Recht) ablehnt."""
    r = min(r, w / 2, h / 2)
    a, b = n(w - 2 * r), n(h - 2 * r)
    return (f'M{n(x + r)},{n(y)} h{a} a{n(r)},{n(r)} 0 0 1 {n(r)},{n(r)} v{b} '
            f'a{n(r)},{n(r)} 0 0 1 -{n(r)},{n(r)} h-{a} a{n(r)},{n(r)} 0 0 1 -{n(r)},-{n(r)} '
            f'v-{b} a{n(r)},{n(r)} 0 0 1 {n(r)},-{n(r)} z')


def car_top(cx=50, cy=50, w=34, h=62, rot=0):
    """Auto von oben, Front nach oben: Silhouette mit einer ausgesparten
    Windschutzscheibe (mehr Detail verschwimmt auf der Kachel) und Rädern."""
    x, y = cx - w / 2, cy - h / 2
    body = rrect_path(x, y, w, h, w * 0.3)
    ws = rrect_path(x + w * 0.2, y + h * 0.22, w * 0.6, max(h * 0.16, 6), 3)
    wheels = ''.join(
        rect(wx, wy, w * 0.2, h * 0.22, 2)
        for wx in (x - w * 0.1, x + w * 0.9)
        for wy in (y + h * 0.12, y + h * 0.62)
    )
    car = (wheels +
           f'<path d="{body} {ws}" fill="white" fill-rule="evenodd"/>')
    return group([car], f'rotate({rot} {n(cx)} {n(cy)})')


def car_rear(cx=50, cy=50, w=70, h=44, lamps=True, rays=False):
    """Auto von hinten (für Beleuchtung): Karosserie mit Dach, Leuchten als
    Aussparung; `rays` = Leuchten strahlen (Bremslicht)."""
    x, y = cx - w / 2, cy - h / 2
    roof = rrect_path(x + 12, y - 16, w - 24, 22, 7)
    body = rrect_path(x, y, w, h, 8)
    parts = [fill(roof)]
    holes = ''
    if lamps:  # Leuchten als Aussparung (evenodd) – einfarbig bleibt einfarbig
        for lx in (x + 6, x + w - 20):
            holes += ' ' + rrect_path(lx, y + 10, 14, 10, 3)
    parts.append(f'<path d="{body}{holes}" fill="white" fill-rule="evenodd"/>')
    parts.append(rect(x + 8, y + h - 2, 12, 6, 2))
    parts.append(rect(x + w - 20, y + h - 2, 12, 6, 2))
    return ''.join(parts)


def arrow(points, head=11, w=SW):
    """Pfeil entlang einer Punktliste, Spitze am letzten Punkt."""
    d = 'M' + ' L'.join(f'{n(px)},{n(py)}' for px, py in points)
    (x1, y1), (x2, y2) = points[-2], points[-1]
    a = math.atan2(y2 - y1, x2 - x1)
    l = (x2 - head * math.cos(a - 0.6), y2 - head * math.sin(a - 0.6))
    r = (x2 - head * math.cos(a + 0.6), y2 - head * math.sin(a + 0.6))
    hd = f'M{l[0]:.1f},{l[1]:.1f} L{n(x2)},{n(y2)} L{r[0]:.1f},{r[1]:.1f}'
    return stroke(d, w) + stroke(hd, w)


def arc_arrow(cx, cy, r, a0, a1, head=11, w=SW, ccw=False):
    """Kreisbogen-Pfeil von Winkel a0 nach a1 (Grad, 0 = rechts, im Uhrzeigersinn)."""
    def pt(a):
        return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))
    x0, y0 = pt(a0)
    x1, y1 = pt(a1)
    sweep = 0 if ccw else 1
    large = 1 if abs(a1 - a0) > 180 else 0
    d = f'M{x0:.1f},{y0:.1f} A{r},{r} 0 {large} {sweep} {x1:.1f},{y1:.1f}'
    # Tangente am Ende
    t = math.radians(a1) + (math.pi / 2 if not ccw else -math.pi / 2)
    l = (x1 - head * math.cos(t - 0.6), y1 - head * math.sin(t - 0.6))
    rr = (x1 - head * math.cos(t + 0.6), y1 - head * math.sin(t + 0.6))
    hd = f'M{l[0]:.1f},{l[1]:.1f} L{x1:.1f},{y1:.1f} L{rr[0]:.1f},{rr[1]:.1f}'
    return stroke(d, w) + stroke(hd, w)


def head_top(cx=50, cy=52, turn=0, r=16, shoulders=True, nose=True):
    """Kopf von oben, `turn` dreht ihn (Grad, + = rechts); die Blickrichtung
    zeigt eine kurze Nase. `cy` ist die Kopfmitte."""
    sh = rect(cx - 36, cy + r + 4, 72, 18, 9) if shoulders else ''
    head = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="white"/>'
    n = fill(f'M{cx - 9},{cy - r + 6} L{cx},{cy - r - 7} L{cx + 9},{cy - r + 6} z') if nose else ''
    return sh + group([head, n], f'rotate({turn} {cx} {cy})')


def lamp(cx=50, cy=50, flip=False, r=22):
    """Scheinwerfer-Symbol (Cockpit): D-Form, flache Seite (Lichtaustritt)
    rechts. `r` = halbe Höhe."""
    k = r / 22
    d = (f'M{cx - 8 * k},{cy - r} a{r},{r} 0 0 0 0,{2 * r} h{16 * k} '
         f'a3,3 0 0 0 3,-3 v-{2 * r - 6} a3,3 0 0 0 -3,-3 z')
    g = fill(d)
    if flip:
        return group([g], f'scale(-1 1) translate({-2 * cx} 0)')
    return g


def rays(x, cy, n=4, length=26, dy=11, slant=0, w=SW - 1):
    """Strahlen neben einer Lampe: n Striche, `slant` versetzt das rechte Ende."""
    out = []
    for i in range(n):
        y = cy - dy * (n - 1) / 2 + i * dy
        out.append(stroke(f'M{x},{y} L{x + length},{y + slant}', w))
    return ''.join(out)


def road_lanes(dashed=True):
    """Zwei Fahrstreifen: Außenlinien durchgezogen, Mitte gestrichelt."""
    parts = [stroke('M10,2 V98', 9), stroke('M90,2 V98', 9)]
    if dashed:
        parts.append(stroke('M50,2 V98', 8, 'stroke-dasharray="12 12"'))
    return ''.join(parts)


def svg(*parts):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            + ''.join(parts) + '</svg>\n')


# ---------------------------------------------------------------- Bilder

P = {}

# --- Richtung -----------------------------------------------------------
# Einordnen: Fahrstreifen, Auto wechselt mit Pfeil hinüber.
P['einordnen_links'] = svg(
    road_lanes(), car_top(70, 70, 26, 46),
    arrow([(70, 40), (70, 18), (32, 18)], 13))
P['einordnen_rechts'] = svg(
    road_lanes(), car_top(30, 70, 26, 46),
    arrow([(30, 40), (30, 18), (68, 18)], 13))
# Ohne Richtung: zwei Spuren laufen in eine zusammen.
P['einordnen'] = svg(
    stroke('M20,96 C20,58 50,66 50,40'),
    stroke('M80,96 C80,58 50,66 50,40'),
    arrow([(50, 44), (50, 6)], 13))
# Straße: „die nächste Straße" – Querstraße geht ab, Pfeil biegt ein.
P['strasse'] = svg(
    stroke('M18,98 V2', 9), stroke('M50,98 V2', 9),
    stroke('M50,36 H98', 9), stroke('M50,72 H98', 9),
    arrow([(34, 94), (34, 54), (84, 54)], 13))
# Straße folgen: geschwungener Verlauf mit Pfeil.
P['folgen'] = svg(
    stroke('M50,96 C50,66 18,74 18,50 C18,26 82,42 82,18', 12),
    stroke('M66,32 L82,14 L98,32', 12))
# Rückwärts: Auto von oben, Pfeil nach hinten.
P['rueckwaerts'] = svg(
    car_top(34, 46, 36, 64), arrow([(78, 20), (78, 92)], 14, 12))

# Kreisverkehr-Ausfahrten: Ring mit drei Abgängen, der genannte ist der Pfeil.
def ausfahrt(n):
    cx, cy, r = 50, 54, 22
    parts = [circle(cx, cy, r, 11)]
    # Einfahrt von unten
    parts.append(stroke(f'M{cx},{cy + r} V98', 11))
    exits = {1: (cx + r, cy, 'M{},{} H98'), 2: (cx, cy - r, 'M{},{} V2'),
             3: (cx - r, cy, 'M{},{} H2')}
    for k, (ex, ey, d) in exits.items():
        if k != n:
            parts.append(stroke(d.format(ex, ey), 9, 'opacity="0.5"'))
    if n == 1:
        parts.append(arrow([(cx + r, cy), (96, cy)], 13, 12))
    elif n == 2:
        parts.append(arrow([(cx, cy - r), (cx, 6)], 13, 12))
    else:
        parts.append(arrow([(cx - r, cy), (4, cy)], 13, 12))
    return svg(*parts)

P['ausfahrt1'] = ausfahrt(1)
P['ausfahrt2'] = ausfahrt(2)
P['ausfahrt3'] = ausfahrt(3)

# --- Tempo --------------------------------------------------------------
def tacho(needle_deg, sign):
    """Tachobogen mit Nadel; darunter + oder − ."""
    parts = [stroke('M10,52 A40,40 0 0 1 90,52')]
    a = math.radians(needle_deg)
    parts.append(stroke(f'M50,52 L{50 + 28 * math.cos(a):.1f},{52 - 28 * math.sin(a):.1f}'))
    parts.append(circle(50, 52, 8))
    if sign == '-':
        parts.append(stroke('M32,84 H68', 12))
    else:
        parts.append(stroke('M32,84 H68', 12) + stroke('M50,66 V100', 12))
    return svg(*parts)

P['langsamer'] = tacho(150, '-')
P['schneller'] = tacho(30, '+')
# Bremsen: das Cockpit-Symbol „(!)" – kein Kreis mit Rand, sondern zwei Bögen.
P['bremsen'] = svg(
    stroke('M26,16 A42,42 0 0 0 26,84'), stroke('M74,16 A42,42 0 0 1 74,84'),
    stroke('M50,22 V56', 14), circle(50, 76, 8))

# --- Hinweise -----------------------------------------------------------
# Spiegel: Innenspiegel am Stiel, darin ein Auge.
P['spiegel'] = svg(
    stroke('M50,4 V22', 10),
    stroke(rrect_path(8, 22, 84, 44, 10), 9),
    stroke('M24,44 Q50,22 76,44 Q50,66 24,44 z', 7),
    circle(50, 44, 8),
    stroke('M18,88 H82', 10, 'opacity="0.5"'))
# Blinker: die zwei Cockpit-Pfeile.
P['blinker'] = svg(
    fill('M4,50 L32,24 V38 H46 V62 H32 V76 z'),
    fill('M96,50 L68,24 V38 H54 V62 H68 V76 z'))
# Schulterblick: Kopf von oben, gedreht, Blickpfeil über die Schulter nach hinten.
# Schulterblick: Kopf über die rechte Schulter gedreht, Blickpfeil von vorn
# nach hinten um die Schulter herum.
P['schulterblick'] = svg(
    head_top(40, 42, 135, 17),
    arc_arrow(44, 48, 46, -80, 112, 13, 10))
P['rundumblick'] = svg(
    head_top(50, 48, 0, 15, nose=False),
    arc_arrow(50, 48, 44, -65, 245, 13, 10))
# Nach hinten schauen: Kopf ganz umgedreht, Blick nach unten (= hinten).
P['nach_hinten'] = svg(
    head_top(50, 26, 180, 16),
    arrow([(50, 66), (50, 96)], 13, 12))
# Abstand: zwei Autos hintereinander, Doppelpfeil dazwischen.
P['abstand'] = svg(
    car_top(50, 16, 34, 36), car_top(50, 84, 34, 36),
    arrow([(50, 50), (50, 36)], 10, 9), arrow([(50, 50), (50, 64)], 10, 9))
# Gang wechseln: H-Schaltschema mit Knauf, Pfeil zum nächsten Gang.
P['gang'] = svg(
    stroke('M20,14 V86 M50,14 V86 M80,14 V86 M20,50 H80', 10),
    circle(50, 14, 13))

# --- Grundfahraufgaben --------------------------------------------------
P['gfa_laengs'] = svg(  # Bordstein rechts, geparktes Auto, Lücke – rückwärts hinein
    stroke('M94,2 V98', 9),
    car_top(70, 18, 30, 38),
    car_top(28, 44, 30, 44, -22),
    arrow([(38, 70), (58, 80), (70, 82)], 12, 10))
P['gfa_quer_vor'] = svg(  # Parkbuchten oben, Auto fährt vorwärts hinein
    stroke('M12,2 V44 M37,2 V44 M63,2 V44 M88,2 V44', 8),
    car_top(50, 78, 28, 40), arrow([(50, 52), (50, 12)], 13, 12))
P['gfa_quer_rueck'] = svg(
    stroke('M12,2 V44 M37,2 V44 M63,2 V44 M88,2 V44', 8),
    car_top(50, 78, 28, 40, 180), arrow([(50, 52), (50, 12)], 13, 12))
P['gfa_bremsung'] = svg(  # Auto mit Bremsspuren, ruckartig vor der Linie
    stroke('M8,8 H92', 11),
    car_top(50, 48, 34, 54),
    stroke('M38,82 V97 M62,82 V97', 9, 'stroke-dasharray="4 7"'))
P['gfa_ecke'] = svg(  # Rückwärts nach rechts um die Ecke: Bordsteinecke + Pfeil
    stroke('M6,60 H60 V4', 10),
    car_top(28, 82, 26, 36, 90),
    arrow([(50, 82), (74, 82), (80, 74), (80, 18)], 12, 11))

# --- Abfahrtkontrolle ---------------------------------------------------
def pedal(cx=50, cy=50):
    """Pedal von der Seite: schräge Trittplatte, Pedalarm hinunter zum Boden."""
    plate = group([rect(cx - 36, cy - 26, 56, 13, 5)], f'rotate(-22 {cx - 8} {cy - 20})')
    arm = stroke(f'M{cx + 12},{cy - 14} L{cx + 20},{cy + 36}', 12)
    floor = stroke(f'M{cx - 36},{cy + 42} H{cx + 42}', 11)
    return plate + arm + floor

P['bremse'] = svg(pedal(48, 50))
# Hupe: Trompete/Horn (Cockpit-Symbol).
P['hupe'] = svg(
    fill('M6,36 h30 l28,-22 v72 l-28,-22 h-30 z'),
    stroke('M74,34 a18,18 0 0 1 0,32', 9), stroke('M84,22 a30,30 0 0 1 0,56', 9))
# Scheibenwischer: Frontscheibe mit Wischerarm und Wischfeld.
P['scheibenwischer'] = svg(
    stroke('M8,84 L20,18 H80 L92,84 z', 9),
    stroke('M50,84 L74,38', 10),
    stroke('M26,58 A38,38 0 0 1 74,38', 9, 'stroke-dasharray="7 8"'))
# Warnweste: Weste mit zwei Reflexstreifen (ausgespart).
P['warnweste'] = svg(
    f'<path d="M30,6 L50,22 L70,6 L92,20 L82,44 L76,40 V96 H24 V40 L18,44 L8,20 z '
    f'M24,58 H76 V66 H24 z M24,76 H76 V84 H24 z" fill="white" fill-rule="evenodd"/>')

# --- Beleuchtung (Cockpit-Symbole nach ISO 2575) -----------------------
P['abblendlicht'] = svg(lamp(34, 50), rays(58, 50, 4, 30, 12, 8))
P['fernlicht'] = svg(lamp(34, 50), rays(58, 50, 5, 32, 11, 0))
# Standlicht: zwei Lampen Rücken an Rücken, Strahlen nach außen.
P['standlicht'] = svg(
    lamp(38, 50, flip=True, r=16), lamp(62, 50, r=16),
    rays(4, 50, 3, 14, 12, 0, 8), rays(82, 50, 3, 14, 12, 0, 8))
# Warnblinker: das doppelte Dreieck der Warnblinktaste – umrandet, ohne Fläche.
P['warnblinker'] = svg(
    stroke('M50,10 L92,84 H8 z', 10), stroke('M50,36 L68,68 H32 z', 8))
P['bremslicht'] = svg(car_rear(50, 60, 60, 40),
                      rays(2, 48, 3, 14, 11, 0, 8), rays(84, 48, 3, 14, 11, 0, 8))
P['ruecklicht'] = svg(car_rear(50, 58))
# Nebelscheinwerfer: Lampe, Strahlen durch eine Wellenlinie unterbrochen.
P['nebel'] = svg(
    lamp(34, 50), rays(58, 50, 4, 30, 12, 0, 8),
    stroke('M74,20 C64,32 84,44 74,56 C64,68 84,80 74,86', 8))

# --- Reifen -------------------------------------------------------------
# Profiltiefe: Lauffläche von vorn, Rillen ausgespart.
P['profil'] = svg(
    f'<path d="{rrect_path(26, 4, 48, 92, 12)} '
    f'M34,24 H66 V32 H34 z M34,46 H66 V54 H34 z M34,68 H66 V76 H34 z" '
    f'fill="white" fill-rule="evenodd"/>')
# Reifenzustand: Reifen von der Seite mit Haken – „anschauen, in Ordnung?"
P['reifenzustand'] = svg(
    circle(50, 50, 38, 18),
    stroke('M36,52 L46,62 L66,40', 10))
P['felgen'] = svg(  # Felge: Ring mit fünf Speichen
    circle(50, 50, 40, 10),
    *[stroke(f'M50,50 L{50 + 36 * math.cos(math.radians(a)):.1f},{50 + 36 * math.sin(math.radians(a)):.1f}', 9)
      for a in range(-90, 270, 72)],
    circle(50, 50, 10))

# --- Flüssigkeiten ------------------------------------------------------
# Motoröl: Ölkanne (Cockpit-Symbol).
P['motoroel'] = svg(
    fill('M22,44 H60 L74,30 L84,38 L66,56 V72 a8,8 0 0 1 -8,8 H22 a8,8 0 0 1 -8,-8 V52 a8,8 0 0 1 8,-8 z'),
    stroke('M36,44 V32 H50', 9), circle(90, 74, 6))
# Kühlwasser: Thermometer über Wellen.
P['kuehlwasser'] = svg(
    stroke('M50,10 V56', 14), circle(50, 62, 12),
    stroke('M8,84 C20,72 30,96 42,84 C54,72 64,96 76,84 C84,76 90,82 94,86', 9))
# Bremsflüssigkeit: Tropfen zwischen den Bremsbögen.
P['bremsfluessigkeit'] = svg(
    stroke('M24,16 A42,42 0 0 0 24,84'), stroke('M76,16 A42,42 0 0 1 76,84'),
    fill('M50,22 C62,42 68,50 68,60 a18,18 0 0 1 -36,0 C32,50 38,42 50,22 z'))
# Scheibenwaschwasser: Frontscheibe, Wasserstrahl von unten.
P['wischwasser'] = svg(
    stroke('M8,84 L20,18 H80 L92,84 z', 9),
    stroke('M50,84 V64', 10),
    stroke('M50,64 C46,50 40,44 32,40 M50,64 C54,50 60,44 68,40 M50,64 V38', 8))

# --- Assistenzsysteme ---------------------------------------------------
def skid(x, y0=64, h=32):
    return stroke(f'M{x},{y0} C{x - 6},{y0 + h / 3} {x + 6},{y0 + 2 * h / 3} {x},{y0 + h}', 9)

P['abs'] = svg(car_top(50, 36, 34, 56), skid(38), skid(62))  # Auto, Räder rutschen nicht weg? Spuren = ABS
P['esp'] = svg(car_top(50, 36, 34, 56, -18), skid(34, 66, 30), skid(62, 66, 30))
# Spurhalte: Auto zwischen zwei Spurlinien, Pfeile zurück in die Mitte.
P['spurhalte'] = svg(
    stroke('M10,2 V98', 9), stroke('M90,2 V98', 9),
    car_top(50, 56, 30, 54),
    stroke('M18,22 L30,22 M82,22 L70,22', 9))
# Notbremsassistent: Auto, davor ein Hindernis-Balken, Bremsbögen dazwischen.
P['notbrems'] = svg(
    stroke('M14,8 H86', 11), car_top(50, 66, 34, 56),
    stroke('M30,30 A26,26 0 0 1 70,30', 9), stroke('M38,22 A18,18 0 0 1 62,22', 9, 'opacity="0.5"'))
# Abstandstempomat: Auto folgt Auto, Radarbögen davor.
P['acc'] = svg(
    car_top(50, 14, 30, 30), car_top(50, 82, 30, 30),
    stroke('M30,52 A26,26 0 0 1 70,52', 9), stroke('M38,42 A18,18 0 0 1 62,42', 9, 'opacity="0.5"'))
# Totwinkel: Auto, schraffierter Kegel schräg hinten.
P['totwinkel'] = svg(
    car_top(34, 48, 32, 60),
    fill('M52,62 L98,44 L98,98 z', 'opacity="0.5"'),
    stroke('M82,64 V80', 10), circle(82, 92, 6))
# Parkassistent: Auto rückwärts, Sensorbögen am Heck.
P['parkassistent'] = svg(
    car_top(50, 36, 34, 56),
    stroke('M30,72 A26,26 0 0 0 70,72', 9), stroke('M38,82 A18,18 0 0 0 62,82', 9, 'opacity="0.5"'))

# --- Fahrzeugeinweisung -------------------------------------------------
P['innenspiegel'] = svg(stroke('M50,10 V28', 10), stroke(rrect_path(6, 28, 88, 44, 10), 9))
def aussenspiegel(flip):
    body = stroke('M6,26 V90', 12)  # Fahrzeugkante
    arm = stroke('M12,50 H30', 10)
    mirror = fill(rrect_path(30, 32, 44, 36, 10))
    g = body + arm + mirror
    return svg(group([g], 'scale(-1 1) translate(-100 0)') if flip else g)
P['aussenspiegel_l'] = aussenspiegel(True)
P['aussenspiegel_r'] = aussenspiegel(False)
P['lenkrad'] = svg(
    circle(50, 50, 40, 12), circle(50, 50, 11),
    stroke('M14,50 H38 M62,50 H86 M50,62 V86', 10))
# Gurt: Person mit Diagonalgurt (Cockpit-Symbol). Der Gurt ist aus dem Körper
# ausgespart (evenodd) – einfarbig geht es nicht anders.
P['gurt'] = svg(
    circle(50, 20, 14),
    # Der Gurtstreifen endet genau auf der Körperkante – außerhalb würde
    # evenodd ihn wieder füllen.
    f'<path d="M22,50 a28,28 0 0 1 56,0 V94 H22 z '
    f'M22,38 L22,52 L64,94 L78,94 z" fill="white" fill-rule="evenodd"/>')
P['kupplung'] = svg(pedal(48, 50))  # Pedal wie Bremse – die Kachel sagt, welches
P['handbremse'] = svg(  # Handbremshebel: Griff schräg nach oben, Knopf, Sockel
    stroke('M22,78 L70,30', 14), circle(74, 26, 10),
    stroke('M8,86 H60', 10))
P['schaltung'] = svg(  # Schalthebel mit Knauf über Schaltschema
    circle(50, 18, 14), stroke('M50,32 V70', 12),
    stroke('M18,70 H82 M18,62 V78 M50,62 V78 M82,62 V78', 9))

# ---------------------------------------------------------------- Schreiben

def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):  # verwaiste Dateien räumen
        if old.endswith('.svg') and old[:-4] not in P:
            os.remove(os.path.join(OUT, old))
    for name, body in P.items():
        assert '#' not in body, name
        with open(os.path.join(OUT, f'{name}.svg'), 'w') as f:
            f.write(body)
    print(f'{len(P)} Piktogramme → {OUT}')
    if '--sheet' in sys.argv:
        os.makedirs('/tmp/fs/p', exist_ok=True)
        pngs = []
        for name in P:
            png = f'/tmp/fs/p/{name}.png'
            subprocess.run(['inkscape', '-w', '160', os.path.join(OUT, f'{name}.svg'),
                            '-o', png], check=True, capture_output=True)
            pngs.append(png)
        subprocess.run(['magick', 'montage', '-background', '#1E88E5', '-geometry',
                        '160x160+14+14', '-tile', '6x', '-label', '%t', '-fill',
                        'white', '-pointsize', '16', *pngs, '/tmp/fs/pictos.png'],
                       check=True)
        print('→ /tmp/fs/pictos.png')


if __name__ == '__main__':
    main()

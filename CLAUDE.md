# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Was ist das

FahrSignal ist eine **Flutter-App** (iOS + Android), mit der eine Fahrlehrperson kurze visuelle
**Fahranweisungen** an das Gerät einer gehörlosen Fahrschülerin / eines Fahrschülers im selben
Auto sendet. Der Empfängerbildschirm zeigt das Kommando groß und **nach Dringlichkeit farbcodiert**
(info=blau, achtung=gelb, dringend=rot) und hat **keine bedienbaren Elemente**. Sicherheitsnah,
aber kein zertifiziertes System.

> **Greenfield.** Dieses Repo startet leer und ist (noch) **kein git-Repo** → vor dem ersten
> Commit `git init`. Befolge „Projekt von null aufsetzen", dann läuft die App lokal am Rechner
> (ohne Handy/Mac) über den `FakeTransport`. **Maßgeblicher Architektur- & Verbindungsplan:
> `PLAN.md`** (getroffene Entscheidungen, BLE-Rollen, Roadmap-Phasen) – bei tiefergehenden
> Fragen dort die Quelle der Wahrheit.

## Voraussetzungen (einmalig)

- **Flutter SDK** installieren (https://docs.flutter.dev/get-started/install/linux) und `flutter doctor` grün für „Linux desktop" + „Web".
- **Linux-Desktop-Build-Abhängigkeiten** (nötig für `flutter run -d linux`), einmalig:
  ```sh
  # Fedora/Nobara:
  sudo dnf install clang cmake ninja-build gtk3-devel mesa-libGLU-devel pkgconf-pkg-config
  # Debian/Ubuntu:
  sudo apt install clang cmake ninja-build libgtk-3-dev pkg-config
  ```
- Desktop-/Web-Ziele aktivieren:
  ```sh
  flutter config --enable-linux-desktop --enable-web
  ```
- Android SDK für echte Android-Gerätetests (optional, für lokale Logik nicht nötig).
- **Kein Mac vorhanden** → iOS wird **nicht lokal** gebaut, sondern über Cloud-CI (siehe unten).

## Projekt von null aufsetzen (im leeren Ordner)

```sh
flutter create --org de.fahrsignal --project-name fahrsignal \
  --platforms=android,ios,linux,web .
flutter pub add flutter_riverpod
flutter run -d linux        # oder: flutter run -d chrome
```

Danach die Startdateien unter „Minimales lauffähiges Skelett" anlegen und `lib/main.dart` durch
den Dev-Harness ersetzen → die App zeigt sofort Sender- und Empfängeransicht nebeneinander.

Weitere Pakete kommen erst, wenn die jeweilige Schicht dran ist:
`flutter pub add bluetooth_low_energy wakelock_plus vibration web_socket_channel` (BLE/Cloud-Phase).

## Commands

```sh
flutter run -d linux            # schnellstes lokales Dev-Ziel (Desktop, ohne Gerät/Mac)
flutter run -d chrome           # alternativ im Browser
flutter run -d <android-id>     # echtes Android-Gerät (flutter devices)
flutter test                    # Unit-/Widget-Tests (laufen gegen FakeTransport)
flutter test test/foo_test.dart # einzelner Test
flutter analyze                 # Analyzer/Linter
dart format .                   # Formatierung
```

## Architektur (das große Bild)

Der Kern ist eine **Transport-Abstraktion** – die UI kennt nur `SignalTransport` und weiß nicht,
ob dahinter BLE, Cloud oder ein Fake steckt. **Diese Trennung muss erhalten bleiben**: neue
synchronisierte Daten immer über den Transport führen, nie direkt gegen BLE/Cloud in der UI.

- `SignalTransport` (Interface): `sendCommand`, `Stream<DriveCommand> commands`,
  `Stream<TransportState> connection`, `dispose`.
- **`FakeTransport`** – Loopback für Entwicklung/Test, koppelt Sender + Empfänger lokal (siehe unten).
- **`BleTransport`** – lokaler Standardweg der echten App: **offline & iOS↔Android** über Bluetooth
  Low Energy (GATT). Empfänger = Peripheral, Sender = Central. Größtes Risiko: Peripheral-Rolle
  auf iOS → per Spike auf echten Geräten verifizieren, bevor darauf aufgebaut wird.
- **`CloudTransport`** – Fallback über managed Realtime (EU-Region, DSGVO); lokal testbar über
  Firebase Emulator / Supabase local.
- **`HybridTransport`** – wählt BLE, fällt automatisch auf Cloud zurück, meldet aktiven Kanal an UI.

Transport wird per **Riverpod-Provider** injiziert. In Dev/Test hängt der Provider `FakeTransport`
ein → keine Hardware nötig. Rollen: `sender` (Fahrlehrer) / `receiver` (Fahrschüler). Kopplung
über 6-stelligen **Raumcode**.

### Nachrichtenmodell
`DriveCommand { v, key, urgency: info|achtung|dringend, ts }` – identisch über alle Transports.
`urgency` steuert **Farbe und Vibrationsmuster**. Sonderkommando `off` blendet die Empfänger-
Anzeige aus. Verlauf („letzte Hinweise") nur lokal auf dem Empfänger.

### Prüfungsmodus

Rückmeldung aus der Praxis (13.08.2026): **In der praktischen Prüfung darf nur beauftragt,
nicht geholfen werden.** Ein „Schulterblick!" zur richtigen Sekunde nimmt dem Prüfling genau
die Leistung ab, die geprüft wird. Der Sender hat deshalb einen Schalter im Header
(`examModeProvider`), der jede Hilfestellung **aus dem Bild** nimmt – nicht ausgraut, damit
niemand danach greift – und ein rotes Band einblendet.

Die Grenze steht in `command_catalog.dart`, nicht in der UI:

| Konstante | Wirkung |
|---|---|
| `kExamHiddenCategories` | ganze Kategorien: Hinweise, Lob & Kritik, Coaching |
| `kExamHiddenKeys` | Einzelnes in erlaubten Kategorien: langsamer/schneller, alle Tempovorgaben |
| `kExamSafetyKeys` | **überstimmt alles**: Bremsen, Anhalten, Stop |

Bewusst ganze Kategorien statt Einzelkeys: eine neue „Hinweis"-Kachel ist per Definition
wieder eine Hilfestellung und soll ohne Codeänderung mitgesperrt sein.

Was daran nicht verhandelbar ist:

- **Die Notkommandos bleiben.** Die Fahrlehrperson trägt auch während der Prüfung die
  Verantwortung im Auto. Deshalb steht „Hinweise" im Prüfungsmodus weiter da – mit genau
  zwei Kacheln (Anhalten, Stop).
- **Die Sprachleiste hat dieselbe Sperre.** Sie erreicht den Katalog an den Kacheln vorbei;
  ohne `commandAllowedInExam` in `_send` wäre der Modus reine Kosmetik. Gemischte Sätze
  („links und Schulterblick") gehen **ganz** nicht raus, statt still beschnitten zu werden –
  außer ein Notkommando steckt drin, dann zählt Sicherheit mehr als Prüfungsreinheit.
- **Erklärungen sind Hilfe**: im Fahrzeug-Bereich verschwindet der Erklären/Abfragen-Umschalter
  und steht fest auf „Abfragen".
- **Freitext bleibt offen.** Der Prüfer formuliert dort selbst; das ist eine Anweisung in
  eigenen Worten, keine Katalog-Hilfe.

Der Modus ist reiner Senderzustand – der Empfänger zeigt ohnehin nur, was ankommt.
`test/exam_mode_test.dart` hält die Grenze fest.

### Empfohlene Struktur
```
lib/
  main.dart              # Prod-Entry (Startscreen: Raumcode + Rolle)
  dev_harness.dart       # Dev-Entry: Split-Screen Sender+Empfänger über FakeTransport
  domain/                # DriveCommand, Urgency, Kommando-Katalog + Farben
  transport/             # signal_transport.dart, fake_transport.dart, ble_/cloud_/hybrid_
  ui/                    # sender_grid.dart, receiver_view.dart, start_screen.dart
  platform/              # wakelock, vibration
```

## Lokal entwickeln & direkt testen (ohne zwei Handys, ohne Mac)

**Regel:** Die Entwicklung darf nicht von BLE-Hardware abhängen – BLE ist im Emulator nicht testbar.
`FakeTransport` deckt UI, Logik, Urgency-Farben, Watchdog und Verlauf vollständig ab.

- **Schnellster Loop – Split-Screen (empfohlen):** `flutter run -d linux` mit `dev_harness.dart`
  als Entry (`flutter run -d linux -t lib/dev_harness.dart`). Ein Fenster zeigt Sender **und**
  Empfänger; ein Tipp im Sender-Grid erscheint sofort in der Empfängeransicht.
- **Zwei getrennte Fenster / zweites Gerät im LAN:** optionaler kleiner WebSocket-Relay
  (`web_socket_channel` + ein 30-Zeilen-Dart-Server), der Nachrichten je Raumcode weiterreicht –
  analog zum `BroadcastChannel` der ursprünglichen Web-Demo.
- **Cloud-Transport lokal:** gegen **Firebase Emulator Suite** / **Supabase local (Docker)** testen.
- `flutter test` läuft deterministisch gegen `FakeTransport` – kein Netz, keine Hardware.
- `BleTransport` **zuletzt und nur auf zwei echten Geräten** verifizieren.

### Minimales lauffähiges Skelett
`lib/transport/signal_transport.dart`
```dart
enum Role { sender, receiver }
enum Urgency { info, achtung, dringend }

class DriveCommand {
  final String key; final Urgency urgency; final int ts;
  const DriveCommand(this.key, this.urgency, this.ts);
}

abstract class SignalTransport {
  Stream<DriveCommand> get commands;
  Future<void> sendCommand(DriveCommand cmd);
  void dispose();
}
```

`lib/transport/fake_transport.dart` – In-Process-Loopback (koppelt alle Instanzen desselben Raums):
```dart
import 'dart:async';
import 'signal_transport.dart';

class _Hub { // ein Broadcast-Bus pro Raumcode
  static final _rooms = <String, StreamController<DriveCommand>>{};
  static StreamController<DriveCommand> of(String room) =>
      _rooms.putIfAbsent(room, () => StreamController<DriveCommand>.broadcast());
}

class FakeTransport implements SignalTransport {
  final String room;
  FakeTransport(this.room);
  @override
  Stream<DriveCommand> get commands => _Hub.of(room).stream;
  @override
  Future<void> sendCommand(DriveCommand cmd) async => _Hub.of(room).add(cmd);
  @override
  void dispose() {}
}
```

`lib/dev_harness.dart` – Split-Screen zum sofortigen lokalen Testen:
```dart
import 'package:flutter/material.dart';
import 'transport/fake_transport.dart';
import 'transport/signal_transport.dart';

void main() => runApp(const MaterialApp(home: DevHarness()));

class DevHarness extends StatelessWidget {
  const DevHarness({super.key});
  @override
  Widget build(BuildContext context) {
    final t = FakeTransport('DEV'); // beide Seiten teilen sich den Raum "DEV"
    return Scaffold(
      body: Row(children: [
        Expanded(child: _Sender(t)),
        const VerticalDivider(width: 1),
        Expanded(child: _Receiver(t)),
      ]),
    );
  }
}

class _Sender extends StatelessWidget {
  final SignalTransport t; const _Sender(this.t);
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(
      onPressed: () => t.sendCommand(
        DriveCommand('links', Urgency.info, DateTime.now().millisecondsSinceEpoch)),
      child: const Text('LINKS senden'),
    ));
}

class _Receiver extends StatelessWidget {
  final SignalTransport t; const _Receiver(this.t);
  @override
  Widget build(BuildContext context) => StreamBuilder<DriveCommand>(
    stream: t.commands,
    builder: (_, snap) => Container(
      color: snap.hasData ? Colors.blue : Colors.black,
      child: Center(child: Text(snap.data?.key.toUpperCase() ?? 'BEREIT',
        style: const TextStyle(color: Colors.white, fontSize: 48))),
    ));
}
```
Start: `flutter run -d linux -t lib/dev_harness.dart` → links „LINKS senden" tippen, rechts
erscheint sofort das Kommando. Von hier aus die echten `ui/`-Widgets, Urgency-Farben und den
`HybridTransport` ausbauen.

## Verkehrszeichen

Rückmeldung aus der Fahrschule (13.08.2026): **echte Straßenschilder statt Piktogrammen.**
Wo ein Kommando einem amtlichen Zeichen entspricht, zeigen Sender-Kachel und
Empfängerschirm dieses Zeichen – dieselbe Bildsprache, die am Straßenrand steht, ist
ohne Sprache am schnellsten zu erfassen.

Die Dateien in `assets/signs/` sind die amtlichen Zeichen von Wikimedia Commons;
StVO-Zeichen sind als amtliche Werke (§ 5 UrhG) gemeinfrei, die konkreten SVGs stehen
dort als *Public domain*. Aus jeder Datei sind `<metadata>`, `<defs/>` und
`sodipodi:namedview` entfernt – sonst schreibt `flutter_svg` bei jedem Aufbau
„unhandled element" ins Log. Zusammen wiegen alle neun ~34 kB.

| Kommando | Zeichen |
|---|---|
| Links / Rechts | VZ 211-10 / 211-20 („hier links/rechts") |
| Geradeaus | VZ 209-30 |
| Abbiegen links / rechts | VZ 209-10 / 209-20 – der abknickende Pfeil ist genau „abbiegen" |
| Kreisverkehr | VZ 215 |
| Ampel | VZ 131 |
| Vorfahrt gewähren | VZ 205 |
| Vorfahrtstraße | VZ 306 |
| Halten | VZ 314 (Parken) |
| Stop | VZ 206 – das rote Achteck ist die kürzeste Halt-Botschaft |
| Schritttempo | VZ 325.1 – das Spielstraßen-Schild *ist* die Anweisung; eine Zahl 4–7 im Verbotszeichen steht so an keiner Straße |
| Tempo 30/50/70/100 | VZ 274, **gezeichnet** (`SignShape.limit`) |
| Unbegrenzt | VZ 282, gezeichnet (`SignShape.ende`) |

Die Zuordnung steht als Nummer am Katalogeintrag (`vz: '209-10'` → `assets/signs/vz209-10.svg`),
nicht in der UI. `test/traffic_sign_test.dart` hält Zuordnung und Dateien zusammen: ein
Tippfehler in der Nummer fiele sonst erst im Auto auf, wenn die Kachel leer bleibt.

Warum die Tempo-Zeichen weiter gezeichnet werden: ihre Aufschrift kommt aus dem Katalog
(`signText`), ein neues Limit ist damit eine Zeile statt einer Datei.

**Jedes Zeichen braucht eine Absetzung vom Grund** – VZ 209 (blauer Kreis) auf der
blauen Richtungs-Kachel und erst recht auf dem blauen Empfängerschirm verschwände sonst
ineinander. Die amtlichen Zeichen sind dafür gemacht, gegen Himmel und Landschaft zu
stehen, nicht gegen eine Fläche ihrer eigenen Farbe; am Straßenrand übernimmt das der
weiße Rand des Schildblechs.

`_Plate` legt dafür **dasselbe SVG ein zweites Mal, 8 % größer und vollflächig weiß**
darunter (`ColorFilter` + `BlendMode.srcIn`). Der Saum folgt damit jeder Form von selbst
– Kreis, Dreieck, Raute, Achteck, Querformat – und braucht keine Liste, welches Zeichen
welche Form hat. Der Vorgänger, eine weiße Platte hinter dem Zeichen, sah bei runden
Zeichen nach aufgeklebtem Sticker aus und bei Dreieck und Raute nach weißem Kasten;
genau das war die Rückmeldung aus der Fahrschule.

Nicht jedes Zeichen ist quadratisch: VZ 325.1 ist ein Querformat-Schild. `_aspect` gibt
das Seitenverhältnis, `size` ist deshalb die **Höhe** – ins Quadrat gezwängt schrumpfte
das Schild auf zwei Drittel und wäre auf der Kachel nicht mehr zu entziffern.

Beim Empfänger wächst das Zeichen mit der Gerätebreite (halbe kurze Kante, 150–260 px):
es trägt mehr Details als ein Piktogramm und muss aus dem Augenwinkel lesbar sein.

Ein neues Zeichen: SVG nach `assets/signs/vz<nr>.svg` (Punkt in der amtlichen Nummer wird
zum Bindestrich: 325.1 → `vz325-1.svg`), `vz: '<nr>'` an den Katalogeintrag, Erwartung in
`test/traffic_sign_test.dart` ergänzen, Sprechvarianten in `command_phrases.dart` – und
nur bei nicht-quadratischer Form eine Zeile in `_aspect`.

## Logo & App-Icons

Die App trägt seit dem 08.08.2026 **Sarahs Logo** (Regenbogenbogen um ein Lenkrad mit
Rollstuhl-Piktogramm, darunter „Fahrlehrerin Sarah"). Vorlagen liegen in `images/`,
kopiert aus `kunden/fahrlehrerin_sarah/` – dort steht in der `CLAUDE.md` die
ausführliche Herleitung:

| Datei | Was |
|---|---|
| `images/logo_sarah_master.png` | volles Logo, freigestellt, 1254 px – Quelle aller Ableitungen |
| `images/logo_sarah_bogen.webp` | nur der Bogen, 1000 px – Bühne für das Signet |
| `assets/logo_sarah[_hell].webp` | volles Logo für helle / dunkle Gründe |
| `assets/logo_sarah_signet[_hell].webp` | Bogen + Lenkrad **ohne Schriftzug** |

Regeln – kommen aus dem Logo selbst, nicht aus Geschmack:

- **Überall das Signet** (`SarahLogo(signet: true)`) – Sender-Header, Empfängerschirm
  und seit dem 13.08.2026 auch der Startbildschirm. Klein skaliert wäre der mitgetragene
  Schriftzug ohnehin Matsch, und auf dem Startbildschirm stünde er doppelt: direkt
  darunter sitzt die Wortmarke. Das volle Logo bleibt als Asset für Aushänge und
  Druckstücke, ist in der App aber nirgends mehr eingebunden.
- **Auf dunklem Grund die `_hell`-Variante** (Schrift creme, Lenkrad invertiert), sonst
  verschwindet „Fahrlehrerin" im Grund. `SarahLogo` wählt sie nach der Theme-Helligkeit;
  auf dem Empfängerschirm bestimmt aber die Dringlichkeitsfarbe den Grund → dort setzt
  der Aufrufer `onDark` selbst (hell außer auf Gelb).
- **Optisch zentrieren, nicht geometrisch.** Die Dateien sind exakt symmetrisch
  beschnitten, das Motiv ist es nicht: der Regenbogen ist ein „C" mit dicker
  Pinselwange links und offener Seite rechts. Auf die Bildkante zentriert wirkt
  das Logo nach links gerutscht. `SarahLogo` gleicht das mit einer Polsterung
  von `kOpticalShift` (5 % der Bildbreite) aus – gemessen am Schwerpunkt der
  *gefüllten* Silhouette (5,1 % links) und an gerenderten Varianten geprüft.
  Bewusst im Widget und nicht in der Datei: das Asset bleibt die unveränderte
  Marke, und der Ausgleich wirkt an allen Einsatzorten. Ein neues Logo braucht
  eine neue Messung – `test/brand_logo_test.dart` hält Seitenverhältnis und
  Wirkung fest.
- **WebP, nicht PNG** – die Aquarell-Verläufe komprimieren als PNG viermal so groß
  (1,2 MB statt 300 kB), und die Web-App wird über Mobilfunk geladen.
- Das alte `FahrSignalLogo` (gezeichnetes Lenkrad im Regenbogen-Ring) bleibt in
  `lib/ui/brand.dart`, ist aber **nirgends mehr eingebunden** – aufgehoben als neutrale
  Marke, falls die App über Sarahs Fahrschule hinauswächst.

Ableitungen neu bauen (aus der Projektwurzel, ImageMagick 7). Das Signet ist eine
**Neukomposition**, kein Ausschnitt: im Originallogo sitzt das Lenkrad hoch und rechts,
weil darunter der Schriftzug steht – ausgeschnitten hinge es schief in der Öffnung.

```sh
# 1. Lenkrad als runde Scheibe ausstanzen und mittig in den Bogen setzen
magick images/logo_sarah_master.png -background white -alpha remove -alpha off \
  -crop 232x232+557+314 +repage \
  \( -size 232x232 xc:black -fill white -draw 'circle 116,116 116,3' -alpha off \) \
  -compose CopyOpacity -composite /tmp/wheel.png
magick images/logo_sarah_bogen.webp \( /tmp/wheel.png -resize 300x300 \) \
  -geometry +449+446 -compose over -composite /tmp/signet-master.png

# 2. App-Assets (die _hell-Variante tauscht Schwarz/Weiß über die Zwischenfarbe
#    Magenta – sonst frisst der zweite -opaque-Durchgang den ersten wieder auf)
magick images/logo_sarah_master.png -trim +repage -resize 640x \
  -quality 86 -define webp:method=6 assets/logo_sarah.webp
magick images/logo_sarah_master.png \
  -fuzz 16% -fill '#FF00FF' -opaque white \
  -fuzz 22% -fill '#FDF8F0' -opaque '#231F20' \
  -fuzz  4% -fill '#2B2434' -opaque '#FF00FF' \
  -trim +repage -resize 640x -quality 86 -define webp:method=6 assets/logo_sarah_hell.webp
# dieselben zwei Befehle mit /tmp/signet-master.png und -resize 320x → *_signet*.webp

# 3. Icon-Master: Signet auf Creme, quadratisch gepolstert. Maskable kleiner (58 %),
#    damit die Form innerhalb des sicheren Kreises bleibt.
magick /tmp/signet-master.png -trim +repage -resize 800x800 -background '#FDF8F0' \
  -gravity center -extent 1024x1024 -alpha remove -alpha off /tmp/icon-master.png
magick /tmp/signet-master.png -trim +repage -resize 600x600 -background '#FDF8F0' \
  -gravity center -extent 1024x1024 -alpha remove -alpha off /tmp/icon-maskable.png
```

Daraus die Icons: `web/favicon.png` (64), `web/icons/Icon-{192,512}.png` und
`Icon-maskable-{192,512}.png`, `android/app/src/main/res/mipmap-*/ic_launcher.png`
(48/72/96/144/192) sowie alle `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`
in ihren jeweiligen Kantenlängen. **iOS-Icons müssen deckend sein** – dort zusätzlich
`-alpha remove -alpha off`, ein Alphakanal führt zur Ablehnung im App Store. Das Icon
ist bewusst das Signet ohne Schriftzug: auf dem Homescreen bliebe der Text unlesbar.
`manifest.json` trägt denselben Creme-Ton als `background_color`, sonst blitzt beim
PWA-Start ein weißer Rand um das Icon.

## Hosting & Deploy (Web-Prototyp)

Die Web-App läuft unter `https://fahrsignal.fahrlehrerinsarah.de` auf **unserem eigenen
VPS** `187.124.178.193` (`srv1535638.hstgr.cloud`) — derselben Kiste wie
`fahrlehrerinsarah.de` und `kein-einzelfall.nils-digital.de`. Vorher lag sie bei Vercel;
umgezogen am 11.08.2026, weil Sarah die App bis zur Abnahme passwortgeschützt haben
wollte und der Schutz auf dem eigenen Server hingehört, nicht in die App.

**Push auf `main` ist der Deploy.** `.github/workflows/deploy.yml` baut im GitHub-Runner
und schiebt das Ergebnis auf den Server:

```
git push main
  └─ Flutter 3.44.3 (exakt gepinnt) → flutter build web → .js/.wasm vorkomprimieren
       └─ tar | ssh root@VPS         → /docker/fahrsignal/deploy.sh
            └─ site/releases/<stand>/ entpacken, Symlink site/www atomar schwenken
```

Anders als die PHP-Nachbarn, die auf dem Server selbst bauen: Flutter auf zwei Kernen
wäre pro Push mehrere Minuten, das Builder-Image wiegt Gigabytes. Der Server bekommt
nur fertige Dateien. Der dafür hinterlegte Schlüssel darf auf dem Server ausschließlich
`deploy.sh` ausführen (erzwungener Befehl in `authorized_keys`) — eine Shell bekommt man
damit nicht.

| Wo | Was |
|---|---|
| `deploy/docker-compose.yml` | nginx-Container + Traefik-Route, hängt am Netz `n8n_default` |
| `deploy/nginx.conf` | Auslieferung, `gzip_static`, Cache-Regeln |
| `deploy/deploy.sh` | liegt auf dem Server als `/docker/fahrsignal/deploy.sh` |
| GitHub Secrets | `SUPABASE_URL`, `SUPABASE_KEY`, `VPS_HOST`, `VPS_SSH_KEY` |
| `/docker/fahrsignal/deploy/.env` | `FS_AUTH` (bcrypt) — **nicht** im Repo, das ist öffentlich |

Was beim Anfassen leicht schiefgeht:

- **Der bcrypt-Hash in `.env` muss in einfachen Anführungszeichen stehen.** Sonst frisst
  die Variablen-Ersetzung von docker compose die Dollarzeichen (`$2y$10$…` → `$2y$10…`),
  der Hash ist still kaputt und *jedes* Passwort wird abgelehnt.
- **Der Volume-Mount geht auf `site/`, nicht auf `site/www`.** Docker löst einen Symlink
  beim Mounten einmal auf; zeigte der Mount direkt auf `www`, liefe der Container nach
  dem nächsten Deploy weiter gegen den alten Stand. Aus demselben Grund ist das
  Symlink-Ziel in `deploy.sh` **relativ** — ein absoluter Pfad existiert im Container nicht.
- **Kompression ist hier nicht Feinschliff.** `main.dart.js` wiegt 2,8 MB, `canvaskit.wasm`
  6,9 MB. Vercels CDN hat das unsichtbar erledigt; nginx muss es gesagt bekommen, und die
  `.gz` entstehen im CI.
- **Flutter-Version gepinnt lassen.** Ein frisches „stable" hat schon einmal einen weißen
  Bildschirm erzeugt.
- Ein Release liegt bei ~25 MB, die letzten fünf bleiben liegen. Zurückschwenken von Hand:
  `cd /docker/fahrsignal/site && ln -sfn releases/<stand> www.neu && mv -T www.neu www`

### Passwortschutz — zur Abnahme entfernen

Der Schutz sitzt als Traefik-Middleware **vor** dem Container: ohne Anmeldung wird kein
Byte ausgeliefert, auch keine einzelne Asset-Datei. Genau ein Zugang für alle Tester.
Middlewares wirken nur auf den Router, der sie nennt — `fahrlehrerinsarah.de` bleibt
davon unberührt und öffentlich.

**Zum Livegang** in `deploy/docker-compose.yml` die beiden Middleware-Zeilen
(`fahrsignal-auth`, `fahrsignal-noindex`) und ihren Eintrag in
`routers.fahrsignal.middlewares` entfernen, dann auf dem Server
`cd /docker/fahrsignal/deploy && docker compose up -d`.

## iOS bauen ohne Mac
Android + gesamte Logik laufen lokal. iOS-Builds brauchen die macOS-Toolchain → **nicht lokal
versuchen**, sondern **Cloud-CI**: Codemagic (Flutter-nah, Gratis-Kontingent) oder GitHub Actions
mit macOS-Runnern bauen/signieren und verteilen per TestFlight. Apple Developer Program nötig.

## Sicherheits- & UX-Leitplanken (nicht aufweichen)
- Empfängerbildschirm **frei von bedienbaren Elementen** – während der Fahrt nur Anzeige.
- Große, kontrastreiche Symbole; Farbcodierung strikt nach `urgency`.
- **Verbindungs-Watchdog**: bei Abbruch beide Geräte sofort deutlich warnen (Heartbeat).
- Empfängergerät **wach halten** (Wakelock) und gegen App-Verlassen sichern (iOS Geführter
  Zugriff / Android App-Pinning).
- **Local-first = Datenschutz-Vorteil**: im BLE-Modus verlassen keine Daten das Auto; keine PII;
  Cloud nur mit EU-Hosting und Ablaufzeiten.

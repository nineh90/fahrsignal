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

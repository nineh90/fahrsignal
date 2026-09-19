// Vorschau-Werkzeug, kein Test im eigentlichen Sinn: rendert alle Kacheln
// des Katalogs (wie der Sender sie zeigt) in ein PNG, damit sich Schilder
// und Piktogramme ohne laufende App nebeneinander beurteilen lassen.
//
//   flutter test test/preview/tiles_preview_test.dart
//   → /tmp/fs/tiles.png und /tmp/fs/receiver.png
//
// Läuft nur, wenn FS_PREVIEW gesetzt ist, damit `flutter test` es überspringt.
@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/receiver_view.dart';
import 'package:fahrsignal/ui/traffic_signs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final home = Platform.environment['HOME']!;
  final dir = '$home/flutter/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, String file) async {
    final bytes = File('$dir/$file').readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await load('MaterialIcons', 'MaterialIcons-Regular.otf');
  await load('Roboto', 'Roboto-Regular.ttf');
  await load('Roboto', 'Roboto-Bold.ttf');
  await load('Roboto', 'Roboto-Black.ttf');
}

Future<void> _snap(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _tile(CommandDef def) => Material(
  color: tileColor(def),
  borderRadius: BorderRadius.circular(14),
  child: SizedBox(
    width: 118,
    height: 100,
    child: def.signOnly
        ? Center(child: TrafficSign(def: def, size: 64))
        : Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TrafficSign(def: def, size: 42),
                  const SizedBox(height: 6),
                  Text(
                    def.tileText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
  ),
);

void main() {
  final on = Platform.environment['FS_PREVIEW'] == '1';

  testWidgets('Kachelraster als PNG', (tester) async {
    await tester.runAsync(_loadFonts);
    Directory('/tmp/fs').createSync(recursive: true);

    final cols = 8;
    final rows = (kCommandCatalog.length / cols).ceil();
    final key = GlobalKey();
    tester.view.physicalSize = Size(cols * 128.0 + 10, rows * 110.0 + 10);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFF15181C),
            padding: const EdgeInsets.all(5),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [for (final d in kCommandCatalog) _tile(d)],
            ),
          ),
        ),
      ),
    );
    // SVGs laden asynchron – mehrfach pumpen, bis alles da ist.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await _snap(tester, key, '/tmp/fs/tiles.png');
  }, skip: !on);

  testWidgets('Empfängerschirm als PNG', (tester) async {
    await tester.runAsync(_loadFonts);
    final keys =
        (Platform.environment['FS_KEYS'] ??
                'links,schulterblick,bremsen,einordnen_links,ausfahrt2,lob')
            .split(',');
    final key = GlobalKey();
    tester.view.physicalSize = Size(keys.length * 400.0, 700);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: Row(
            children: [
              for (final k in keys)
                Builder(
                  builder: (_) {
                    final def = commandByKey(k)!;
                    final bg = tileColor(def);
                    final fg = foregroundOn(bg);
                    return Container(
                      width: 400,
                      height: 700,
                      color: bg,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TrafficSign(def: def, size: 200, color: fg),
                          const SizedBox(height: 24),
                          FittedBox(
                            child: Text(
                              def.label.toUpperCase(),
                              style: TextStyle(
                                color: fg,
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await _snap(tester, key, '/tmp/fs/receiver.png');
  }, skip: !on);

  // Echte Empfängeransicht (Handyformat) mit Verlauf: FS_PREV wird zuerst
  // gesendet, dann FS_KEY (optional FS_ORD, FS_COMBO=a,b,c).
  //   FS_PREVIEW=1 FS_PREV=spiegel FS_KEY=links flutter test test/preview/…
  testWidgets('echte Empfängeransicht als PNG', (tester) async {
    await tester.runAsync(_loadFonts);
    final env = Platform.environment;
    final prev = env['FS_PREV'];
    final key = env['FS_KEY'] ?? 'links';
    final ord = int.tryParse(env['FS_ORD'] ?? '') ?? 0;
    final combo = env['FS_COMBO']?.split(',');
    final rk = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: rk, child: const ReceiverView()),
        ),
      ),
    );
    Future<void> send(DriveCommand c) async {
      await FakeTransport('DEV').sendCommand(c);
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    if (prev != null) await send(DriveCommand.now(prev, Urgency.info));
    await send(
      combo != null
          ? DriveCommand.combo(combo, Urgency.info, ord: ord)
          : DriveCommand.now(key, Urgency.info, ord: ord),
    );
    await _snap(tester, rk, '/tmp/fs/receiver_real.png');
  }, skip: !on);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/ui/traffic_signs.dart';

/// Die Zuordnung Kommando → Verkehrszeichen steht als Nummernstring im
/// Katalog (`vz: '209-10'`). Ein Tippfehler dort fiele sonst erst im Auto auf,
/// wenn die Kachel leer bleibt – deshalb hier festgehalten.
void main() {
  final mitZeichen = kCommandCatalog.where((d) => d.vz.isNotEmpty).toList();

  test('jedes Kommando mit Zeichen hat auch die Datei', () async {
    expect(mitZeichen, isNotEmpty);
    for (final def in mitZeichen) {
      final data = await rootBundle.loadString(def.vzAsset);
      expect(
        data,
        contains('<svg'),
        reason: '${def.key} verweist auf ${def.vzAsset}',
      );
    }
  });

  test('die erwarteten Kommandos tragen ein Zeichen', () {
    expect(
      {for (final d in mitZeichen) d.key: d.vz},
      {
        'links': '211-10',
        'rechts': '211-20',
        'geradeaus': '209-30',
        'abbiegen_links': '209-10',
        'abbiegen_rechts': '209-20',
        'kreisverkehr': '215',
        'ampel': '131',
        'parken': '314',
        't_schritt': '325-1',
        'vorfahrt_gewaehren': '205',
        'vorfahrtstrasse': '306',
        'stopp': '206',
      },
    );
    // Zeichen und gezeichnetes Tempo-Schild schließen sich aus.
    for (final d in mitZeichen) {
      expect(d.sign, SignShape.none, reason: '${d.key} hat beides');
    }
    // Die Tempo-Zeichen bleiben gezeichnet (die Zahl kommt aus dem Katalog).
    expect(commandByKey('t_30')!.sign, SignShape.limit);
    expect(commandByKey('t_frei')!.sign, SignShape.ende);
  });

  testWidgets('jedes Zeichen rendert und bringt seinen weißen Saum mit', (
    tester,
  ) async {
    for (final def in mitZeichen) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // Dieselbe Farbe wie die Richtungs-Kachel: hier fiele auf, wenn
            // ein blaues Zeichen ohne Absetzung im Grund verschwindet.
            backgroundColor: const Color(0xFF1E88E5),
            body: Center(child: TrafficSign(def: def, size: 120)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: def.key);

      // Zweimal dasselbe Bild: die weiß eingefärbte Silhouette dahinter und
      // das Zeichen darüber.
      final bilder = tester.widgetList<SvgPicture>(
        find.descendant(
          of: find.byType(TrafficSign),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(bilder, hasLength(2), reason: def.key);
      expect(
        bilder.first.colorFilter,
        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        reason: '${def.key} braucht den weißen Saum',
      );
      expect(bilder.last.colorFilter, isNull, reason: def.key);
    }
  });

  testWidgets('das Querformat-Schild wird nicht ins Quadrat gequetscht', (
    tester,
  ) async {
    final schritt = commandByKey('t_schritt')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: TrafficSign(def: schritt, size: 60)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester.getSize(find.byType(TrafficSign));
    expect(box.height, 60);
    expect(box.width, greaterThan(80), reason: 'VZ 325.1 ist ein Querformat');
  });
}

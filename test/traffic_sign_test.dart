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
        't_zone20': '274-1-20',
        't_zone30': '274-1',
        't_frei': '282',
        'vorfahrt_gewaehren': '205',
        'vorfahrtstrasse': '306',
        'vorfahrt': '301',
        'abknickend_links': '306-1002-10',
        'abknickend_rechts': '306-1002-20',
        'hindernis': '101',
        'stopp': '206',
        'tanken': '365-52',
      },
    );
    // Zeichen und gezeichnetes Tempo-Schild schließen sich aus.
    for (final d in mitZeichen) {
      expect(d.sign, SignShape.none, reason: '${d.key} hat beides');
      expect(d.picto, isEmpty, reason: '${d.key} hat Zeichen und Piktogramm');
    }
    // Die Tempo-Zeichen bleiben gezeichnet (die Zahl kommt aus dem Katalog).
    expect(commandByKey('t_30')!.sign, SignShape.limit);
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

  group('Piktogramme statt erfundener Schilder', () {
    // Auskunft TÜV (09/2026): die App darf keine Schilder zeigen, die es an
    // der Straße nicht gibt – auch keine „im Stil der StVO" nachgebauten.
    // Alles ohne amtliches Zeichen ist deshalb ein flaches Piktogramm.
    final ohneZeichen = kCommandCatalog.where((d) => !d.isSign).toList();

    test('jedes eigene Piktogramm hat seine Datei', () async {
      final eigene = ohneZeichen.where((d) => d.picto.isNotEmpty);
      expect(eigene, isNotEmpty);
      for (final def in eigene) {
        final data = await rootBundle.loadString(def.pictoAsset);
        expect(
          data,
          contains('<svg'),
          reason: '${def.key} verweist auf ${def.pictoAsset}',
        );
        // Einfarbig: die Farbe kommt aus der App (ColorFilter), nicht aus
        // der Datei – sonst bliebe das Bild auf gelbem Grund weiß.
        expect(
          data,
          isNot(anyOf(contains('#'), contains('rgb('))),
          reason: '${def.key}: Piktogramm trägt eigene Farben',
        );
      }
    });

    testWidgets('ein Piktogramm ist kein Schild – nichts wird gemalt', (
      tester,
    ) async {
      for (final def in ohneZeichen) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TrafficSign(
                  def: def,
                  size: 96,
                  color: const Color(0xFF111417),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: def.key);
        final innen = find.descendant(
          of: find.byType(TrafficSign),
          matching: find.byType(CustomPaint),
        );
        expect(innen, findsNothing, reason: '${def.key} zeichnet eine Form');

        // Entweder das Material-Symbol oder das eingefärbte eigene Bild.
        if (def.picto.isEmpty) {
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.icon, def.icon, reason: def.key);
          expect(icon.color, const Color(0xFF111417), reason: def.key);
        } else {
          final bild = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(
            bild.colorFilter,
            const ColorFilter.mode(Color(0xFF111417), BlendMode.srcIn),
            reason: '${def.key} nimmt die Anzeigefarbe nicht an',
          );
        }
      }
    });
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

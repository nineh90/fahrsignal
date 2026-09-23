import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/tile_layout.dart';
import 'package:fahrsignal/ui/sender_grid.dart';
import 'package:fahrsignal/ui/tile_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<String> keys(List<CommandDef> ds) => [for (final d in ds) d.key];

/// Vollständige Reihenfolge einer Kategorie mit [first] vorne – so, wie der
/// Editor sie speichert.
List<String> vorne(CommandCategory c, List<String> first) => [
  ...first,
  for (final d in commandsInCategory(c))
    if (!first.contains(d.key)) d.key,
];

void main() {
  group('Standard-Raster (SAR-120)', () {
    const l = TileLayout.standard;

    test('die sechs Richtungs-Kacheln sind aus, „Straße" folgt der Ampel', () {
      final richtung = keys(l.visible(CommandCategory.richtung));
      for (final k in kDefaultHiddenKeys) {
        expect(richtung, isNot(contains(k)));
        // Nur ausgeblendet, nicht gelöscht – die Sprachleiste braucht sie.
        expect(commandByKey(k), isNotNull, reason: k);
      }
      expect(richtung.indexOf('strasse'), richtung.indexOf('ampel') + 1);
    });

    test('Notkommandos lassen sich nicht ausblenden', () {
      var x = l;
      for (final k in kExamSafetyKeys) {
        x = x.withHidden(k, true);
        expect(x.isHidden(k), isFalse, reason: k);
      }
    });

    test('Prüfungsmodus filtert zusätzlich', () {
      expect(
        keys(l.visible(CommandCategory.hinweis, exam: true)),
        unorderedEquals(['anhalten', 'stopp']),
      );
    });
  });

  group('Eigene Anordnung', () {
    test('Reihenfolge und Einblenden', () {
      final l = TileLayout.standard
          .withOrder(
            CommandCategory.richtung,
            vorne(CommandCategory.richtung, ['ampel', 'links', 'rechts']),
          )
          .withHidden('rueckwaerts', false);
      final v = keys(l.visible(CommandCategory.richtung));
      expect(v.take(3), ['ampel', 'links', 'rechts']);
      expect(v, contains('rueckwaerts'));
    });

    test('neue Katalog-Kachel landet hinter ihrem Vorgänger', () {
      // Eine Anordnung von vor „Straße": sie fehlt in der gespeicherten Liste.
      final alt = [
        for (final d in commandsInCategory(CommandCategory.richtung))
          if (d.key != 'strasse') d.key,
      ].reversed.toList();
      final v = keys(
        TileLayout.standard
            .withOrder(CommandCategory.richtung, alt)
            .arranged(CommandCategory.richtung),
      );
      expect(v.indexOf('strasse'), v.indexOf('ampel') + 1);
      expect(
        v.toSet(),
        keys(commandsInCategory(CommandCategory.richtung)).toSet(),
      );
    });

    test('übersteht das Speichern, verträgt Müll', () {
      final l = TileLayout.standard
          .withOrder(CommandCategory.tempo, ['t_50', 't_30'])
          .withHidden('hupe', true);
      final back = TileLayout.fromJson(
        jsonDecode(jsonEncode(l.toJson())) as Map<String, dynamic>,
      );
      expect(back.order[CommandCategory.tempo], ['t_50', 't_30']);
      expect(back.hidden, l.hidden);

      final kaputt = TileLayout.fromJson({
        'order': {
          'gibtsnicht': ['x'],
          'tempo': 'kein array',
        },
        'hidden': 42,
      });
      expect(kaputt.order, isEmpty);
      expect(kaputt.hidden, kDefaultHiddenKeys);
      // Unbekannte Keys in der Reihenfolge fallen heraus.
      expect(
        keys(
          TileLayout.standard
              .withOrder(CommandCategory.tempo, [
                'weg',
                ...vorne(CommandCategory.tempo, ['t_30']),
              ])
              .arranged(CommandCategory.tempo),
        ).first,
        't_30',
      );
    });
  });

  group('Neue Standard-Ausblendungen', () {
    TileLayout laden(Map<String, dynamic> j) =>
        TileLayout.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);

    test('erreichen eine alte gespeicherte Anordnung', () {
      // Gespeichert vor SAR-119: „Rückwärts" wieder eingeblendet.
      final alt = laden({
        'order': <String, dynamic>{},
        'hidden': ['abbiegen_links', 'abbiegen_rechts'],
      });
      expect(alt.isHidden('parken'), isTrue);
      expect(alt.isHidden('rueckwaerts'), isFalse, reason: 'Wahl bleibt');
    });

    test('wieder Eingeblendetes bleibt eingeblendet', () {
      final l = TileLayout.standard.withHidden('parken', false);
      final back = laden(l.toJson());
      expect(back.isHidden('parken'), isFalse);
    });
  });

  group('Sender', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> aufbauen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SenderGrid())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('zeigt „Straße", nicht „Abbiegen links"', (tester) async {
      await aufbauen(tester);
      expect(find.text('Straße'), findsOneWidget);
      expect(find.text('Abbiegen links'), findsNothing);
    });

    testWidgets('lädt die gespeicherte Anordnung', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tile_layout_v1': jsonEncode(
          TileLayout.standard.withHidden('abbiegen_links', false).toJson(),
        ),
      });
      await aufbauen(tester);
      expect(find.text('Abbiegen links'), findsOneWidget);
    });

    testWidgets('Kacheln anpassen: einblenden wirkt sofort und bleibt', (
      tester,
    ) async {
      await aufbauen(tester);
      await tester.tap(find.byTooltip('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kacheln anpassen'));
      await tester.pumpAndSettle();
      expect(find.byType(TileEditor), findsOneWidget);

      final zeile = find.ancestor(
        of: find.text('Rückwärts'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(of: zeile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Rückwärts'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      final saved = TileLayout.fromJson(
        jsonDecode(prefs.getString('tile_layout_v1')!) as Map<String, dynamic>,
      );
      expect(saved.isHidden('rueckwaerts'), isFalse);
    });

    testWidgets('Notkommando hat einen gesperrten Schalter', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TileEditor())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Stop'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final zeile = find.ancestor(
        of: find.text('Stop'),
        matching: find.byType(ListTile),
      );
      final schalter = tester.widget<Switch>(
        find.descendant(of: zeile, matching: find.byType(Switch)),
      );
      expect(schalter.onChanged, isNull);
      expect(schalter.value, isTrue);
    });
  });
}

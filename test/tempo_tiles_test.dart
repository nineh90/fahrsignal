import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/speech/command_parser.dart';
import 'package:fahrsignal/domain/tile_layout.dart';
import 'package:fahrsignal/ui/sender_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _limits = ['t_30', 't_50', 't_70', 't_100', 't_frei'];

void main() {
  group('Tempo-Bereich (SAR-119)', () {
    final tempo = [
      for (final d in TileLayout.standard.visible(CommandCategory.tempo)) d.key,
    ];

    test('Halten ist raus, die Limits stehen hintereinander', () {
      expect(tempo, isNot(contains('parken')));
      final start = tempo.indexOf('t_30');
      expect(tempo.sublist(start, start + _limits.length), _limits);
    });

    test(
      '20er Zone ist da – als amtliches Zeichen, in der Prüfung gesperrt',
      () {
        expect(tempo, contains('t_zone20'));
        final zone = commandByKey('t_zone20')!;
        expect(zone.vzAsset, 'assets/signs/vz274-1-20.svg');
        expect(allowedInExam(zone), isFalse);
        expect(parseUtterance('jetzt kommt eine 20er zone').key, 't_zone20');
      },
    );

    test('ohne Wort nur, wo das Schild die Anweisung ausschreibt', () {
      final ohneWort = {
        for (final d in kCommandCatalog)
          if (d.signOnly) d.key,
      };
      expect(ohneWort, {..._limits, 't_zone20', 't_zone30'});
      // Wer nur das Schild zeigt, braucht auch eines.
      for (final k in ohneWort) {
        expect(commandByKey(k)!.isSign, isTrue, reason: k);
      }
    });
  });

  testWidgets('Kacheln ohne Wort: Schild statt Text, Name für Screenreader', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tempo 50'), findsNothing);
    expect(find.text('Halten'), findsNothing);
    expect(find.text('Langsamer'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Tempo 50\b')), findsOneWidget);

    // Die fünf Limits teilen sich auch auf dem Handy eine Zeile.
    final ys = {
      for (final k in ['Tempo 30', 'Tempo 100', 'Unbegrenzt'])
        tester.getCenter(find.bySemanticsLabel(RegExp('^$k\\b'))).dy,
    };
    expect(ys, hasLength(1));
    semantics.dispose();
  });
}

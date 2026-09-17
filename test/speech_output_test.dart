import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/domain/spoken_text.dart';
import 'package:fahrsignal/domain/voice_phrases.dart';
import 'package:fahrsignal/platform/speech/speech_output.dart';
import 'package:fahrsignal/providers.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/receiver_view.dart';
import 'package:fahrsignal/ui/sender_grid.dart';

String? de(DriveCommand c) => spokenGerman(c)?.text;
String? im(VoiceLanguage l, DriveCommand c) => spokenIn(l, c)?.text;

void main() {
  group('Deutsche Ansage (SAR-121)', () {
    test('sagt, was auf dem Schirm steht', () {
      expect(de(DriveCommand.now('links', Urgency.info)), 'Links');
    });

    test('Ordnungszahlen als Wort, nicht als „zwei Punkt"', () {
      expect(
        de(DriveCommand.now('abbiegen_links', Urgency.info, ord: 2)),
        'zweite Straße links',
      );
      expect(
        de(DriveCommand.now('ausfahrt3', Urgency.info)),
        'dritte Ausfahrt',
      );
    });

    test('Kombination nennt alle Teile, Abfrage verrät keine Lösung', () {
      expect(
        de(DriveCommand.combo(['links', 'schulterblick'], Urgency.info)),
        'Links, Schulterblick',
      );
      final frage = kCommandCatalog.firstWhere((d) => d.hasExplanation);
      final text = de(DriveCommand.now(frage.key, frage.urgency, ask: true))!;
      expect(text, 'Zeige mir: ${frage.label}');
      expect(text, isNot(contains(frage.explanation)));
    });

    test('Freitext wörtlich, „off" schweigt', () {
      expect(
        de(DriveCommand.freitext('  Parkplatz suchen ')),
        'Parkplatz suchen',
      );
      expect(de(DriveCommand.now(kOffKey, Urgency.info)), isNull);
    });

    test('kein Katalogeintrag spricht Ziffern mit Punkt', () {
      for (final d in kCommandCatalog) {
        final text = de(DriveCommand.now(d.key, d.urgency))!;
        expect(text, isNot(matches(RegExp(r'\d\.\s'))), reason: d.key);
      }
    });
  });

  group('Übersetzte Ansage', () {
    test('jede Sprache kennt jede Kachel', () {
      // Eine neue Kachel ohne Übersetzung spräche im Auto still deutsch.
      for (final l in VoiceLanguage.values.skip(1)) {
        final phrases = kVoicePhrases[l]!;
        for (final d in kCommandCatalog) {
          expect(
            phrases[d.key]?.trim(),
            isNotEmpty,
            reason: '${l.code}: "${d.key}" fehlt',
          );
        }
        expect(
          phrases.keys.where((k) => commandByKey(k) == null),
          isEmpty,
          reason: '${l.code}: Übersetzung ohne Kachel',
        );
        expect(kVoiceAsk[l], isNotNull, reason: l.code);
      }
    });

    test('Sprache und Stimme passen zusammen', () {
      final u = spokenIn(
        VoiceLanguage.tr,
        DriveCommand.now('abbiegen_links', Urgency.info),
      )!;
      expect(u, const Utterance('Sola dön', 'tr-TR'));
    });

    test('Ordnungszahl, Kombination und Abfrage', () {
      expect(
        im(
          VoiceLanguage.en,
          DriveCommand.now('abbiegen_rechts', Urgency.info, ord: 2),
        ),
        'Second street on the right',
      );
      expect(
        im(
          VoiceLanguage.ru,
          DriveCommand.now('abbiegen_links', Urgency.info, ord: 3),
        ),
        'Третья улица налево',
      );
      expect(
        im(
          VoiceLanguage.en,
          DriveCommand.combo(['links', 'schulterblick'], Urgency.info),
        ),
        'Left, Shoulder check',
      );
      expect(
        im(
          VoiceLanguage.en,
          DriveCommand.now('warndreieck', Urgency.info, ask: true),
        ),
        'Show me: Warning triangle',
      );
    });

    test('Freitext und Unübersetzbares fallen auf Deutsch zurück', () {
      final frei = DriveCommand.freitext('Parkplatz suchen').withVoice('ar');
      expect(
        announcementFor(frei)!.say,
        const Utterance('Parkplatz suchen', 'de-DE'),
      );

      // Ordnungszahl an einer Kachel ohne übersetzte Form.
      final ord = DriveCommand.now(
        'links',
        Urgency.info,
        ord: 2,
      ).withVoice('uk');
      expect(announcementFor(ord)!.say.locale, 'de-DE');
    });

    test('ohne Sprachwahl schweigt der Empfänger', () {
      expect(announcementFor(DriveCommand.now('links', Urgency.info)), isNull);
      // Unbekannter Code von einem neueren Sender: lieber deutsch.
      final neu = DriveCommand.now('links', Urgency.info).withVoice('fr');
      expect(announcementFor(neu)!.say, const Utterance('Links', 'de-DE'));
    });

    test('die Wahl übersteht die Leitung', () {
      final cmd = DriveCommand.now('links', Urgency.info).withVoice('tr');
      expect(DriveCommand.fromJson(cmd.toJson()).voice, 'tr');
      // Ältere Sender schicken kein Feld → stumm.
      final alt = Map.of(DriveCommand.now('links', Urgency.info).toJson())
        ..remove('voice');
      expect(DriveCommand.fromJson(alt).voice, '');
    });
  });

  group('Empfänger spricht', () {
    Future<RecordingSpeechOutput> aufbauen(WidgetTester tester) async {
      final voice = RecordingSpeechOutput();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [speechOutputProvider.overrideWithValue(voice)],
          child: const MaterialApp(home: ReceiverView()),
        ),
      );
      return voice;
    }

    Future<void> senden(WidgetTester tester, DriveCommand cmd) async {
      await FakeTransport('DEV').sendCommand(cmd);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('in der Sprache, die mitkommt', (tester) async {
      final voice = await aufbauen(tester);
      await senden(
        tester,
        DriveCommand.now('stopp', Urgency.dringend).withVoice('en'),
      );
      expect(voice.spoken, [const Utterance('Stop', 'en-GB')]);
    });

    testWidgets('ohne Sprache stumm, „off" bricht ab', (tester) async {
      final voice = await aufbauen(tester);
      await senden(tester, DriveCommand.now('links', Urgency.info));
      await senden(
        tester,
        DriveCommand.now(kOffKey, Urgency.info).withVoice('de'),
      );
      expect(voice.spoken, isEmpty);
      expect(voice.stops, 2);
    });
  });

  testWidgets('Fahrlehrer wählt die Sprache, die Anweisung trägt sie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final empfangen = <DriveCommand>[];
    final sub = FakeTransport('DEV').commands.listen(empfangen.add);
    addTearDown(sub.cancel);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    Future<void> tippeLinks() async {
      await tester.tap(find.text('Links').first);
      await tester.pump();
    }

    await tippeLinks();
    expect(empfangen.last.voice, '', reason: 'Standard: stumm');

    await tester.tap(find.byTooltip('Sprachausgabe beim Fahrschüler: aus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();

    await tippeLinks();
    expect(empfangen.last.voice, 'tr');
  });
}

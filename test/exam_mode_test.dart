import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/platform/speech/fake_speech_recognizer.dart';
import 'package:fahrsignal/providers.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/sender_grid.dart';

/// Fester Raumcode statt des Standards – der Test hört am selben Hub mit.
class _FixedRoom extends RoomCodeNotifier {
  _FixedRoom(this.room);
  final String room;
  @override
  String build() => room;
}

/// Mikrofonfreigabe als erteilt vortäuschen, sonst fragt die Leiste zuerst.
class _GrantedMic extends MicPermissionNotifier {
  @override
  bool? build() => true;
}

/// Prüfungsmodus: In der Prüfung darf nur beauftragt, nicht geholfen werden.
/// Die Tests halten die Grenze fest – vor allem die Ausnahme, dass die
/// Notkommandos jede Sperre überstimmen.
void main() {
  group('Katalogfilter', () {
    test('Hilfestellungen fallen weg, Fahraufträge bleiben', () {
      final erlaubt = kCommandCatalog.where(allowedInExam).map((d) => d.key);

      // Raus: Erinnerungen, Bewertung, Zuspruch, Tempovorgabe.
      for (final key in [
        'schulterblick',
        'spiegel',
        'blinker',
        'reihenfolge',
        'abstand',
        'hindernis',
        'lob',
        'fehler',
        'ruhig',
        'langsamer',
        'schneller',
        't_30',
        't_frei',
      ]) {
        expect(erlaubt, isNot(contains(key)), reason: '$key ist Hilfestellung');
      }

      // Drin: Fahraufträge, Prüfungsaufgaben, Fahrzeugfragen.
      for (final key in [
        'links',
        'rechts',
        'abbiegen_links',
        'kreisverkehr',
        'ausfahrt2',
        'parken',
        'gfa_laengs',
        'gfa_bremsung',
        'profil',
        'abs',
      ]) {
        expect(erlaubt, contains(key), reason: '$key ist eine Anweisung');
      }
    });

    test('Notkommandos überstimmen die Sperre', () {
      // „Anhalten" und „STOPP" stehen in der gesperrten Kategorie Hinweise,
      // „Bremsen" bei Tempo – die Fahrlehrperson muss auch in der Prüfung
      // eingreifen können.
      for (final key in kExamSafetyKeys) {
        final def = commandByKey(key);
        expect(def, isNotNull, reason: '$key fehlt im Katalog');
        expect(allowedInExam(def!), isTrue, reason: '$key muss bleiben');
      }
    });

    test('leergelaufene Kategorien und Bereiche verschwinden', () {
      // „Lob & Kritik" und „Coaching" laufen leer und fallen weg …
      expect(categoriesInMode(DashboardMode.fahrschueler, exam: true), [
        CommandCategory.organisation,
      ]);
      // … „Hinweise" nicht: dort stehen Anhalten und STOPP.
      expect(
        commandsInCategory(
          CommandCategory.hinweis,
          exam: true,
        ).map((d) => d.key),
        ['anhalten', 'stopp'],
      );
      // Tempo behält nur Bremsen und Halten.
      expect(
        commandsInCategory(CommandCategory.tempo, exam: true).map((d) => d.key),
        ['bremsen', 'parken'],
      );
      for (final m in modesWithContent(exam: true)) {
        expect(categoriesInMode(m, exam: true), isNotEmpty);
      }
    });

    test('Freitext und „Anzeige aus" bleiben sendbar', () {
      expect(keyAllowedInExam(kOffKey), isTrue);
      expect(
        commandAllowedInExam(DriveCommand.freitext('Rechts zur Prüfstelle')),
        isTrue,
      );
    });

    test('gemischte Kombination geht nicht raus – außer sie rettet', () {
      final gemischt = DriveCommand.combo([
        'abbiegen_links',
        'schulterblick',
      ], Urgency.info);
      expect(commandAllowedInExam(gemischt), isFalse);

      // Sicherheit vor Prüfungsreinheit: sobald ein Notkommando dabei ist,
      // geht der Befehl unverändert raus.
      final mitNot = DriveCommand.combo([
        'bremsen',
        'hindernis',
      ], Urgency.dringend);
      expect(commandAllowedInExam(mitNot), isTrue);
    });
  });

  group('Senderansicht', () {
    // Bewusst groß: die ListView baut nur, was sichtbar ist – auf einem
    // Handyschirm wäre „Hinweise" schlicht noch nicht gerendert.
    Future<void> pumpSender(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SenderGrid())),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Umschalter blendet Hilfestellungen aus und wieder ein', (
      tester,
    ) async {
      await pumpSender(tester);

      expect(find.text('Schulterblick'), findsOneWidget);

      await tester.tap(find.byTooltip('Prüfungsmodus starten'));
      await tester.pumpAndSettle();

      expect(find.text('Schulterblick'), findsNothing);
      expect(find.text('Spiegel'), findsNothing);
      expect(find.text('Tempo 30'), findsNothing);
      expect(find.text('PRÜFUNGSMODUS – nur Anweisungen'), findsOneWidget);

      // Anweisungen und Notkommandos bleiben erreichbar.
      expect(find.text('Links'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Bremsen'), findsOneWidget);

      await tester.tap(find.byTooltip('Prüfungsmodus beenden'));
      await tester.pumpAndSettle();
      expect(find.text('Schulterblick'), findsOneWidget);
    });

    testWidgets('leergelaufener Bereich fällt aus dem Umschalter', (
      tester,
    ) async {
      await pumpSender(tester);
      await tester.tap(find.text(DashboardMode.fahrschueler.label));
      await tester.pumpAndSettle();
      expect(find.text('Gut gemacht'), findsOneWidget);
      expect(find.text('Ruhig bleiben'), findsOneWidget);

      await tester.tap(find.byTooltip('Prüfungsmodus starten'));
      await tester.pumpAndSettle();

      // Lob und Zuspruch sind weg, Organisatorisches bleibt.
      expect(find.text('Gut gemacht'), findsNothing);
      expect(find.text('Ruhig bleiben'), findsNothing);
      expect(find.text('Pause machen'), findsOneWidget);
    });

    // Die Sprachleiste erreicht den Katalog an den Kacheln vorbei – ohne
    // eigene Sperre wäre der Prüfungsmodus reine Kosmetik.
    testWidgets('Sprache setzt die Sperre nicht außer Kraft', (tester) async {
      final gesendet = <DriveCommand>[];
      final lauscher = FakeTransport('PRUEF');
      final sub = lauscher.commands.listen(gesendet.add);
      addTearDown(() {
        sub.cancel();
        lauscher.dispose();
      });

      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomCodeProvider.overrideWith(() => _FixedRoom('PRUEF')),
            speechRecognizerProvider.overrideWithValue(
              FakeSpeechRecognizer(const ['Schulterblick', 'rechts abbiegen']),
            ),
            micPermissionProvider.overrideWith(() => _GrantedMic()),
          ],
          child: const MaterialApp(home: SenderGrid()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Prüfungsmodus starten'));
      await tester.pumpAndSettle();

      // 1. Äußerung: „Schulterblick" – eine Hilfestellung.
      await tester.tap(find.text('Halten & sprechen'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(gesendet, isEmpty, reason: 'Hilfestellung darf nicht raus');
      // Der Hinweis steht im Halteknopf selbst und verdrängt dort kurz die
      // Beschriftung – abwarten, bevor der Knopf erneut gedrückt wird.
      expect(find.text('Im Prüfungsmodus gesperrt'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 2. Äußerung: „rechts abbiegen" – ein Fahrauftrag, der durchgeht.
      await tester.tap(find.text('Halten & sprechen'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(gesendet.map((c) => c.key), contains('abbiegen_rechts'));
    });

    testWidgets('im Prüfungsmodus wird abgefragt, nicht erklärt', (
      tester,
    ) async {
      await pumpSender(tester);
      await tester.tap(find.text(DashboardMode.fahrzeug.label));
      await tester.pumpAndSettle();
      expect(find.text('Erklären'), findsOneWidget);

      await tester.tap(find.byTooltip('Prüfungsmodus starten'));
      await tester.pumpAndSettle();
      expect(find.text('Erklären'), findsNothing);
      expect(find.text('Abfragen'), findsNothing);
    });
  });
}

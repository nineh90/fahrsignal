import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/receiver_view.dart';
import 'package:fahrsignal/ui/traffic_signs.dart';

void main() {
  Future<void> senden(WidgetTester tester, String key) async {
    await FakeTransport('DEV').sendCommand(DriveCommand.now(key, Urgency.info));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder bild(String key) => find.byWidgetPredicate(
    (w) => w is TrafficSign && w.def.key == key,
    description: 'Bild von $key',
  );

  // Der Verlauf trägt die Beschriftung in normaler Schreibweise, die große
  // Anzeige in Großbuchstaben – so lassen sich beide auseinanderhalten.
  // Piktogramm-Kommandos, denn ein amtliches Zeichen steht ohne Wort.
  testWidgets('Verlauf: nur der vorige, das aktive steht groß', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReceiverView())),
    );

    await senden(tester, 'spiegel');
    expect(find.text('SPIEGEL'), findsOneWidget);
    expect(find.text('Spiegel'), findsNothing, reason: 'aktiv, nicht Verlauf');

    await senden(tester, 'abstand');
    await senden(tester, 'gang');
    await senden(tester, 'schulterblick');

    expect(find.text('SCHULTERBLICK'), findsOneWidget);
    expect(find.text('Schulterblick'), findsNothing);
    expect(find.text('Gang wechseln'), findsOneWidget);
    expect(find.text('Abstand'), findsNothing, reason: 'nur einer');

    // Größer als früher (12,5), als vergangen gekennzeichnet.
    expect(tester.widget<Text>(find.text('Gang wechseln')).style!.fontSize, 21);
    expect(find.text('ZUVOR'), findsOneWidget);

    // Anzeige aus: der zuletzt gezeigte bleibt stehen.
    await senden(tester, kOffKey);
    expect(find.text('Schulterblick'), findsOneWidget);
    expect(find.text('Gang wechseln'), findsNothing);
    expect(tester.takeException(), isNull);

    // Langer Hinweis: gekürzt, nicht übergelaufen, Schrift bleibt groß.
    await senden(tester, 'reihenfolge');
    await senden(tester, 'links');
    expect(tester.takeException(), isNull);
    final lang = find.textContaining('Innenspiegel');
    expect(tester.widget<Text>(lang).style!.fontSize, 21);
    expect(tester.getRect(lang).right, lessThanOrEqualTo(390));
  });

  // Rückmeldung 19.09.2026: ein amtliches Zeichen wird im Unterricht gelehrt
  // und steht beim Schüler **ohne Wort** – groß in der Mitte, im Verlauf und
  // als Kombi-Chip. Nur die Ordnungszahl bleibt als Plakette.
  testWidgets('amtliches Zeichen steht ohne Wort', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReceiverView())),
    );

    await senden(tester, 'links');
    expect(bild('links'), findsOneWidget);
    expect(find.text('LINKS'), findsNothing);
    expect(find.text('Links'), findsNothing);

    // Ohne Wort darf das Zeichen größer stehen als mit.
    final ohneWort = tester.getSize(bild('links')).height;
    await senden(tester, 'spiegel');
    final mitWort = tester.getSize(bild('spiegel')).height;
    expect(ohneWort, greaterThan(mitWort));

    // Im Verlauf: das Zeichen, kein „Links".
    expect(bild('links'), findsOneWidget);
    expect(find.text('Links'), findsNothing);

    // Ordnungszahl bleibt – groß als Plakette, im Verlauf klein.
    await FakeTransport(
      'DEV',
    ).sendCommand(DriveCommand.now('abbiegen_links', Urgency.info, ord: 2));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2.'), findsOneWidget);
    expect(find.textContaining('STRASSE'), findsNothing);
    await senden(tester, 'spiegel');
    expect(find.text('2.'), findsOneWidget, reason: 'Plakette im Verlauf');
    expect(find.textContaining('Straße'), findsNothing);

    // Kombi: Zeichen an zweiter Stelle ohne Wort, Piktogramm mit.
    await FakeTransport('DEV').sendCommand(
      DriveCommand.combo(['links', 'rechts', 'spiegel'], Urgency.info),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(bild('rechts'), findsOneWidget);
    expect(find.text('RECHTS'), findsNothing);
    expect(find.text('SPIEGEL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('das Wort unter dem aktiven Schild steht in einer Zeile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReceiverView())),
    );
    await senden(tester, 'reihenfolge');
    final wort = find.textContaining('INNENSPIEGEL');
    final text = tester.widget<Text>(wort);
    expect(text.maxLines, 1);
    // Eine Zeile: nicht höher als die Schriftgröße samt Zeilenhöhe.
    expect(tester.getSize(wort).height, lessThanOrEqualTo(44 * 1.05 + 1));
    expect(tester.getRect(wort).width, lessThanOrEqualTo(390 - 40));
    expect(tester.takeException(), isNull);
  });
}

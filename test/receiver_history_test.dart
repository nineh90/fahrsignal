import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/receiver_view.dart';

void main() {
  Future<void> senden(WidgetTester tester, String key) async {
    await FakeTransport('DEV').sendCommand(DriveCommand.now(key, Urgency.info));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  // Der Verlauf trägt die Beschriftung in normaler Schreibweise, die große
  // Anzeige in Großbuchstaben – so lassen sich beide auseinanderhalten.
  testWidgets('Verlauf: nur der vorige, das aktive steht groß', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReceiverView())),
    );

    await senden(tester, 'links');
    expect(find.text('LINKS'), findsOneWidget);
    expect(find.text('Links'), findsNothing, reason: 'aktiv, nicht Verlauf');

    await senden(tester, 'rechts');
    await senden(tester, 'geradeaus');
    await senden(tester, 'ampel');

    expect(find.text('AMPEL'), findsOneWidget);
    expect(find.text('Ampel'), findsNothing);
    expect(find.text('Geradeaus'), findsOneWidget);
    expect(find.text('Rechts'), findsNothing, reason: 'nur einer');

    // Größer als früher (12,5), als vergangen gekennzeichnet.
    expect(tester.widget<Text>(find.text('Geradeaus')).style!.fontSize, 21);
    expect(find.text('ZUVOR'), findsOneWidget);

    // Anzeige aus: der zuletzt gezeigte bleibt stehen.
    await senden(tester, kOffKey);
    expect(find.text('Ampel'), findsOneWidget);
    expect(find.text('Geradeaus'), findsNothing);
    expect(tester.takeException(), isNull);

    // Langer Hinweis: gekürzt, nicht übergelaufen, Schrift bleibt groß.
    await senden(tester, 'reihenfolge');
    await senden(tester, 'links');
    expect(tester.takeException(), isNull);
    final lang = find.textContaining('Innenspiegel');
    expect(tester.widget<Text>(lang).style!.fontSize, 21);
    expect(tester.getRect(lang).right, lessThanOrEqualTo(390));
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

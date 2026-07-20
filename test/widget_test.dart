import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fahrsignal/main.dart';
import 'package:fahrsignal/ui/sender_grid.dart';

void main() {
  testWidgets('Startscreen zeigt Rollen-Auswahl und öffnet Senderansicht', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FahrSignalApp()));

    expect(find.text('Fahr'), findsOneWidget); // Wortmarke Teil 1
    expect(find.text('Signal'), findsOneWidget); // Wortmarke Teil 2
    expect(find.text('Senden (Fahrlehrer)'), findsOneWidget);
    expect(find.text('Empfangen (Fahrschüler)'), findsOneWidget);

    await tester.tap(find.text('Senden (Fahrlehrer)'));
    await tester.pumpAndSettle();

    // Senderansicht mit Kommando-Grid erscheint (erstes Item ist sichtbar).
    expect(find.byType(SenderGrid), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);
  });
}

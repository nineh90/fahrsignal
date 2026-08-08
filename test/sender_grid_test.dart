import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/ui/sender_grid.dart';

void main() {
  // Handy hochkant – der engste Fall, den die Fahrlehrperson im Auto hat.
  // Hier fällt auf, wenn eine Kachelzeile (z. B. die Ausfahrt-Gruppe) oder
  // ein zu langes Label das Layout sprengt.
  testWidgets('Sender rendert alle vier Bereiche ohne Overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    for (final mode in DashboardMode.values) {
      await tester.tap(find.byIcon(mode.icon).first);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Bereich ${mode.label} rendert fehlerfrei',
      );
    }
  });

  testWidgets('Ausfahrt-Gruppe steht in einer Zeile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    // Gleiche Oberkante = gleiche Zeile.
    final tops = [
      '1. Ausfahrt',
      '2. Ausfahrt',
      '3. Ausfahrt',
    ].map((t) => tester.getTopLeft(find.text(t)).dy).toSet();
    expect(tops, hasLength(1));
  });

  testWidgets('Kachel zeigt Kurzlabel, Katalog trägt den vollen Text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Reihenfolge'),
      find.byType(ListView),
      const Offset(0, -120),
    );

    expect(find.text('Reihenfolge'), findsOneWidget);
    expect(
      commandByKey('reihenfolge')!.label,
      'Spiegel – Blinker – Schulterblick',
    );
  });
}

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

  // iPad/Desktop: hier bekamen die Gruppenzeilen („1./2./3. Ausfahrt",
  // „Einordnen") früher die volle Breite geteilt durch Gruppengröße – also
  // dreimal so große Kacheln wie das freie Raster daneben.
  testWidgets('Alle Kacheln sind gleich groß – auch auf breitem Display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    final sizes = <Size>{};
    for (final cat in categoriesInMode(DashboardMode.fahrt)) {
      for (final def in commandsInCategory(cat)) {
        final tile = find.ancestor(
          of: find.text(def.tileText),
          matching: find.byType(InkWell),
        );
        if (tile.evaluate().isEmpty) continue; // noch nicht gescrollt
        sizes.add(tester.getSize(tile.first));
      }
    }
    expect(sizes, isNotEmpty);
    expect(sizes, hasLength(1), reason: 'genau ein Kachelmaß: $sizes');
    expect(sizes.first.height, 84);
    expect(sizes.first.width, lessThanOrEqualTo(118));
  });

  testWidgets('Symbol und Beschriftung sitzen mittig in der Kachel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SenderGrid())),
    );
    await tester.pumpAndSettle();

    // „Links" ist der kritische Fall: kurzes Wort, schmale Column. Genau da
    // klebte der Inhalt am linken Kachelrand, solange der Stack ihn oben
    // links ausrichtete.
    final tile = tester.getRect(
      find
          .ancestor(of: find.text('Links'), matching: find.byType(InkWell))
          .first,
    );
    expect(
      tester.getRect(find.text('Links')).center.dx,
      closeTo(tile.center.dx, 0.5),
    );
    expect(
      tester.getRect(find.byIcon(Icons.turn_left).first).center.dx,
      closeTo(tile.center.dx, 0.5),
    );
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

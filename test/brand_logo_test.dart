import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fahrsignal/ui/brand.dart';
import 'package:fahrsignal/ui/start_screen.dart';

/// Der optische Ausgleich in [SarahLogo] rechnet mit dem Seitenverhältnis der
/// Bilddateien. Diese Tests halten beides zusammen: die Annahme über die
/// Assets und die Wirkung im fertigen Bildschirm.
void main() {
  testWidgets(
    'Logo-Assets haben das Seitenverhältnis, mit dem gerechnet wird',
    (tester) async {
      const assets = [
        'assets/logo_sarah.webp',
        'assets/logo_sarah_hell.webp',
        'assets/logo_sarah_signet.webp',
        'assets/logo_sarah_signet_hell.webp',
      ];

      for (final path in assets) {
        late ui.Image image;
        await tester.runAsync(() async {
          final data = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          image = (await codec.getNextFrame()).image;
        });
        final aspect = image.width / image.height;
        expect(
          aspect,
          closeTo(SarahLogo.kAspect, 0.01),
          reason: '$path ist ${image.width}×${image.height}',
        );
        image.dispose();
      }
    },
  );

  testWidgets(
    'Startbildschirm setzt das Logo optisch mittig, nicht geometrisch',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StartScreen())),
      );
      // Ohne dekodiertes Bild hätte das Image keine Eigenbreite – die Box
      // wäre 0 breit und die Messung wertlos.
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
            image.image,
            tester.element(find.byType(StartScreen)),
          );
        }
      });
      await tester.pumpAndSettle();

      final box = tester.getRect(find.byType(Image).first);
      expect(box.width, greaterThan(0), reason: 'Logo wurde nicht geladen');
      final screenCentre = tester.view.physicalSize.width / 2;
      final offset = box.center.dx - screenCentre;

      // Das Motiv sitzt bewusst rechts der Bildschirmmitte – sonst zieht die
      // dicke Regenbogen-Wange links den Eindruck aus der Mitte.
      expect(
        offset,
        closeTo(box.width * SarahLogo.kOpticalShift, 1.0),
        reason:
            'Logo-Box ${box.width.toStringAsFixed(1)} breit, '
            'Versatz ${offset.toStringAsFixed(1)} px',
      );
    },
  );
}

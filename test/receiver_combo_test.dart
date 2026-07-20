import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/receiver_view.dart';

void main() {
  testWidgets('Empfänger rendert 3er-Kombi (auch aus Zeichen) ohne Fehler', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReceiverView())),
    );

    // Kombi aus drei Verkehrszeichen in denselben Raum ('DEV') senden.
    FakeTransport('DEV').sendCommand(
      DriveCommand.combo([
        'z_stop',
        'z_tempo30',
        'z_vorfahrt_gewaehren',
      ], Urgency.dringend),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('STOPP-SCHILD'), findsOneWidget);
  });
}

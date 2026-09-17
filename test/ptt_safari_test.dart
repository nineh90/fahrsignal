import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/platform/speech/speech_recognizer.dart';
import 'package:fahrsignal/providers.dart';
import 'package:fahrsignal/transport/fake_transport.dart';
import 'package:fahrsignal/ui/sender_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Erkennung, die der Test Schritt für Schritt steuert – so, wie sich
/// Safari auf dem iPhone verhält: Zwischenergebnisse, kein Endergebnis,
/// Ende erst Sekunden nach dem Loslassen (SAR-16).
class _SafariLike implements SpeechRecognizer {
  final _res = StreamController<SpeechResult>.broadcast();
  final statuses = StreamController<SpeechStatus>.broadcast();

  void interim(String t) =>
      _res.add(SpeechResult(transcript: t, confidence: 0, isFinal: false));
  void finalResult(String t) =>
      _res.add(SpeechResult(transcript: t, confidence: 0, isFinal: true));
  void ended() => statuses.add(SpeechStatus.idle);

  @override
  bool get isSupported => true;
  @override
  Stream<SpeechResult> get results => _res.stream;
  @override
  Stream<SpeechStatus> get status => statuses.stream;
  @override
  String get lastError => '';
  @override
  Future<bool> warmUp() async => true;
  @override
  Future<void> start({String locale = 'de-DE'}) async =>
      statuses.add(SpeechStatus.listening);
  @override
  Future<void> stop() async {}
  @override
  Future<void> abort() async {}
  @override
  void dispose() {}
}

class _GrantedMic extends MicPermissionNotifier {
  @override
  bool? build() => true;
}

void main() {
  late _SafariLike rec;
  late List<DriveCommand> gesendet;

  Future<TestGesture> halten(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.text('Halten & sprechen')),
    );
    await tester.pump();
    return g;
  }

  Future<void> aufbauen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    rec = _SafariLike();
    gesendet = [];
    final sub = FakeTransport('DEV').commands.listen(gesendet.add);
    addTearDown(sub.cancel);
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speechRecognizerProvider.overrideWithValue(rec),
          micPermissionProvider.overrideWith(_GrantedMic.new),
        ],
        child: const MaterialApp(home: SenderGrid()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nur Zwischenergebnis: geht nach dem Loslassen sofort raus', (
    tester,
  ) async {
    await aufbauen(tester);
    final g = await halten(tester);
    rec.interim('rechts');
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(gesendet, isEmpty, reason: 'erst ruhen lassen');

    // Kein Endergebnis, kein Ende – nach einer halben Sekunde trotzdem raus.
    await tester.pump(const Duration(milliseconds: 600));
    expect(gesendet.map((c) => c.key), ['rechts']);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('Safari bessert nach dem Loslassen nach: das Ganze zählt', (
    tester,
  ) async {
    await aufbauen(tester);
    final g = await halten(tester);
    rec.interim('zweite Straße');
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    rec.interim('zweite Straße links');
    await tester.pump(const Duration(milliseconds: 300));
    expect(gesendet, isEmpty, reason: 'Nachbesserung hält die Uhr an');
    await tester.pump(const Duration(milliseconds: 300));
    expect(gesendet, hasLength(1));
    expect(gesendet.single.ord, 2);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('spätes Ende und spätes Endergebnis senden nicht doppelt', (
    tester,
  ) async {
    await aufbauen(tester);
    final g = await halten(tester);
    rec.interim('Schulterblick');
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(gesendet, hasLength(1));

    rec.finalResult('Schulterblick und Spiegel');
    rec.ended();
    await tester.pump(const Duration(seconds: 2));
    expect(gesendet, hasLength(1));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('Ende ohne Worte meldet sich, statt stumm zu bleiben', (
    tester,
  ) async {
    await aufbauen(tester);
    final g = await halten(tester);
    await g.up();
    rec.ended();
    await tester.pump();
    expect(find.text('Nichts verstanden – nochmal versuchen'), findsOneWidget);
    expect(gesendet, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('Unklares bleibt in der Rückfrage', (tester) async {
    await aufbauen(tester);
    final g = await halten(tester);
    rec.interim('blinke irgendwas');
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(gesendet, isEmpty);
    // Die Rückfrage zeigt, was gehört wurde.
    expect(find.text('„blinke irgendwas"'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}

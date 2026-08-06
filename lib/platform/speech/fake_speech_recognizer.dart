/// Skriptbare Spracherkennung für Tests, Dev-Harness und als Rettungsnetz
/// für die Vorführung, falls Safari am Termin nicht mitspielt.
///
/// Aktivierung in der Produktion über `--dart-define=FAKE_SPEECH=1`.
library;

import 'dart:async';

import 'speech_recognizer.dart';

class FakeSpeechRecognizer implements SpeechRecognizer {
  /// Äußerungen, die nacheinander bei jedem [start] geliefert werden.
  final List<String> script;

  /// Konfidenz, die als Endergebnis gemeldet wird.
  final double confidence;

  /// Verzögerung bis zum Endergebnis – bildet die reale Latenz nach.
  final Duration delay;

  FakeSpeechRecognizer(
    this.script, {
    this.confidence = 0.95,
    this.delay = const Duration(milliseconds: 250),
  });

  final _results = StreamController<SpeechResult>.broadcast();
  final _status = StreamController<SpeechStatus>.broadcast();
  int _next = 0;
  Timer? _pending;

  @override
  bool get isSupported => true;

  @override
  Stream<SpeechResult> get results => _results.stream;

  @override
  Stream<SpeechStatus> get status => _status.stream;

  @override
  String get lastError => '';

  @override
  Future<bool> warmUp() async => true;

  @override
  Future<void> start({String locale = 'de-DE'}) async {
    if (script.isEmpty) return;
    final utterance = script[_next % script.length];
    _next++;
    _status.add(SpeechStatus.listening);

    // Zwischenergebnis (halber Satz), dann Endergebnis – so verhält sich
    // die echte Erkennung auch.
    final words = utterance.split(' ');
    final half = words.take((words.length / 2).ceil()).join(' ');
    _results.add(
      SpeechResult(transcript: half, confidence: 0, isFinal: false),
    );

    _pending = Timer(delay, () {
      _results.add(
        SpeechResult(
          transcript: utterance,
          confidence: confidence,
          isFinal: true,
        ),
      );
      _status.add(SpeechStatus.idle);
    });
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> abort() async {
    _pending?.cancel();
    _status.add(SpeechStatus.idle);
  }

  @override
  void dispose() {
    _pending?.cancel();
    _results.close();
    _status.close();
  }
}

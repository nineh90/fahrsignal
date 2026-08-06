/// Stub für alle Plattformen ohne Web Speech API (Linux-Desktop, Tests, VM).
///
/// Meldet `isSupported == false`; die UI blendet den Sprachmodus dann als
/// „auf diesem Gerät nicht verfügbar" aus, statt einen toten Knopf zu zeigen.
library;

import 'dart:async';

import 'speech_recognizer.dart';

class StubSpeechRecognizer implements SpeechRecognizer {
  final _results = StreamController<SpeechResult>.broadcast();
  final _status = StreamController<SpeechStatus>.broadcast();

  @override
  bool get isSupported => false;

  @override
  Stream<SpeechResult> get results => _results.stream;

  @override
  Stream<SpeechStatus> get status => _status.stream;

  @override
  String get lastError =>
      'Spracherkennung auf dieser Plattform nicht verfügbar';

  @override
  Future<bool> warmUp() async => false;

  @override
  Future<void> start({String locale = 'de-DE'}) async {
    _status.add(SpeechStatus.unsupported);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> abort() async {}

  @override
  void dispose() {
    _results.close();
    _status.close();
  }
}

SpeechRecognizer createSpeechRecognizer() => StubSpeechRecognizer();

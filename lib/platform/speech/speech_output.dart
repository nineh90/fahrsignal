/// Plattformkapsel für die Sprachausgabe beim Fahrschüler (SAR-121) – nach
/// dem Muster von `speech_recognizer.dart`.
///
/// Die UI kennt nur [SpeechOutput]. Dahinter steckt die Sprachsynthese des
/// Geräts: im Browser die Web Speech API, in der App `flutter_tts`. Eine
/// andere Stimme (etwa eine KI-Stimme von Sarah) ist eine weitere
/// Implementierung, keine Änderung an der Anzeige.
library;

import '../../domain/drive_command.dart';
import '../../domain/spoken_text.dart';
import 'speech_output_device.dart'
    if (dart.library.js_interop) 'speech_output_web.dart'
    as impl;

abstract class SpeechOutput {
  /// Spricht [say] und bricht dafür eine laufende Ansage ab: im Auto zählt
  /// nur die jüngste Anweisung, eine Warteschlange liefe der Fahrt hinterher.
  ///
  /// Hat das Gerät keine Stimme für die Sprache von [say], spricht es
  /// [fallback] – lieber deutsch als gar nicht.
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  });

  /// Schaltet die Ausgabe frei. **Muss aus einer echten Nutzergeste heraus
  /// aufgerufen werden** – Safari auf dem iPhone spricht sonst nie. Stumm.
  void prime();

  Future<void> stop();

  void dispose();
}

/// Erzeugt die zur Plattform passende Implementierung.
SpeechOutput createSpeechOutput() => impl.createSpeechOutput();

/// Merkt sich, was gesagt würde – für Tests.
class RecordingSpeechOutput implements SpeechOutput {
  final spoken = <Utterance>[];
  int stops = 0;
  bool primed = false;

  @override
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  }) async => spoken.add(say);

  @override
  void prime() => primed = true;

  @override
  Future<void> stop() async => stops++;

  @override
  void dispose() {}
}

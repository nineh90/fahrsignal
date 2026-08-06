/// Plattformkapsel für Spracherkennung – nach dem Muster von `keep_awake.dart`.
///
/// Die UI kennt nur dieses Interface. Auf Web liegt dahinter die Web Speech
/// API, überall sonst ein Stub, der `isSupported == false` meldet. Dadurch
/// bleiben Linux-Desktop, Dev-Harness und Tests ohne Mikrofon lauffähig.
library;

import 'speech_recognizer_stub.dart'
    if (dart.library.js_interop) 'speech_recognizer_web.dart'
    as impl;

/// Ein Zwischen- oder Endergebnis der Erkennung.
class SpeechResult {
  final String transcript;

  /// Konfidenz der Erkennung (0..1). Zwischenergebnisse melden oft 0 –
  /// der Aufrufer behandelt das über [isFinal].
  final double confidence;

  /// `false` = Zwischenergebnis, das sich noch ändern kann.
  final bool isFinal;

  const SpeechResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
  });

  @override
  String toString() =>
      'SpeechResult("$transcript", ${confidence.toStringAsFixed(2)}, '
      'final=$isFinal)';
}

enum SpeechStatus {
  /// Plattform kann keine Spracherkennung (Linux-Desktop, Tests).
  unsupported,

  /// Bereit, hört aber nicht zu.
  idle,

  /// Mikrofon ist offen.
  listening,

  /// Letzter Versuch ist gescheitert (Berechtigung, Netz, kein Signal).
  error,
}

abstract class SpeechRecognizer {
  /// Ob auf dieser Plattform überhaupt erkannt werden kann.
  bool get isSupported;

  /// Zwischen- und Endergebnisse.
  Stream<SpeechResult> get results;

  Stream<SpeechStatus> get status;

  /// Letzter Fehlertext, für die Anzeige. Leer, wenn keiner vorlag.
  String get lastError;

  /// Holt die Mikrofonberechtigung ab. **Muss aus einer echten Nutzergeste
  /// heraus aufgerufen werden** – Safari verweigert es sonst. Deshalb hängt
  /// es in der UI an einem eigenen Knopf und nicht am Start des Bildschirms.
  Future<bool> warmUp();

  Future<void> start({String locale = 'de-DE'});

  /// Beendet die Aufnahme und lässt das Endergebnis noch durch.
  Future<void> stop();

  /// Bricht ab und verwirft ein etwaiges Endergebnis.
  Future<void> abort();

  void dispose();
}

/// Erzeugt die zur Plattform passende Implementierung.
SpeechRecognizer createSpeechRecognizer() => impl.createSpeechRecognizer();

/// Web Speech API über `dart:js_interop` – **ohne zusätzliches Paket**.
///
/// Bewusst kein `speech_to_text`: das wrappt auf Web dieselbe API, brächte
/// Plugin-Registranten für Plattformen mit, die wir nicht bauen, und löst die
/// eigentliche Hürde (Safaris Gestenanforderung) ohnehin nicht.
///
/// **Safari-Eigenheiten, die hier bewusst abgefangen werden:**
/// - `continuous = true` wird ignoriert; die Erkennung endet nach kurzer
///   Stille von selbst → Auto-Neustart, solange der Knopf gehalten wird.
/// - `start()` auf einer laufenden Erkennung wirft `InvalidStateError`.
/// - Die Berechtigung wird nur aus einer echten Nutzergeste heraus erteilt.
library;

import 'dart:async';
import 'dart:js_interop';
// Für den dynamischen Zugriff auf `globalContext[...]` und den Aufruf des
// Konstruktors: die Web Speech API heißt je nach Browser anders und lässt
// sich deshalb nicht statisch binden.
import 'dart:js_interop_unsafe';

import 'speech_recognizer.dart';

extension type _Recognition._(JSObject _) implements JSObject {
  external set lang(String v);
  external set continuous(bool v);
  external set interimResults(bool v);
  external set maxAlternatives(int v);
  external set onresult(JSFunction v);
  external set onerror(JSFunction v);
  external set onend(JSFunction v);
  external set onstart(JSFunction v);
  external void start();
  external void stop();
  external void abort();
}

extension type _ResultEvent._(JSObject _) implements JSObject {
  external int get resultIndex;
  external _ResultList get results;
}

extension type _ResultList._(JSObject _) implements JSObject {
  external int get length;
  external _Result item(int index);
}

extension type _Result._(JSObject _) implements JSObject {
  external bool get isFinal;
  external int get length;
  external _Alternative item(int index);
}

extension type _Alternative._(JSObject _) implements JSObject {
  external String get transcript;
  external double get confidence;
}

extension type _ErrorEvent._(JSObject _) implements JSObject {
  external String get error;
}

extension type _Navigator._(JSObject _) implements JSObject {
  external _MediaDevices? get mediaDevices;
}

extension type _MediaDevices._(JSObject _) implements JSObject {
  external JSPromise<_MediaStream> getUserMedia(JSObject constraints);
}

extension type _MediaStream._(JSObject _) implements JSObject {
  external JSArray<_MediaTrack> getTracks();
}

extension type _MediaTrack._(JSObject _) implements JSObject {
  external void stop();
}

/// Maximale Zahl **erfolgloser** automatischer Neustarts hintereinander.
/// Verhindert eine Endlosschleife, wenn das Mikrofon dauerhaft nichts liefert.
/// Sobald ein Ergebnis ankommt, beginnt die Zählung von vorn – sonst wäre bei
/// einem längeren Haltevorgang irgendwann stumm Schluss, obwohl gesprochen
/// wird (Safari beendet die Erkennung nach jeder Sprechpause von selbst).
const int _maxRestarts = 12;

class WebSpeechRecognizer implements SpeechRecognizer {
  final _results = StreamController<SpeechResult>.broadcast();
  final _statusCtrl = StreamController<SpeechStatus>.broadcast();

  _Recognition? _recognition;
  bool _wantListening = false;
  int _restarts = 0;
  String _lastError = '';

  WebSpeechRecognizer() {
    _recognition = _create();
  }

  static JSFunction? _constructor() {
    final modern = globalContext['SpeechRecognition'];
    if (modern != null) return modern as JSFunction;
    final webkit = globalContext['webkitSpeechRecognition'];
    if (webkit != null) return webkit as JSFunction;
    return null;
  }

  _Recognition? _create() {
    final ctor = _constructor();
    if (ctor == null) return null;
    final obj = ctor.callAsConstructor<JSObject>();
    final rec = _Recognition._(obj)
      ..lang = 'de-DE'
      // iOS ignoriert `continuous`; wir starten stattdessen selbst neu.
      ..continuous = false
      ..interimResults = true
      // Mehr Deutungen kosten nichts und geben dem Parser mehr zu prüfen.
      ..maxAlternatives = 5;

    rec.onresult = ((JSObject event) => _onResult(_ResultEvent._(event))).toJS;
    rec.onerror = ((JSObject event) => _onError(_ErrorEvent._(event))).toJS;
    rec.onend = ((JSObject _) => _onEnd()).toJS;
    rec.onstart = ((JSObject _) {
      _statusCtrl.add(SpeechStatus.listening);
    }).toJS;
    return rec;
  }

  void _onResult(_ResultEvent event) {
    final list = event.results;
    for (var i = event.resultIndex; i < list.length; i++) {
      final result = list.item(i);
      if (result.length == 0) continue;
      final best = result.item(0);
      final text = best.transcript.trim();
      if (text.isEmpty) continue;
      // Es kommt etwas an – das Neustart-Budget für die nächste Sprechpause
      // ist damit wieder voll.
      _restarts = 0;

      // Die weiteren Deutungen mitnehmen, statt sie wegzuwerfen: „Blinke"
      // als beste und „Blinker" als zweite Hypothese ist der Alltagsfall,
      // an dem die Erkennung sonst scheitert. Auswerten tut der Parser.
      final alternatives = <String>[];
      for (var a = 1; a < result.length; a++) {
        final alt = result.item(a).transcript.trim();
        if (alt.isNotEmpty && alt != text && !alternatives.contains(alt)) {
          alternatives.add(alt);
        }
      }

      _results.add(
        SpeechResult(
          transcript: text,
          // Safari meldet für Zwischenergebnisse 0 – erst das Endergebnis
          // trägt eine belastbare Konfidenz.
          confidence: result.isFinal ? best.confidence : 0,
          isFinal: result.isFinal,
          alternatives: result.isFinal ? alternatives : const [],
        ),
      );
    }
  }

  void _onError(_ErrorEvent event) {
    _lastError = switch (event.error) {
      'not-allowed' || 'service-not-allowed' =>
        'Mikrofon nicht freigegeben. In den Safari-Einstellungen erlauben.',
      'no-speech' => 'Nichts verstanden.',
      'audio-capture' => 'Kein Mikrofon gefunden.',
      'network' => 'Spracherkennung braucht eine Internetverbindung.',
      final other => 'Spracherkennung: $other',
    };
    // „no-speech" ist Alltag beim Halten und darf den Modus nicht abbrechen.
    if (event.error != 'no-speech') {
      _wantListening = false;
      _statusCtrl.add(SpeechStatus.error);
    }
  }

  void _onEnd() {
    // Safari beendet nach kurzer Stille selbst. Solange der Knopf gehalten
    // wird, sofort wieder aufmachen – sonst reißt die Aufnahme mitten im Satz.
    if (_wantListening && _restarts < _maxRestarts) {
      _restarts++;
      Timer(const Duration(milliseconds: 150), () {
        if (!_wantListening) return;
        try {
          _recognition?.start();
        } catch (_) {
          // Läuft bereits – unkritisch.
        }
      });
      return;
    }
    _wantListening = false;
    _statusCtrl.add(SpeechStatus.idle);
  }

  @override
  bool get isSupported => _recognition != null;

  @override
  Stream<SpeechResult> get results => _results.stream;

  @override
  Stream<SpeechStatus> get status => _statusCtrl.stream;

  @override
  String get lastError => _lastError;

  @override
  Future<bool> warmUp() async {
    // Explizit übers Mikrofon fragen statt die Erkennung kurz anzutippen:
    // getUserMedia löst den Berechtigungsdialog aus **und** liefert eine
    // belastbare Antwort. Ein kurzer Start der Erkennung täte das nicht —
    // dort käme eine Ablehnung erst später als `not-allowed`-Event.
    //
    // Muss aus einer echten Nutzergeste heraus laufen; deshalb hängt der
    // Aufruf am Umschalten auf „Sprechen" bzw. am Mikrofonknopf.
    final navigator = globalContext['navigator'];
    if (navigator == null) return false;
    final devices = _Navigator._(navigator as JSObject).mediaDevices;
    if (devices == null) {
      _lastError = 'Mikrofonzugriff erfordert eine sichere Verbindung (HTTPS).';
      return false;
    }

    try {
      final constraints = {'audio': true}.jsify() as JSObject;
      final stream = await devices.getUserMedia(constraints).toDart;
      // Sofort wieder freigeben – wir wollten nur die Freigabe, keine Aufnahme.
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
      _lastError = '';
      return true;
    } catch (_) {
      _lastError =
          'Mikrofon nicht freigegeben. In Safari über „aA" in der Adresszeile '
          '→ Website-Einstellungen → Mikrofon erlauben.';
      _statusCtrl.add(SpeechStatus.error);
      return false;
    }
  }

  @override
  Future<void> start({String locale = 'de-DE'}) async {
    if (_recognition == null) return;
    _wantListening = true;
    _restarts = 0;
    _lastError = '';
    _recognition!.lang = locale;
    try {
      _recognition!.start();
    } catch (_) {
      // InvalidStateError: läuft schon. Kein Grund zur Beunruhigung.
    }
  }

  @override
  Future<void> stop() async {
    _wantListening = false;
    try {
      _recognition?.stop();
    } catch (_) {}
  }

  @override
  Future<void> abort() async {
    _wantListening = false;
    try {
      _recognition?.abort();
    } catch (_) {}
  }

  @override
  void dispose() {
    _wantListening = false;
    try {
      _recognition?.abort();
    } catch (_) {}
    _results.close();
    _statusCtrl.close();
  }
}

SpeechRecognizer createSpeechRecognizer() => WebSpeechRecognizer();

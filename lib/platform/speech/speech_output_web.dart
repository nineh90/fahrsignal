/// Sprachausgabe im Browser über die Web Speech API (`speechSynthesis`) –
/// direkt über `dart:js_interop`, wie die Spracherkennung.
///
/// Bewusst nicht `flutter_tts` auf Web: das Plugin verwendet ein einziges
/// Utterance-Objekt und spricht nur, wenn es sich im Zustand „gestoppt"
/// glaubt. Nach einem Abbruch kommt dieser Zustand erst mit dem nächsten
/// Ereignis an – eine sofort folgende Anweisung wurde still verworfen.
/// Genau „abbrechen und Neues sagen" ist hier aber der Normalfall.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../domain/drive_command.dart';
import '../../domain/spoken_text.dart';
import 'speech_output.dart';

SpeechOutput createSpeechOutput() => WebSpeechOutput();

extension type _Synth._(JSObject _) implements JSObject {
  external void speak(_Utterance u);
  external void cancel();
  external JSArray<_Voice> getVoices();
}

extension type _Utterance._(JSObject _) implements JSObject {
  external set lang(String v);
  external set rate(double v);
  external set volume(double v);
  external set voice(_Voice? v);
}

extension type _Voice._(JSObject _) implements JSObject {
  external String get lang;
}

class WebSpeechOutput implements SpeechOutput {
  final _Synth? _synth = _findSynth();

  static _Synth? _findSynth() {
    final s = globalContext['speechSynthesis'];
    return s == null ? null : _Synth._(s as JSObject);
  }

  // Chrome gibt ein Utterance-Objekt ohne Referenz vorzeitig frei und
  // bricht die Ansage dann mittendrin ab – deshalb festhalten.
  // ignore: unused_field
  _Utterance? _current;

  _Utterance _utterance(String text) {
    final ctor = globalContext['SpeechSynthesisUtterance'] as JSFunction;
    return _Utterance._(ctor.callAsConstructor<JSObject>(text.toJS));
  }

  /// Stimme für [locale]: exakt (`tr-TR`), sonst gleiche Sprache (`tr`).
  /// `null`, wenn keine da ist.
  _Voice? _voiceFor(String locale, List<_Voice> voices) {
    String norm(String l) => l.replaceAll('_', '-').toLowerCase();
    final want = norm(locale);
    final lang = want.split('-').first;
    _Voice? sameLang;
    for (final v in voices) {
      final l = norm(v.lang);
      if (l == want) return v;
      if (sameLang == null && l.split('-').first == lang) sameLang = v;
    }
    return sameLang;
  }

  @override
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  }) async {
    final synth = _synth;
    if (synth == null) return;
    try {
      final voices = synth.getVoices().toDart;
      var u = say;
      var voice = _voiceFor(say.locale, voices);
      // Leere Liste heißt oft nur „noch nicht geladen" (Chrome) – dann
      // der Sprache vertrauen und den Browser wählen lassen.
      if (voice == null && voices.isNotEmpty && fallback != null) {
        u = fallback;
        voice = _voiceFor(u.locale, voices);
      }
      final utt = _utterance(u.text)
        ..lang = u.locale
        ..voice = voice
        ..rate = urgency == Urgency.dringend ? 1.15 : 1.0;
      synth.cancel();
      _current = utt;
      synth.speak(utt);
    } catch (_) {}
  }

  @override
  void prime() {
    final synth = _synth;
    if (synth == null) return;
    try {
      // Eine leere, stumme Ansage aus der Geste heraus reicht Safari, um
      // die Ausgabe für die ganze Sitzung freizugeben.
      final utt = _utterance('')..volume = 0;
      _current = utt;
      synth.speak(utt);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      _synth?.cancel();
    } catch (_) {}
  }

  @override
  void dispose() => stop();
}

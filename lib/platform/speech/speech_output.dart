/// Plattformkapsel für die Sprachausgabe beim Fahrschüler (SAR-121) – nach
/// dem Muster von `speech_recognizer.dart`.
///
/// Die UI kennt nur [SpeechOutput]. Dahinter steckt die Sprachsynthese des
/// Geräts: im Browser die Web Speech API, in der App `flutter_tts`. Eine
/// andere Stimme (etwa eine KI-Stimme von Sarah) ist eine weitere
/// Implementierung, keine Änderung an der Anzeige.
library;

import 'dart:async';
import 'dart:collection';

import '../../domain/drive_command.dart';
import '../../domain/spoken_text.dart';
import 'speech_output_device.dart'
    if (dart.library.js_interop) 'speech_output_web.dart'
    as impl;

abstract class SpeechOutput {
  /// Spricht [say] und bricht dafür eine laufende Ansage ab. Das Future ist
  /// erfüllt, wenn die Ansage **zu Ende gesprochen** (oder abgebrochen) ist –
  /// darauf baut [QueuedSpeechOutput] die Reihenfolge auf.
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

/// Erzeugt die zur Plattform passende Implementierung – **mit Warteschlange**.
SpeechOutput createSpeechOutput() =>
    QueuedSpeechOutput(impl.createSpeechOutput());

/// Spricht Ansagen **nacheinander** statt sich gegenseitig abzubrechen.
///
/// Rückmeldung (19.09.2026): schickt die Fahrlehrerin zwei Anweisungen kurz
/// hintereinander („links" – „Schulterblick"), brach die zweite die erste
/// mitten im Wort ab – bei zusammengehörenden Ansagen sinnlos. Jetzt läuft
/// die aktive zu Ende, die nächste folgt.
///
/// Zwei Grenzen, beide aus dem Auto heraus:
/// - **Dringendes unterbricht sofort.** Ein „Stop", das wartet, bis
///   „Schulterblick" fertig ist, wäre das Gegenteil seines Zwecks. Es leert
///   auch die Warteschlange: was danach noch käme, ist überholt.
/// - **Höchstens [maxPending] warten.** Eine Ansage, die erst nach vier
///   anderen dran wäre, beschreibt eine Situation, die vorbei ist – die
///   älteste Wartende fliegt raus. `off` (→ [stop]) leert alles.
///
/// Meldet die Plattform das Ende nicht (Safari lässt `onend` nach `cancel`
/// schon mal aus), springt eine Schätzung ein: [_estimate] aus der Textlänge,
/// großzügig – lieber eine kurze Pause als zwei Stimmen übereinander.
class QueuedSpeechOutput implements SpeechOutput {
  final SpeechOutput _inner;
  final int maxPending;
  final Queue<_Pending> _queue = Queue();
  bool _busy = false;
  int _generation = 0;

  QueuedSpeechOutput(this._inner, {this.maxPending = 3});

  /// Warten gerade Ansagen? (für Tests)
  int get pending => _queue.length;
  bool get speaking => _busy;

  static Duration _estimate(Utterance u) =>
      Duration(milliseconds: 1500 + 120 * u.text.length);

  @override
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  }) async {
    if (urgency == Urgency.dringend) {
      _queue.clear();
      _generation++;
      _busy = false;
      // Kein `await`: die alte Ansage soll nicht erst ausgelaufen sein.
      unawaited(_inner.stop());
    }
    final p = _Pending(say, fallback, urgency);
    if (_busy) {
      _queue.add(p);
      while (_queue.length > maxPending) {
        _queue.removeFirst();
      }
      return;
    }
    await _drain(p);
  }

  Future<void> _drain(_Pending first) async {
    _Pending? next = first;
    while (next != null) {
      _busy = true;
      final gen = _generation;
      try {
        await _inner
            .speak(next.say, fallback: next.fallback, urgency: next.urgency)
            .timeout(_estimate(next.say));
      } catch (_) {
        // Zeitüberschreitung oder Plattformfehler – weiter mit der nächsten.
      }
      // Ein Dringend- oder Stop-Aufruf hat inzwischen alles verworfen und
      // gegebenenfalls eine eigene Kette gestartet.
      if (gen != _generation) return;
      next = _queue.isEmpty ? null : _queue.removeFirst();
    }
    _busy = false;
  }

  @override
  void prime() => _inner.prime();

  @override
  Future<void> stop() {
    _queue.clear();
    _generation++;
    _busy = false;
    return _inner.stop();
  }

  @override
  void dispose() {
    _queue.clear();
    _inner.dispose();
  }
}

class _Pending {
  final Utterance say;
  final Utterance? fallback;
  final Urgency urgency;
  const _Pending(this.say, this.fallback, this.urgency);
}

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

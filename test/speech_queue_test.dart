import 'dart:async';

import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/domain/spoken_text.dart';
import 'package:fahrsignal/platform/speech/speech_output.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stimme, deren Ansagen erst enden, wenn der Test es sagt.
class _SlowVoice implements SpeechOutput {
  final spoken = <Utterance>[];
  final _open = <Completer<void>>[];
  int stops = 0;

  @override
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  }) {
    spoken.add(say);
    final c = Completer<void>();
    _open.add(c);
    return c.future;
  }

  /// Die älteste laufende Ansage ist zu Ende.
  void finish() => _open.removeAt(0).complete();

  @override
  Future<void> stop() async {
    stops++;
    for (final c in _open) {
      if (!c.isCompleted) c.complete();
    }
    _open.clear();
  }

  @override
  void prime() {}
  @override
  void dispose() {}
}

const _links = Utterance('Links', 'de-DE');
const _blick = Utterance('Schulterblick', 'de-DE');
const _spiegel = Utterance('Spiegel', 'de-DE');
const _stop = Utterance('Stop', 'de-DE');

void main() {
  // Rückmeldung (19.09.2026): zwei Anweisungen kurz nacheinander brachen
  // sich gegenseitig ab. Jetzt wird die aktive zu Ende gesprochen.
  test('die zweite Ansage wartet, bis die erste zu Ende ist', () async {
    final inner = _SlowVoice();
    final q = QueuedSpeechOutput(inner);

    unawaited(q.speak(_links));
    unawaited(q.speak(_blick));
    await Future<void>.delayed(Duration.zero);
    expect(inner.spoken, [_links], reason: 'zweite noch nicht gestartet');
    expect(q.pending, 1);
    expect(inner.stops, 0, reason: 'nichts abgebrochen');

    inner.finish();
    await Future<void>.delayed(Duration.zero);
    expect(inner.spoken, [_links, _blick]);
    expect(q.pending, 0);

    inner.finish();
    await Future<void>.delayed(Duration.zero);
    expect(q.speaking, isFalse);
  });

  test('Dringendes unterbricht sofort und leert die Warteschlange', () async {
    final inner = _SlowVoice();
    final q = QueuedSpeechOutput(inner);

    unawaited(q.speak(_links));
    unawaited(q.speak(_blick));
    unawaited(q.speak(_stop, urgency: Urgency.dringend));
    await Future<void>.delayed(Duration.zero);

    expect(inner.stops, 1);
    expect(inner.spoken, [_links, _stop], reason: 'Schulterblick verworfen');
    expect(q.pending, 0);

    // Nach dem Stop läuft die Kette normal weiter – ohne Geister der alten.
    unawaited(q.speak(_spiegel));
    await Future<void>.delayed(Duration.zero);
    expect(q.pending, 1);
    inner.finish();
    await Future<void>.delayed(Duration.zero);
    expect(inner.spoken.last, _spiegel);
  });

  test('stop (Anzeige aus) verwirft alles Wartende', () async {
    final inner = _SlowVoice();
    final q = QueuedSpeechOutput(inner);
    unawaited(q.speak(_links));
    unawaited(q.speak(_blick));
    await q.stop();
    await Future<void>.delayed(Duration.zero);
    expect(inner.spoken, [_links]);
    expect(q.pending, 0);
    expect(q.speaking, isFalse);
  });

  test('höchstens drei warten – die älteste fliegt', () async {
    final inner = _SlowVoice();
    final q = QueuedSpeechOutput(inner);
    unawaited(q.speak(_links));
    for (final u in const [
      Utterance('a', 'de-DE'),
      Utterance('b', 'de-DE'),
      Utterance('c', 'de-DE'),
      Utterance('d', 'de-DE'),
    ]) {
      unawaited(q.speak(u));
    }
    expect(q.pending, 3);
    for (var i = 0; i < 4; i++) {
      inner.finish();
      await Future<void>.delayed(Duration.zero);
    }
    expect(inner.spoken.map((u) => u.text), ['Links', 'b', 'c', 'd']);
  });

  testWidgets('meldet die Plattform kein Ende, geht es nach Schätzung weiter', (
    tester,
  ) async {
    final inner = _SlowVoice();
    final q = QueuedSpeechOutput(inner);
    unawaited(q.speak(_links));
    unawaited(q.speak(_blick));
    await tester.pump();
    expect(inner.spoken, [_links]);
    // 1,5 s + 120 ms je Zeichen („Links" = 5) = 2,1 s
    await tester.pump(const Duration(milliseconds: 2000));
    expect(inner.spoken, [_links], reason: 'noch nicht abgelaufen');
    await tester.pump(const Duration(milliseconds: 200));
    expect(inner.spoken, [_links, _blick]);
    // Den Schätz-Timer der zweiten Ansage nicht offen lassen.
    await q.stop();
    await tester.pump(const Duration(seconds: 5));
  });
}

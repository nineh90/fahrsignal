import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/domain/speech/command_parser.dart';

/// Die Sprachlogik ist reines Dart – hier laufen die Garantien, an denen sich
/// jede Erweiterung des Katalogs messen lassen muss.
void main() {
  group('Normalisierung', () {
    test('Zahlwörter werden zu Ziffern', () {
      expect(normalizeUtterance('Tempo dreißig'), 'tempo 30');
      expect(normalizeUtterance('Tempo 30'), 'tempo 30');
      expect(normalizeUtterance('fünfzig'), '50');
    });
  });

  group('Vorfahrt', () {
    // Die beiden liegen sprachlich dicht beieinander und dürfen sich nicht
    // gegenseitig treffen: „der hat Vorfahrt" ist das Gegenteil von
    // „du hast Vorfahrt".
    test('gewähren und Vorfahrtstraße bleiben auseinander', () {
      for (final pair in {
        'Vorfahrt gewähren': 'vorfahrt_gewaehren',
        'Vorfahrt beachten': 'vorfahrt_gewaehren',
        'der hat Vorfahrt': 'vorfahrt_gewaehren',
        'Vorfahrtstraße': 'vorfahrtstrasse',
        'du hast Vorfahrt': 'vorfahrtstrasse',
      }.entries) {
        final r = parseUtterance(pair.key);
        expect(r.key, pair.value, reason: pair.key);
        expect(r.outcome, ParseOutcome.matched, reason: pair.key);
      }
    });
  });

  group('Unscharfe Treffer', () {
    test('Verhörer landen beim gemeinten Kommando', () {
      for (final pair in {
        'schulterblik': 'schulterblick',
        'warndreiek': 'warndreieck',
        'gefahrenbremsun': 'gfa_bremsung',
      }.entries) {
        final r = parseUtterance(pair.key);
        expect(r.key, pair.value, reason: pair.key);
        expect(r.outcome, ParseOutcome.matched);
      }
    });

    test('zu kurze Wörter werden nicht geraten', () {
      final r = parseUtterance('hup');
      expect(r.outcome, ParseOutcome.unmatched);
      expect(r.alternatives, contains('hupe'));
    });

    test('unscharf gefundenes Dringendes braucht eine Bestätigung', () {
      // Ein rot aufleuchtender Schirm ist die gefährlichste Fehlfunktion:
      // geraten wird dafür nie automatisch gesendet.
      final r = parseUtterance(
        'bremsn',
        urgencyOf: (k) => k == 'bremsen' ? Urgency.dringend : Urgency.info,
      );
      expect(r.canAutoSend, isFalse);
    });
  });

  group('Sprechweisen, die im Feldtest durchfielen', () {
    test('zusammengeschriebene Komposita treffen genauso', () {
      // Die Spracherkennung macht aus dem gesprochenen „links abbiegen" gern
      // ein Wort. Beide Formen müssen gehen – sonst funktioniert nur das
      // sperrige „abbiegen links".
      for (final pair in {
        'linksabbiegen': 'abbiegen_links',
        'links abbiegen': 'abbiegen_links',
        'abbiegen links': 'abbiegen_links',
        'rechtsabbiegen': 'abbiegen_rechts',
        'rechts abbiegen': 'abbiegen_rechts',
        'abbiegen rechts': 'abbiegen_rechts',
      }.entries) {
        final r = parseUtterance(pair.key);
        expect(r.key, pair.value, reason: pair.key);
        expect(r.canAutoSend, isTrue, reason: pair.key);
      }
    });

    test('Einordnen trägt die Richtung mit', () {
      for (final pair in {
        'links einordnen': 'einordnen_links',
        'rechts einordnen': 'einordnen_rechts',
        'ordne dich links ein': 'einordnen_links',
        'auf die rechte spur': 'einordnen_rechts',
        // ohne Richtung bleibt es das neutrale Kommando
        'einordnen': 'einordnen',
        'spur wechseln': 'einordnen',
      }.entries) {
        expect(parseUtterance(pair.key).key, pair.value, reason: pair.key);
      }
    });
  });

  group('Ganze Sätze', () {
    test('Kommando im Fließtext wird sicher erkannt', () {
      for (final pair in {
        'so, dann fährst du jetzt bitte mal rechts ran': 'anhalten',
        'du musst noch den Schulterblick machen': 'schulterblick',
        'hier fährst du bitte 30': 't_30',
        'wir machen jetzt mal quer parken': 'gfa_quer',
      }.entries) {
        final r = parseUtterance(pair.key);
        expect(r.key, pair.value, reason: pair.key);
        expect(r.canAutoSend, isTrue, reason: pair.key);
      }
    });

    test('Verneinung innerhalb einer Phrase kippt kein Lob', () {
      expect(parseUtterance('blinker nicht vergessen').key, 'blinker');
      expect(parseUtterance('das war nicht gut').key, 'fehler');
    });
  });

  group('Geplauder löst nie ein Kommando aus', () {
    // Die Gegenprobe zum unscharfen Matching: im Auto wird geredet, und
    // nichts davon darf ungefragt auf dem Schülerschirm landen.
    const chatter = [
      'das wetter ist heute richtig schön',
      'wie war denn deine Woche',
      'hast du am Wochenende schon was vor',
      'ich hab gestern das Auto gewaschen',
      'der Verkehr ist heute echt schlimm',
      'wir haben noch zwanzig Minuten Zeit',
      'das machst du echt gut',
      'nachher wird es bestimmt noch regnen',
      'die Prüfung ist am Dienstag',
      'wie viele Stunden hast du schon',
      'der Motor klingt komisch oder',
      'guck mal der Hund da drüben',
      'das war jetzt aber knapp',
    ];

    for (final s in chatter) {
      test('„$s"', () => expect(parseUtterance(s).canAutoSend, isFalse));
    }
  });

  group('Mehrere Erkennungs-Hypothesen', () {
    test(
      'die treffende Hypothese gewinnt, auch wenn sie nicht die erste ist',
      () {
        final r = parseBestOf(['links ab bigen', 'links abbiegen']);
        expect(r.key, 'abbiegen_links');
      },
    );

    test('trifft keine, sammelt die Rückfrage alle Vorschläge', () {
      final r = parseBestOf(['hup', 'huhe']);
      expect(r.outcome, ParseOutcome.unmatched);
      expect(r.alternatives, contains('hupe'));
    });

    test('leere Liste endet nicht im Fehler', () {
      expect(parseBestOf(const []).outcome, ParseOutcome.unmatched);
    });
  });
}

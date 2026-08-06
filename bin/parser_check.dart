// Eigenständiger Prüflauf für den Parser — läuft mit dem Dart-SDK direkt,
// ohne flutter_test. Ersetzt keine Tests, verifiziert aber sofort.
import 'package:fahrsignal/domain/command_phrases.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/domain/speech/command_parser.dart';

var failures = 0;
var checks = 0;

void expectIntent(
  String utterance, {
  String? key,
  List<String>? extra,
  int ord = 0,
  Urgency? urgency,
  ParseOutcome outcome = ParseOutcome.matched,
  Set<String>? scope,
}) {
  checks++;
  final r = parseUtterance(
    utterance,
    scopeKeys: scope,
    urgencyOf: _urgencyOf,
  );
  final problems = <String>[];
  if (r.outcome != outcome) problems.add('outcome ${r.outcome.name} != ${outcome.name}');
  if (key != null && r.key != key) problems.add('key ${r.key} != $key');
  if (extra != null && r.extraKeys.join(',') != extra.join(',')) {
    problems.add('extra ${r.extraKeys} != $extra');
  }
  if (r.ordinal != ord) problems.add('ord ${r.ordinal} != $ord');
  if (urgency != null && r.urgency != urgency) {
    problems.add('urgency ${r.urgency.name} != ${urgency.name}');
  }
  if (problems.isEmpty) {
    print('  ok   "$utterance" → ${r.key}${r.ordinal > 0 ? " ord=${r.ordinal}" : ""}'
        ' ${r.urgency.name} conf=${r.confidence.toStringAsFixed(2)}'
        '${r.canAutoSend ? " [auto]" : " [rueckfrage]"}');
  } else {
    failures++;
    print('  FAIL "$utterance" → ${problems.join(' | ')}   ($r)');
  }
}

// Urgency-Nachschlag ohne Flutter-Abhängigkeit (Auszug aus dem Katalog).
const _urgencies = <String, Urgency>{
  'kinder': Urgency.dringend,
  'fussgaenger': Urgency.achtung,
  'bremsen': Urgency.dringend,
  'stopp': Urgency.dringend,
  'langsamer': Urgency.achtung,
  'abstand': Urgency.achtung,
  'achtung': Urgency.dringend,
  'hindernis': Urgency.dringend,
};
Urgency _urgencyOf(String key) => _urgencies[key] ?? Urgency.info;

void main() {
  print('\n=== Kernfaelle (vom Nutzer genannt) ===');
  expectIntent('rechts abbiegen', key: 'abbiegen_rechts');
  expectIntent('links abbiegen', key: 'abbiegen_links');
  expectIntent('zweite links', key: 'abbiegen_links', ord: 2);
  expectIntent('zweite strasse links', key: 'abbiegen_links', ord: 2);
  expectIntent('naechste rechts', key: 'abbiegen_rechts', ord: 1);
  expectIntent('dritte ausfahrt', key: 'ausfahrt3');
  expectIntent('zweite ausfahrt', key: 'ausfahrt2');

  print('\n=== Praefix-Enthaltung: laengster Treffer muss gewinnen ===');
  expectIntent('links', key: 'links');
  expectIntent('aussenspiegel links', key: 'aussenspiegel_l');
  expectIntent('stopp', key: 'stopp', urgency: Urgency.dringend);
  expectIntent('stopp schild', key: 'z_stop');
  expectIntent('bremse', key: 'bremse');
  expectIntent('handbremse', key: 'handbremse');
  expectIntent('abstand', key: 'abstand');
  expectIntent('abstandstempomat', key: 'acc');

  print('\n=== "Achtung"-Sonderregel ===');
  expectIntent('achtung', key: 'achtung', urgency: Urgency.dringend);
  // Als Verstaerker: Kommando bleibt fussgaenger, Urgency steigt achtung→dringend
  expectIntent('achtung fussgaenger', key: 'fussgaenger', urgency: Urgency.dringend);
  expectIntent('vorsicht kinder', key: 'kinder', urgency: Urgency.dringend);

  print('\n=== Dringlichkeitsverstaerker ===');
  expectIntent('sofort bremsen', key: 'bremsen', urgency: Urgency.dringend);
  expectIntent('schnell langsamer', key: 'langsamer', urgency: Urgency.dringend);

  print('\n=== Verneinung darf kein Lob senden ===');
  expectIntent('gut gemacht', key: 'lob');
  expectIntent('das war nicht gut', key: 'fehler');

  print('\n=== Kombination ===');
  expectIntent('spiegel und schulterblick', key: 'spiegel', extra: ['schulterblick']);

  print('\n=== Fuellwoerter duerfen nichts ausloesen ===');
  expectIntent('das ist halt so', outcome: ParseOutcome.unmatched);
  expectIntent('ja also dann mal', outcome: ParseOutcome.unmatched);
  expectIntent('wir fahren gleich zum baecker', outcome: ParseOutcome.unmatched);
  expectIntent('', outcome: ParseOutcome.unmatched);

  print('\n=== Ordinal ohne Anker ist kein Ordinal ===');
  expectIntent('beim zweiten mal blinken', key: 'blinker', ord: 0);

  print('\n=== Katalog-Invarianten ===');
  checks++;
  final seen = <String, String>{};
  final collisions = <String>[];
  for (final e in kCommandPhrases.entries) {
    for (final p in e.value) {
      final prev = seen[p];
      if (prev != null && prev != e.key) collisions.add('"$p": $prev vs ${e.key}');
      seen[p] = e.key;
    }
  }
  if (collisions.isEmpty) {
    print('  ok   keine Phrasenkollision (${seen.length} Phrasen)');
  } else {
    failures++;
    print('  FAIL Phrasenkollisionen: ${collisions.join('; ')}');
  }

  checks++;
  final unstable = <String>[];
  for (final e in kCommandPhrases.entries) {
    for (final p in e.value) {
      if (normalizeUtterance(p) != p) unstable.add('${e.key}: "$p" → "${normalizeUtterance(p)}"');
    }
  }
  if (unstable.isEmpty) {
    print('  ok   alle Phrasen sind normalisierungsstabil');
  } else {
    failures++;
    print('  FAIL nicht normalisiert: ${unstable.take(5).join('; ')}');
  }

  print('\n=== JSON-Roundtrip mit ord ===');
  checks++;
  final cmd = DriveCommand.now('abbiegen_links', Urgency.info, ord: 2);
  final back = DriveCommand.fromJson(cmd.toJson());
  final v3 = DriveCommand.fromJson({
    'v': 3, 'keys': ['links'], 'urgency': 'info', 'ts': 1,
  });
  if (back.ord == 2 && v3.ord == 0) {
    print('  ok   ord=2 ueberlebt, v3-Nachricht ohne ord liest als 0');
  } else {
    failures++;
    print('  FAIL ord-Roundtrip: ${back.ord} / ${v3.ord}');
  }

  print('\n${failures == 0 ? "ALLES GRUEN" : "$failures FEHLER"} — $checks Pruefungen\n');
}

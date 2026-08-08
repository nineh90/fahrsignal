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
  bool? ask,
  bool checkAsk = false,
  String? mustSuggest,
  ParseOutcome outcome = ParseOutcome.matched,
}) {
  checks++;
  final r = parseUtterance(utterance, urgencyOf: _urgencyOf);
  final problems = <String>[];
  if (r.outcome != outcome)
    problems.add('outcome ${r.outcome.name} != ${outcome.name}');
  if (key != null && r.key != key) problems.add('key ${r.key} != $key');
  if (extra != null && r.extraKeys.join(',') != extra.join(',')) {
    problems.add('extra ${r.extraKeys} != $extra');
  }
  if (r.ordinal != ord) problems.add('ord ${r.ordinal} != $ord');
  if (urgency != null && r.urgency != urgency) {
    problems.add('urgency ${r.urgency.name} != ${urgency.name}');
  }
  if (checkAsk && r.ask != ask) {
    problems.add('ask ${r.ask} != $ask');
  }
  if (mustSuggest != null && !r.alternatives.contains(mustSuggest)) {
    problems.add('Vorschlaege ${r.alternatives} ohne $mustSuggest');
  }
  if (problems.isEmpty) {
    print(
      '  ok   "$utterance" → ${r.key}${r.ordinal > 0 ? " ord=${r.ordinal}" : ""}'
      ' ${r.urgency.name} conf=${r.confidence.toStringAsFixed(2)}'
      '${r.canAutoSend ? " [auto]" : " [rueckfrage]"}',
    );
  } else {
    failures++;
    print('  FAIL "$utterance" → ${problems.join(' | ')}   ($r)');
  }
}

// Urgency-Nachschlag ohne Flutter-Abhängigkeit (Auszug aus dem Katalog).
const _urgencies = <String, Urgency>{
  'bremsen': Urgency.dringend,
  'stopp': Urgency.dringend,
  'langsamer': Urgency.achtung,
  'abstand': Urgency.achtung,
  'anhalten': Urgency.achtung,
  'hindernis': Urgency.achtung,
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
  expectIntent('bremse', key: 'bremse');
  expectIntent('handbremse', key: 'handbremse');
  expectIntent('abstand', key: 'abstand');
  expectIntent('abstandstempomat', key: 'acc');
  expectIntent('laengs einparken', key: 'gfa_laengs');
  expectIntent('einparken', key: 'gfa_laengs');

  print('\n=== Neue Kommandos aus dem Fahrschul-Feedback ===');
  expectIntent('ampel', key: 'ampel');
  expectIntent('tempo dreissig', key: 't_30');
  expectIntent('fuenfzig', key: 't_50');
  expectIntent('unbegrenzt', key: 't_frei');
  expectIntent('schrittgeschwindigkeit', key: 't_schritt');
  expectIntent('reihenfolge', key: 'reihenfolge');
  expectIntent('rundumblick', key: 'rundumblick');
  expectIntent('nach hinten schauen', key: 'nach_hinten');
  expectIntent('gefahrenbremsung', key: 'gfa_bremsung');
  expectIntent('quer parken', key: 'gfa_quer');
  expectIntent('rechts um die ecke', key: 'gfa_ecke');
  expectIntent('umkehren', key: 'gfa_umkehren');
  // „Gefahr" ist raus: „achtung"/„vorsicht" sind nur noch Verstaerker.
  expectIntent('achtung', outcome: ParseOutcome.unmatched);
  expectIntent('vorsicht bremsen', key: 'bremsen', urgency: Urgency.dringend);

  print('\n=== Dringlichkeitsverstaerker ===');
  expectIntent('sofort bremsen', key: 'bremsen', urgency: Urgency.dringend);
  expectIntent(
    'schnell langsamer',
    key: 'langsamer',
    urgency: Urgency.dringend,
  );
  expectIntent('sofort anhalten', key: 'stopp', urgency: Urgency.dringend);

  print('\n=== Verneinung darf kein Lob senden ===');
  expectIntent('gut gemacht', key: 'lob');
  expectIntent('das war nicht gut', key: 'fehler');

  print('\n=== Kombination ===');
  expectIntent(
    'spiegel und schulterblick',
    key: 'spiegel',
    extra: ['schulterblick'],
  );
  expectIntent('links und danach rechts', key: 'links', extra: ['rechts']);

  print('\n=== Abfrage-/Erklaer-Marker (Fahrzeug-Bereich) ===');
  expectIntent(
    'frag den verbandskasten ab',
    key: 'verbandskasten',
    ask: true,
    checkAsk: true,
  );
  expectIntent(
    'zeig mir die handbremse',
    key: 'handbremse',
    ask: true,
    checkAsk: true,
  );
  expectIntent(
    'erklaere das abblendlicht',
    key: 'abblendlicht',
    ask: false,
    checkAsk: true,
  );
  // Ohne Marker bleibt ask offen — dann entscheidet der Umschalter im Sender.
  expectIntent('verbandskasten', key: 'verbandskasten', checkAsk: true);

  print('\n=== Bereichsunabhaengig: exakte Treffer senden immer ===');
  expectIntent('bremse', key: 'bremse'); // Fahrzeug-Key, auch im Fahrt-Tab
  expectIntent('links', key: 'links'); // Fahrt-Key, auch im Fahrzeug-Tab

  print(
    '\n=== Unscharfe Treffer: Verhoerer duerfen nicht ins Leere laufen ===',
  );
  // Genau der Alltagsfall: die Erkennung verschluckt oder verdreht einen
  // Buchstaben. Frueher: stumme Rueckfrage. Jetzt: erkannt, mit Abschlag.
  expectIntent('warndreiek', key: 'warndreieck');
  expectIntent('schulterblik', key: 'schulterblick');
  expectIntent('gefahrenbremsun', key: 'gfa_bremsung');
  expectIntent('verbandkast', key: 'verbandskasten');
  // Zu kurz zum Raten – bleibt Vorschlag statt Treffer.
  expectIntent('hup', outcome: ParseOutcome.unmatched, mustSuggest: 'hupe');

  print('\n=== Zusammengeschriebene Komposita (so liefert es die ASR) ===');
  expectIntent('linksabbiegen', key: 'abbiegen_links');
  expectIntent('rechtsabbiegen', key: 'abbiegen_rechts');
  expectIntent('du musst hier rechtsabbiegen', key: 'abbiegen_rechts');
  expectIntent('rueckwaertsfahren', key: 'rueckwaerts');
  expectIntent('geradeausfahren', key: 'geradeaus');

  print('\n=== Einordnen traegt die Richtung mit ===');
  expectIntent('links einordnen', key: 'einordnen_links');
  expectIntent('rechts einordnen', key: 'einordnen_rechts');
  expectIntent('linkseinordnen', key: 'einordnen_links');
  expectIntent('ordne dich rechts ein', key: 'einordnen_rechts');
  expectIntent('links einfaedeln', key: 'einordnen_links');
  expectIntent('auf die linke spur', key: 'einordnen_links');
  // Ohne Richtung bleibt es das neutrale Kommando.
  expectIntent('einordnen', key: 'einordnen');
  expectIntent('spur wechseln', key: 'einordnen');

  print('\n=== Ganze Saetze, wie sie im Auto fallen ===');
  expectIntent(
    'so, dann faehrst du jetzt bitte mal rechts ran',
    key: 'anhalten',
  );
  expectIntent(
    'an der naechsten kreuzung rechts',
    key: 'abbiegen_rechts',
    ord: 1,
  );
  expectIntent('du musst noch den schulterblick machen', key: 'schulterblick');
  expectIntent('hier faehrst du bitte 30', key: 't_30');
  expectIntent('wir machen jetzt mal quer parken', key: 'gfa_quer');
  expectIntent('schau kurz in den spiegel', key: 'spiegel');
  // Lob und Mahnung im selben Satz: das „nicht" gehoert zur Phrase und
  // darf das Lob nicht kippen.
  expectIntent('gut gemacht', key: 'lob', extra: []);
  expectIntent('blinker nicht vergessen', key: 'blinker');

  print('\n=== Fuellwoerter duerfen nichts ausloesen ===');
  expectIntent('das ist halt so', outcome: ParseOutcome.unmatched);
  expectIntent('ja also dann mal', outcome: ParseOutcome.unmatched);
  expectIntent(
    'wir fahren gleich zum baecker',
    outcome: ParseOutcome.unmatched,
  );
  expectIntent('', outcome: ParseOutcome.unmatched);

  print('\n=== Mehrere Erkennungs-Hypothesen ===');
  checks++;
  // Beste Hypothese ist Unsinn, die zweite trifft – frueher ging das verloren.
  final multi = parseBestOf(['links ab bigen', 'links abbiegen']);
  if (multi.outcome == ParseOutcome.matched && multi.key == 'abbiegen_links') {
    print('  ok   zweite Hypothese gewinnt → ${multi.key}');
  } else {
    failures++;
    print('  FAIL Hypothesenauswahl: $multi');
  }
  checks++;
  // Trifft keine, sammelt die Rueckfrage die Vorschlaege aus allen.
  final none = parseBestOf(['hup', 'huhe']);
  if (none.outcome == ParseOutcome.unmatched &&
      none.alternatives.contains('hupe')) {
    print('  ok   Vorschlaege aus allen Hypothesen: ${none.alternatives}');
  } else {
    failures++;
    print('  FAIL Hypothesen-Vorschlaege: $none');
  }

  print('\n=== Ordinal ohne Anker ist kein Ordinal ===');
  expectIntent('beim zweiten mal blinken', key: 'blinker', ord: 0);

  print('\n=== Katalog-Invarianten ===');
  checks++;
  final seen = <String, String>{};
  final collisions = <String>[];
  for (final e in kCommandPhrases.entries) {
    for (final p in e.value) {
      final prev = seen[p];
      if (prev != null && prev != e.key)
        collisions.add('"$p": $prev vs ${e.key}');
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
      if (normalizeUtterance(p) != p)
        unstable.add('${e.key}: "$p" → "${normalizeUtterance(p)}"');
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
    'v': 3,
    'keys': ['links'],
    'urgency': 'info',
    'ts': 1,
  });
  if (back.ord == 2 && v3.ord == 0) {
    print('  ok   ord=2 ueberlebt, v3-Nachricht ohne ord liest als 0');
  } else {
    failures++;
    print('  FAIL ord-Roundtrip: ${back.ord} / ${v3.ord}');
  }

  print(
    '\n${failures == 0 ? "ALLES GRUEN" : "$failures FEHLER"} — $checks Pruefungen\n',
  );
}

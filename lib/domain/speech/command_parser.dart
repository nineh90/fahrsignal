/// Übersetzt einen erkannten Satz in eine strukturierte Fahranweisung.
///
/// **Reines Dart** – kein Flutter, kein Mikrofon, keine Plattform. Damit ist
/// die gesamte Sprachlogik ohne Gerät testbar; die Spracherkennung liefert nur
/// einen String und eine Konfidenz hinein.
///
/// Bewusst deterministisch und erklärbar statt „schlau": Phrasen aus dem
/// Katalog entscheiden, was gesendet wird.
///
/// Der Abgleich läuft in drei Stufen, jede unsicherer als die vorige – und
/// jede Stufe drückt die Konfidenz, sodass Unsicheres von selbst in der
/// Rückfrage landet statt auf dem Schülerschirm:
/// 1. **wörtlich**, längster Treffer gewinnt (`links abbiegen` schlägt `links`)
/// 2. **unscharf** über Editierdistanz, wenn wörtlich nichts passt – fängt
///    Verhörer der Spracherkennung („Blinke" → `blinker`)
/// 3. **Vorschläge** in der Rückfrage, wenn auch das nichts hergibt
///
/// Für `Urgency.dringend` gilt durchgehend eine höhere Hürde: ein fälschlich
/// rot aufleuchtender Schirm ist die gefährlichste Fehlfunktion des Systems.
library;

import '../command_phrases.dart';
import '../drive_command.dart';

/// Ergebnisklasse einer Äußerung.
enum ParseOutcome {
  /// Eindeutiger Treffer – darf (ab Schwellwert) direkt gesendet werden.
  matched,

  /// Mehrere gleich plausible Kandidaten – der Fahrlehrer muss wählen.
  ambiguous,

  /// Kein Kommando erkannt – Rückfallebene Freitext.
  unmatched,
}

/// Ab dieser Konfidenz geht ein Kommando ohne Rückfrage raus.
const double kAutoSendThreshold = 0.72;

/// Für `Urgency.dringend` gilt eine höhere Hürde: ein fälschlich rot
/// aufleuchtender Schirm ist die gefährlichste Fehlfunktion des Systems.
const double kAutoSendThresholdUrgent = 0.85;

/// Darunter gilt eine Äußerung als nicht erkannt.
const double kMinConfidence = 0.35;

/// Vertrauensboden für einen **wörtlichen Volltreffer ohne Beiwerk**: die
/// gemeldete Konfidenz der Spracherkennung wird dann auf diesen Wert gehoben.
/// Bewusst über [kAutoSendThresholdUrgent] – „Stopp" muss sofort raus.
const double kCleanHitConfidence = 0.95;

/// Das Ergebnis einer geparsten Äußerung.
class ParsedIntent {
  final ParseOutcome outcome;

  /// Primärer Katalog-Key; null bei [ParseOutcome.unmatched].
  final String? key;

  /// Weitere Keys derselben Äußerung („Spiegel und Schulterblick").
  final List<String> extraKeys;

  /// Ordnungszahl als Attribut; 0 = keine.
  final int ordinal;

  /// Dringlichkeit nach Anwendung etwaiger Verstärker.
  final Urgency urgency;

  /// Gesprochener Abfrage-/Erklär-Marker: true = „frag … ab", false =
  /// „erkläre …", null = nichts gesagt (dann entscheidet der Umschalter).
  final bool? ask;

  final double confidence;

  /// Ursprünglicher Text – Rückfallebene für Freitext.
  final String transcript;

  /// Normalisierte Form, die dem Abgleich zugrunde lag (Diagnose/Tests).
  final String normalized;

  /// Bei [ParseOutcome.ambiguous]: gleichrangige Alternativen zur Auswahl.
  final List<String> alternatives;

  const ParsedIntent({
    required this.outcome,
    required this.transcript,
    required this.normalized,
    this.key,
    this.extraKeys = const [],
    this.ordinal = 0,
    this.urgency = Urgency.info,
    this.ask,
    this.confidence = 0,
    this.alternatives = const [],
  });

  /// Alle Keys in Sendereihenfolge (primär zuerst).
  List<String> get allKeys => [?key, ...extraKeys];

  bool get isCombo => extraKeys.isNotEmpty;

  /// Darf dieses Ergebnis ohne Rückfrage gesendet werden?
  ///
  /// Der Aufrufer entscheidet damit zwischen „sofort raus" und
  /// „Kandidaten zur Auswahl anbieten" – bewusst hier und nicht in der UI,
  /// damit die Schwelle testbar bleibt.
  bool get canAutoSend {
    if (outcome != ParseOutcome.matched) return false;
    final threshold = urgency == Urgency.dringend
        ? kAutoSendThresholdUrgent
        : kAutoSendThreshold;
    return confidence >= threshold;
  }

  /// Baut die sendefertige Anweisung. Nur bei [ParseOutcome.matched] sinnvoll.
  /// [asAsk] ist die aufgelöste Abfrage-Entscheidung (gesprochener Marker
  /// bzw. Umschalter) – der Aufrufer prüft vorher, ob das Kommando überhaupt
  /// eine Erklärung hat.
  DriveCommand toCommand({bool asAsk = false}) => isCombo
      ? DriveCommand.combo(allKeys, urgency, ord: ordinal)
      : DriveCommand.now(key!, urgency, ord: ordinal, ask: asAsk);

  @override
  String toString() =>
      'ParsedIntent(${outcome.name}, keys=$allKeys, ord=$ordinal, '
      '${urgency.name}, ask=$ask, conf=${confidence.toStringAsFixed(2)})';
}

// ---------------------------------------------------------------------------
// Normalisierung
// ---------------------------------------------------------------------------

/// Bringt eine Äußerung auf die Form, in der die Phrasentabelle steht:
/// kleingeschrieben, Umlaute aufgelöst, ohne Satzzeichen, einfache Leerzeichen.
///
/// Ziffernordinale („2.") werden zu Wörtern („zweite"), weil die
/// Spracherkennung je nach Laune das eine oder das andere liefert.
String normalizeUtterance(String input) {
  var s = input.toLowerCase();

  const umlauts = {
    'ä': 'ae',
    'ö': 'oe',
    'ü': 'ue',
    'ß': 'ss',
    'á': 'a',
    'à': 'a',
    'é': 'e',
    'è': 'e',
  };
  umlauts.forEach((from, to) => s = s.replaceAll(from, to));

  // „2." / „2" vor einem Zählnomen → Ordinalwort.
  const digitWords = {1: 'erste', 2: 'zweite', 3: 'dritte', 4: 'vierte'};
  digitWords.forEach((digit, word) {
    s = s.replaceAll(RegExp('\\b$digit\\.'), word);
  });

  // Alles außer Buchstaben/Ziffern/Leerzeichen entfernen.
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return s;

  // Zahlwörter → Ziffern. Die Erkennung liefert dasselbe Gesagte mal als
  // „Tempo 30", mal als „Tempo dreißig"; kanonisch ist die Ziffer, und die
  // Phrasentabelle steht entsprechend da.
  return s.split(' ').map((t) => kNumberWords[t] ?? t).join(' ');
}

// ---------------------------------------------------------------------------
// Phrasenindex
// ---------------------------------------------------------------------------

/// Phrase → Key. Lazy gebaut; bei kollidierenden Phrasen gewinnt die erste,
/// aber ein Invariantentest verbietet solche Kollisionen von vornherein.
Map<String, String>? _phraseIndex;
int _maxPhraseTokens = 1;

/// Wortanzahl → Phrasen dieser Länge. Der unscharfe Abgleich vergleicht ein
/// Fenster nur mit gleich langen Phrasen – das hält ihn schnell *und* schützt
/// davor, dass „links" gegen „links abbiegen" antritt.
final Map<int, List<MapEntry<String, String>>> _phrasesByTokens = {};

Map<String, String> _index() {
  if (_phraseIndex != null) return _phraseIndex!;
  final idx = <String, String>{};
  for (final entry in kCommandPhrases.entries) {
    for (final phrase in entry.value) {
      idx.putIfAbsent(phrase, () => entry.key);
      final n = phrase.split(' ').length;
      if (n > _maxPhraseTokens) _maxPhraseTokens = n;
      (_phrasesByTokens[n] ??= []).add(MapEntry(phrase, entry.key));
    }
  }
  _phraseIndex = idx;
  return idx;
}

/// Nur für Tests: erzwingt einen Neuaufbau des Index.
void resetPhraseIndexForTest() {
  _phraseIndex = null;
  _maxPhraseTokens = 1;
  _phrasesByTokens.clear();
}

/// Ein Treffer im Tokenstrom.
class _Hit {
  final String key;
  final int start;
  final int length;

  /// 1,0 = wörtlich getroffen, darunter = unscharf (Ähnlichkeit 0..1).
  final double score;

  const _Hit(this.key, this.start, this.length, [this.score = 1.0]);
}

// ---------------------------------------------------------------------------
// Unscharfer Abgleich
// ---------------------------------------------------------------------------

/// Ab dieser Ähnlichkeit gilt ein Wortfenster als (unscharf) erkannt.
///
/// 0,8 lässt Erkennungs- und Beugungsfehler durch („blinke"→„blinker",
/// „schulterblik"→„schulterblick"), hält aber echte Nachbarn auseinander:
/// „links"/„rechts" liegen bei 0,33, „parken"/„funken" bei 0,67.
const double kFuzzyMatchThreshold = 0.8;

/// Ein unscharfer Treffer muss den nächstbesten *anderen* Kandidaten um so
/// viel schlagen. Sonst ist die Lage mehrdeutig und wir raten lieber nicht.
const double kFuzzyMargin = 0.08;

/// Kürzere Fenster werden nicht unscharf verglichen – bei drei Buchstaben
/// ist jede zweite Verwechslung „ähnlich genug".
const int kFuzzyMinChars = 5;

/// Bester unscharfer Treffer für das Fenster ab [start].
///
/// Sucht wie der exakte Abgleich von lang nach kurz: das erste Fenster mit
/// einem **eindeutigen** Kandidaten gewinnt. Liefert null, wenn nichts nah
/// genug dran ist oder zwei Bedeutungen zu dicht beieinanderliegen.
_Hit? _fuzzyHit(List<String> tokens, int start, int maxLen) {
  for (var len = maxLen; len >= 1; len--) {
    final candidate = tokens.sublist(start, start + len).join(' ');
    if (candidate.length < kFuzzyMinChars) continue;
    // Ein bloßes Füllwort darf nie unscharf zum Kommando werden.
    if (len == 1 && kFillerWords.contains(candidate)) continue;

    final bestPerKey = <String, double>{};
    for (final entry
        in _phrasesByTokens[len] ?? const <MapEntry<String, String>>[]) {
      final phrase = entry.key;
      final maxChars = candidate.length > phrase.length
          ? candidate.length
          : phrase.length;
      // Die Längendifferenz allein kann die Schwelle schon reißen.
      if ((candidate.length - phrase.length).abs() / maxChars >
          1 - kFuzzyMatchThreshold) {
        continue;
      }
      final sim = 1 - _levenshtein(candidate, phrase) / maxChars;
      if (sim < kFuzzyMatchThreshold) continue;
      final prev = bestPerKey[entry.value];
      if (prev == null || sim > prev) bestPerKey[entry.value] = sim;
    }

    if (bestPerKey.isEmpty) continue;
    final ranked = bestPerKey.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.length > 1 && ranked[0].value - ranked[1].value < kFuzzyMargin) {
      continue; // mehrdeutig – lieber die Rückfrage
    }
    return _Hit(ranked[0].key, start, len, ranked[0].value);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

/// Übersetzt [transcript] in eine [ParsedIntent].
///
/// [asrConfidence] ist die Konfidenz der Spracherkennung (0..1). Eine
/// Bereichs-Eingrenzung gibt es bewusst nicht mehr: Was exakt erkannt wurde,
/// wird ausgeführt, egal welcher Tab im Sender offen ist – Rückfragen sind
/// unklarer Erkennung vorbehalten.
///
/// [provisional] markiert ein Zwischenergebnis, das sich noch ändern kann.
/// Solche Äußerungen bekommen den Vertrauensboden für saubere Treffer
/// ([kCleanHitConfidence]) **nicht** und landen damit in der Rückfrage.
ParsedIntent parseUtterance(
  String transcript, {
  double asrConfidence = 1.0,
  bool provisional = false,
  Urgency Function(String key)? urgencyOf,
}) {
  final normalized = normalizeUtterance(transcript);
  if (normalized.isEmpty) {
    return ParsedIntent(
      outcome: ParseOutcome.unmatched,
      transcript: transcript,
      normalized: normalized,
    );
  }

  final tokens = normalized.split(' ');
  final index = _index();

  // --- 1. Längster Treffer gewinnt -----------------------------------------
  // Löst sämtliche Präfix-Enthaltungen mechanisch: „aussenspiegel links"
  // schlägt „links", „laengs einparken" schlägt „einparken", „handbremse"
  // schlägt „bremse". Ohne diese Regel wäre die Erkennung im Auto unbrauchbar.
  final hits = <_Hit>[];
  final consumed = List<bool>.filled(tokens.length, false);

  var i = 0;
  while (i < tokens.length) {
    var matched = false;
    final maxLen = _maxPhraseTokens.clamp(1, tokens.length - i);
    for (var len = maxLen; len >= 1; len--) {
      final candidate = tokens.sublist(i, i + len).join(' ');
      final key = index[candidate];
      if (key != null) {
        hits.add(_Hit(key, i, len));
        for (var k = i; k < i + len; k++) {
          consumed[k] = true;
        }
        i += len;
        matched = true;
        break;
      }
    }
    if (matched) continue;

    // Nichts wörtlich getroffen → zweiter Anlauf mit Ähnlichkeit. Das ist
    // der Unterschied zwischen „Blinke" (Erkennungsfehler, gemeint war der
    // Blinker) und einer stummen Rückfrage. Der Treffer trägt seinen Score
    // mit und drückt später die Konfidenz – Unsicheres landet dadurch von
    // selbst in der Bestätigung statt sofort auf dem Schülerschirm.
    final fuzzy = _fuzzyHit(tokens, i, maxLen);
    if (fuzzy != null) {
      hits.add(fuzzy);
      for (var k = i; k < i + fuzzy.length; k++) {
        consumed[k] = true;
      }
      i += fuzzy.length;
      continue;
    }
    i++;
  }

  // --- 2. Freie Token auswerten --------------------------------------------
  // Verstärker und Verneinungen werden ebenfalls *verstanden* und zählen
  // deshalb zur Abdeckung. Täten sie das nicht, würde ausgerechnet
  // „sofort bremsen" schlechter bewertet als „bremsen" – und damit in der
  // Rückfrage landen statt sofort rauszugehen.
  // Nur *freie* Verneinungen zählen: das „nicht" in „blinker nicht vergessen"
  // gehört zur erkannten Phrase und darf kein Lob im selben Satz kippen.
  final hasNegation = [
    for (var k = 0; k < tokens.length; k++)
      if (!consumed[k]) tokens[k],
  ].any(kNegationWords.contains);
  var boosted = false;
  bool? ask;

  for (var k = 0; k < tokens.length; k++) {
    if (consumed[k]) continue;
    final t = tokens[k];
    if (kUrgencyBoosters.contains(t)) {
      boosted = true;
      consumed[k] = true;
    } else if (kNegationWords.contains(t)) {
      consumed[k] = true;
    } else if (kAskMarkers.contains(t)) {
      // „frag … ab" / „zeig mir …" → als Abfrage senden.
      ask = true;
      consumed[k] = true;
    } else if (kExplainMarkers.contains(t)) {
      // „erkläre …" schlägt den Umschalter in Richtung Erklärung.
      ask = false;
      consumed[k] = true;
    }
  }

  // --- 3. Ordnungszahl ------------------------------------------------------
  var ordinal = 0;
  for (var k = 0; k < tokens.length; k++) {
    final value = kOrdinalWords[tokens[k]];
    if (value == null) continue;
    // Nur mit Anker in Reichweite: „zweite Straße links" ja,
    // „das zweite Mal" nein.
    final windowEnd = (k + 3).clamp(0, tokens.length);
    final anchorOffset = tokens
        .sublist(k + 1, windowEnd)
        .indexWhere(kOrdinalAnchors.contains);
    if (anchorOffset >= 0) {
      ordinal = value;
      consumed[k] = true;
      // Das Zählnomen („zweite **Straße** links") ist mitverstanden.
      consumed[k + 1 + anchorOffset] = true;
      break;
    }
  }

  // --- 4. Kein Treffer → Ähnlichkeits-Vorschläge + Freitext ----------------
  // „hup" statt „hupe" soll nicht im Nichts enden: die nächstliegenden
  // Katalogphrasen kommen als Vorschläge in die Rückfrage. Gesendet wird
  // davon nichts automatisch.
  if (hits.isEmpty) {
    final residual = [
      for (var k = 0; k < tokens.length; k++)
        if (!consumed[k] && !kFillerWords.contains(tokens[k])) tokens[k],
    ].join(' ');
    return ParsedIntent(
      outcome: ParseOutcome.unmatched,
      transcript: transcript,
      normalized: normalized,
      ask: ask,
      alternatives: fuzzySuggestions(residual),
      confidence: 0,
    );
  }

  // --- 5. Ordnungszahl auflösen --------------------------------------------
  // Entweder ersetzt sie den Key („zweite Ausfahrt" → ausfahrt2) oder sie
  // wird Attribut („zweite Straße links" → abbiegen_links mit ord=2).
  var keys = hits.map((h) => h.key).toList();
  var attributeOrdinal = 0;

  if (ordinal > 0) {
    final primary = keys.first;
    final ordinalFamily = kOrdinalKeys.entries
        .where((e) => e.value.containsValue(primary))
        .firstOrNull;
    if (ordinalFamily != null) {
      keys[0] = ordinalFamily.value[ordinal] ?? primary;
    } else if (kOrdinalCapable.contains(primary)) {
      attributeOrdinal = ordinal;
    } else if (primary == 'links' || primary == 'rechts') {
      // „zweite links" ohne Verb meint das Abbiegen, nicht die Seite.
      keys[0] = primary == 'links' ? 'abbiegen_links' : 'abbiegen_rechts';
      attributeOrdinal = ordinal;
    }
  }

  // --- 6. Verneinung schützt vor gegenteiligem Lob -------------------------
  if (hasNegation) {
    keys = keys.where((k) => !kPositiveFeedbackKeys.contains(k)).toList();
    if (keys.isEmpty) {
      return ParsedIntent(
        outcome: ParseOutcome.unmatched,
        transcript: transcript,
        normalized: normalized,
        ask: ask,
      );
    }
  }

  // Höchstens drei Kommandos – gleiche Grenze wie im Kombi-Modus der Tasten.
  if (keys.length > 3) keys = keys.sublist(0, 3);

  // --- 7. Dringlichkeit -----------------------------------------------------
  var urgency = Urgency.info;
  if (urgencyOf != null) {
    final urgencies = keys.map(urgencyOf).toList();
    urgency = urgencies.reduce((a, b) => a.index >= b.index ? a : b);
  }
  if (boosted && urgency.index < Urgency.dringend.index) {
    urgency = Urgency.values[urgency.index + 1];
  }

  // --- 8. Konfidenz ---------------------------------------------------------
  // Anteil der Äußerung, der tatsächlich verstanden wurde. Wer viel redet und
  // wenig Erkanntes trifft, bekommt eine Rückfrage statt eines Sendevorgangs.
  final consumedCount = consumed.where((c) => c).length;
  final meaningful = tokens.where((t) => !kFillerWords.contains(t)).length;
  final coverage = meaningful == 0
      ? 0.0
      : (consumedCount / meaningful).clamp(0.0, 1.0);

  // Der schwächste Treffer bestimmt die Sicherheit der ganzen Äußerung:
  // eine Kombination ist nur so gut wie ihr wackeligstes Glied.
  final matchScore = hits.map((h) => h.score).reduce((a, b) => a < b ? a : b);

  // Wörtlich getroffen, nichts Unverstandenes drumherum: dann ist die Deutung
  // eindeutig – auch wenn die Spracherkennung selbst niedrig meldet. Chrome
  // liefert dort notorisch 0 oder Fantasiewerte, und ohne diesen Boden landete
  // ausgerechnet ein klar gerufenes „Stopp" in der Rückfrage, weil für
  // `dringend` die höhere Hürde gilt.
  final clean = !provisional && coverage >= 1.0 && matchScore >= 1.0;
  final asr = clean && asrConfidence < kCleanHitConfidence
      ? kCleanHitConfidence
      : asrConfidence;

  final confidence = asr * (0.45 + 0.55 * coverage) * matchScore;

  if (confidence < kMinConfidence) {
    // Zu unsicher zum Senden – aber das Erkannte als Vorschlag anbieten,
    // statt es zu verschlucken.
    return ParsedIntent(
      outcome: ParseOutcome.unmatched,
      transcript: transcript,
      normalized: normalized,
      ask: ask,
      alternatives: keys.take(3).toList(),
      confidence: confidence,
    );
  }

  return ParsedIntent(
    outcome: ParseOutcome.matched,
    key: keys.first,
    extraKeys: keys.skip(1).toList(),
    ordinal: attributeOrdinal,
    urgency: urgency,
    ask: ask,
    confidence: confidence,
    transcript: transcript,
    normalized: normalized,
  );
}

/// Wertet **alle** Hypothesen der Spracherkennung aus und liefert die beste.
///
/// Die Web Speech API gibt bis zu drei Deutungen desselben Gesagten zurück
/// („links abbiegen" / „Linksabbiegen" / „Lings abbiegen"). Bisher zählte nur
/// die erste – dabei steht das gesuchte Kommando oft wörtlich in Hypothese 2.
/// Frühere Hypothesen sind laut Erkennung wahrscheinlicher und bekommen
/// deshalb einen kleinen Vorsprung ([_hypothesisPenalty] je Rang).
///
/// Trifft keine, kommt die erste Hypothese zurück – aber mit den
/// **vereinigten** Vorschlägen aller, damit die Rückfrage möglichst viel
/// anzubieten hat.
ParsedIntent parseBestOf(
  List<String> transcripts, {
  double asrConfidence = 1.0,
  bool provisional = false,
  Urgency Function(String key)? urgencyOf,
}) {
  final candidates = transcripts
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (candidates.isEmpty) {
    return parseUtterance(
      '',
      asrConfidence: asrConfidence,
      provisional: provisional,
      urgencyOf: urgencyOf,
    );
  }

  final parsed = [
    for (final t in candidates)
      parseUtterance(
        t,
        asrConfidence: asrConfidence,
        provisional: provisional,
        urgencyOf: urgencyOf,
      ),
  ];

  ParsedIntent? best;
  var bestRank = double.negativeInfinity;
  for (var i = 0; i < parsed.length; i++) {
    if (parsed[i].outcome != ParseOutcome.matched) continue;
    final rank = parsed[i].confidence - i * _hypothesisPenalty;
    if (rank > bestRank) {
      bestRank = rank;
      best = parsed[i];
    }
  }
  if (best != null) return best;

  final suggestions = <String>{for (final p in parsed) ...p.alternatives};
  final first = parsed.first;
  return ParsedIntent(
    outcome: first.outcome,
    key: first.key,
    extraKeys: first.extraKeys,
    ordinal: first.ordinal,
    urgency: first.urgency,
    ask: first.ask,
    confidence: first.confidence,
    transcript: first.transcript,
    normalized: first.normalized,
    alternatives: suggestions.take(3).toList(),
  );
}

/// Abschlag je Rang in der Hypothesenliste der Spracherkennung.
const double _hypothesisPenalty = 0.04;

// ---------------------------------------------------------------------------
// Ähnlichkeits-Vorschläge (nur Rückfrage, nie Auto-Send)
// ---------------------------------------------------------------------------

/// Ab dieser Ähnlichkeit (1 − Editierdistanz/Länge) wird eine Phrase
/// vorgeschlagen. 0,6 lässt „hup"→„hupe" und „stob"→„stopp" durch, hält aber
/// zufällige Kurzwort-Treffer draußen.
const double kSuggestThreshold = 0.6;

/// Nächstliegende Katalog-Keys zu einer nicht exakt erkannten Äußerung,
/// bestpassende zuerst (max. 3, je Key nur einmal).
List<String> fuzzySuggestions(String utterance) {
  final s = utterance.trim();
  if (s.length < 3) return const [];

  final bestPerKey = <String, double>{};
  for (final entry in _index().entries) {
    final phrase = entry.key;
    if (phrase.length < 3) continue;
    // Editierdistanz kann die Längendifferenz nie unterschreiten – so
    // entfallen aussichtslose Vergleiche, bevor gerechnet wird.
    final maxLen = s.length > phrase.length ? s.length : phrase.length;
    if ((s.length - phrase.length).abs() / maxLen > 1 - kSuggestThreshold) {
      continue;
    }
    final sim = 1 - _levenshtein(s, phrase) / maxLen;
    if (sim < kSuggestThreshold) continue;
    final prev = bestPerKey[entry.value];
    if (prev == null || sim > prev) bestPerKey[entry.value] = sim;
  }

  final ranked = bestPerKey.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in ranked.take(3)) e.key];
}

/// Klassische Levenshtein-Distanz mit zwei Zeilen Speicher.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (j) => j);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1, // Einfügen
        prev[j] + 1, // Löschen
        prev[j - 1] + cost, // Ersetzen
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

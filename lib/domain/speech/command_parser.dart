/// Übersetzt einen erkannten Satz in eine strukturierte Fahranweisung.
///
/// **Reines Dart** – kein Flutter, kein Mikrofon, keine Plattform. Damit ist
/// die gesamte Sprachlogik ohne Gerät testbar; die Spracherkennung liefert nur
/// einen String und eine Konfidenz hinein.
///
/// Bewusst deterministisch und erklärbar statt „schlau": kein Fuzzy-Matching,
/// keine Statistik. Wenn im Auto etwas falsch erkannt wird, muss man in einer
/// Tabelle nachsehen können, warum – und es dort korrigieren.
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
  DriveCommand toCommand() => isCombo
      ? DriveCommand.combo(allKeys, urgency, ord: ordinal)
      : DriveCommand.now(key!, urgency, ord: ordinal);

  @override
  String toString() =>
      'ParsedIntent(${outcome.name}, keys=$allKeys, ord=$ordinal, '
      '${urgency.name}, conf=${confidence.toStringAsFixed(2)})';
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
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

// ---------------------------------------------------------------------------
// Phrasenindex
// ---------------------------------------------------------------------------

/// Phrase → Key. Lazy gebaut; bei kollidierenden Phrasen gewinnt die erste,
/// aber ein Invariantentest verbietet solche Kollisionen von vornherein.
Map<String, String>? _phraseIndex;
int _maxPhraseTokens = 1;

Map<String, String> _index() {
  if (_phraseIndex != null) return _phraseIndex!;
  final idx = <String, String>{};
  for (final entry in kCommandPhrases.entries) {
    for (final phrase in entry.value) {
      idx.putIfAbsent(phrase, () => entry.key);
      final n = phrase.split(' ').length;
      if (n > _maxPhraseTokens) _maxPhraseTokens = n;
    }
  }
  _phraseIndex = idx;
  return idx;
}

/// Nur für Tests: erzwingt einen Neuaufbau des Index.
void resetPhraseIndexForTest() {
  _phraseIndex = null;
  _maxPhraseTokens = 1;
}

/// Ein Treffer im Tokenstrom.
class _Hit {
  final String key;
  final int start;
  final int length;
  const _Hit(this.key, this.start, this.length);
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

/// Übersetzt [transcript] in eine [ParsedIntent].
///
/// [asrConfidence] ist die Konfidenz der Spracherkennung (0..1);
/// [scopeKeys] sind die Keys des aktuell im Sender gewählten Bereichs – Treffer
/// außerhalb werden abgewertet, aber nicht ausgeschlossen (so bleibt „Felgen"
/// im Fahrzeugmodus erreichbar, verliert im Fahrtmodus aber gegen „folgen").
ParsedIntent parseUtterance(
  String transcript, {
  double asrConfidence = 1.0,
  Set<String>? scopeKeys,
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
  // schlägt „links", „stopp schild" schlägt „stopp", „handbremse" schlägt
  // „bremse". Ohne diese Regel wäre die Erkennung im Auto unbrauchbar.
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
    if (!matched) i++;
  }

  // --- 2. Freie Token auswerten --------------------------------------------
  // Verstärker und Verneinungen werden ebenfalls *verstanden* und zählen
  // deshalb zur Abdeckung. Täten sie das nicht, würde ausgerechnet
  // „sofort bremsen" schlechter bewertet als „bremsen" – und damit in der
  // Rückfrage landen statt sofort rauszugehen.
  final hasNegation = tokens.any(kNegationWords.contains);
  var boosted = false;

  for (var k = 0; k < tokens.length; k++) {
    if (consumed[k]) continue;
    final t = tokens[k];
    if (kUrgencyBoosters.contains(t)) {
      boosted = true;
      consumed[k] = true;
    } else if (kNegationWords.contains(t)) {
      consumed[k] = true;
    }
  }

  // --- 3. „Achtung"-Sonderregel --------------------------------------------
  // „Achtung" ist Füllwort *und* Kommandoname. Als Kommando gilt es nur,
  // wenn nichts anderes erkannt wurde; sonst verstärkt es das Erkannte.
  final contentHits = hits.where((h) => h.key != 'achtung').toList();
  if (contentHits.length != hits.length && contentHits.isNotEmpty) {
    boosted = true;
    hits
      ..clear()
      ..addAll(contentHits);
  }

  // --- 4. Ordnungszahl ------------------------------------------------------
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

  // --- 5. Kein Treffer → Freitext ------------------------------------------
  if (hits.isEmpty) {
    return ParsedIntent(
      outcome: ParseOutcome.unmatched,
      transcript: transcript,
      normalized: normalized,
      confidence: 0,
    );
  }

  // --- 6. Ordnungszahl auflösen --------------------------------------------
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

  // --- 7. Verneinung schützt vor gegenteiligem Lob -------------------------
  if (hasNegation) {
    keys = keys.where((k) => !kPositiveFeedbackKeys.contains(k)).toList();
    if (keys.isEmpty) {
      return ParsedIntent(
        outcome: ParseOutcome.unmatched,
        transcript: transcript,
        normalized: normalized,
      );
    }
  }

  // Höchstens drei Kommandos – gleiche Grenze wie im Kombi-Modus der Tasten.
  if (keys.length > 3) keys = keys.sublist(0, 3);

  // --- 8. Dringlichkeit -----------------------------------------------------
  var urgency = Urgency.info;
  if (urgencyOf != null) {
    final urgencies = keys.map(urgencyOf).toList();
    urgency = urgencies.reduce((a, b) => a.index >= b.index ? a : b);
  }
  if (boosted && urgency.index < Urgency.dringend.index) {
    urgency = Urgency.values[urgency.index + 1];
  }

  // --- 9. Konfidenz ---------------------------------------------------------
  // Anteil der Äußerung, der tatsächlich verstanden wurde. Wer viel redet und
  // wenig Erkanntes trifft, bekommt eine Rückfrage statt eines Sendevorgangs.
  final consumedCount = consumed.where((c) => c).length;
  final meaningful = tokens.where((t) => !kFillerWords.contains(t)).length;
  final coverage = meaningful == 0
      ? 0.0
      : (consumedCount / meaningful).clamp(0.0, 1.0);

  var confidence = asrConfidence * (0.45 + 0.55 * coverage);

  // Treffer außerhalb des gewählten Bereichs sind plausibel, aber weniger
  // wahrscheinlich – halbieren statt ausschließen.
  if (scopeKeys != null && !scopeKeys.contains(keys.first)) {
    confidence *= 0.5;
  }

  if (confidence < kMinConfidence) {
    return ParsedIntent(
      outcome: ParseOutcome.unmatched,
      transcript: transcript,
      normalized: normalized,
      confidence: confidence,
    );
  }

  return ParsedIntent(
    outcome: ParseOutcome.matched,
    key: keys.first,
    extraKeys: keys.skip(1).toList(),
    ordinal: attributeOrdinal,
    urgency: urgency,
    confidence: confidence,
    transcript: transcript,
    normalized: normalized,
  );
}

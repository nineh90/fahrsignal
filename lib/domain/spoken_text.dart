import 'command_catalog.dart';
import 'command_phrases.dart';
import 'drive_command.dart';
import 'voice_phrases.dart';

/// Eine Ansage: Text und die Sprache, in der er gesprochen wird.
class Utterance {
  final String text;

  /// BCP-47-Locale für die Sprachsynthese, z. B. `de-DE`.
  final String locale;

  const Utterance(this.text, this.locale);

  @override
  bool operator ==(Object other) =>
      other is Utterance && other.text == text && other.locale == locale;

  @override
  int get hashCode => Object.hash(text, locale);

  @override
  String toString() => 'Utterance($locale: "$text")';
}

/// Die deutsche Ansage zu einer Anweisung (SAR-121) – genau das Wort, das auf
/// dem Schirm steht, damit Bild und Ton nicht zwei Ansagen machen.
///
/// Sie ist zugleich der **Rückfall** für jede andere Sprache: Freitext lässt
/// sich nicht übersetzen, und ein Gerät ohne türkische Stimme soll lieber
/// deutsch sprechen als schweigen. `null` heißt nichts sagen ('off').
Utterance? spokenGerman(DriveCommand c) {
  if (c.isOff) return null;
  const de = 'de-DE';
  if (c.isFreitext) return Utterance(c.text, de);

  final text = [
    displayLabel(c),
    for (final k in c.keys.skip(1)) commandByKey(k)?.label ?? k,
  ].map(_speakable).join(', ');

  // Abfrage: die Lösung steht nicht auf dem Schirm, also auch nicht im Ohr.
  // Die Erklärung selbst wird nicht vorgelesen – zu lang für die Fahrt.
  return Utterance(c.ask ? 'Zeige mir: $text' : text, de);
}

/// Die Ansage in der Sprache, die der Fahrlehrer gewählt hat, oder `null`,
/// wenn sie sich nicht übersetzen lässt – dann gilt [spokenGerman].
Utterance? spokenIn(VoiceLanguage lang, DriveCommand c) {
  if (lang == VoiceLanguage.de) return spokenGerman(c);
  if (c.isOff || c.isFreitext) return null;
  final phrases = kVoicePhrases[lang];
  if (phrases == null) return null;

  final parts = <String>[];
  for (final (i, k) in c.keys.indexed) {
    // Die Ordnungszahl gehört zum primären Kommando.
    final p = i == 0 && c.hasOrdinal
        ? (kOrdinalNoun.containsKey(k)
              ? voiceOrdinalTurn(lang, c.ord, right: k.endsWith('rechts'))
              : null)
        : phrases[k];
    // Ein unübersetzbarer Teil: lieber alles deutsch als halb.
    if (p == null) return null;
    parts.add(p);
  }
  final text = parts.join(lang == VoiceLanguage.ar ? '، ' : ', ');
  return Utterance(c.ask ? '${kVoiceAsk[lang]}: $text' : text, lang.locale);
}

/// Was der Empfänger zu [c] sagt: `null` = schweigen (und eine laufende
/// Ansage abbrechen). Stumm, solange der Fahrlehrer keine Sprache gewählt hat.
({Utterance say, Utterance fallback})? announcementFor(DriveCommand c) {
  if (c.voice.isEmpty) return null;
  final de = spokenGerman(c);
  if (de == null) return null;
  final lang = VoiceLanguage.byCode(c.voice);
  final say = lang == null ? de : (spokenIn(lang, c) ?? de);
  return (say: say, fallback: de);
}

const _ordinals = [
  'erste',
  'zweite',
  'dritte',
  'vierte',
  'fünfte',
  'sechste',
  'siebte',
  'achte',
  'neunte',
];

/// „2. Straße links" → „zweite Straße links". Die Sprach-Engines lesen die
/// Ziffer mit Punkt je nach Gerät als „zwei Punkt" – im Auto unbrauchbar.
String _speakable(String label) => label.replaceAllMapped(
  RegExp(r'\b([1-9])\.\s'),
  (m) => '${_ordinals[int.parse(m[1]!) - 1]} ',
);

/// Rolle eines Geräts in einer Sitzung.
enum Role { sender, receiver }

/// Dringlichkeit einer Fahranweisung – steuert Farbe (und später Vibration).
enum Urgency { info, achtung, dringend }

/// Sonderkommando: blendet die Empfänger-Anzeige aus.
const String kOffKey = 'off';

/// Key für eine frei getippte Anweisung (Freitext).
const String kFreitextKey = 'freitext';

/// Aktuelle Protokollversion des Nachrichtenmodells.
const int kProtocolVersion = 3;

/// Eine Fahranweisung. Kann **ein bis drei** Kommandos kombinieren, als
/// Abfrage (`ask`) oder als **Freitext** (`text`) gesendet werden.
/// Identisch über alle Transports.
class DriveCommand {
  final int v;

  /// 1–3 Kommando-Keys; das erste ist das primäre.
  final List<String> keys;
  final Urgency urgency;
  final int ts;

  /// Abfrage statt Erklärung („Zeige mir …") – nur für Fahrzeug-Themen relevant.
  final bool ask;

  /// Frei getippte Anweisung; wenn gesetzt, zeigt der Empfänger diesen Text.
  final String text;

  const DriveCommand({
    this.v = kProtocolVersion,
    required this.keys,
    required this.urgency,
    required this.ts,
    this.ask = false,
    this.text = '',
  });

  /// Einzelnes Kommando mit aktuellem Zeitstempel.
  factory DriveCommand.now(String key, Urgency urgency, {bool ask = false}) =>
      DriveCommand(
        keys: [key],
        urgency: urgency,
        ask: ask,
        ts: DateTime.now().millisecondsSinceEpoch,
      );

  /// Kombination mehrerer Kommandos (Dringlichkeit = höchste der Teile).
  factory DriveCommand.combo(List<String> keys, Urgency urgency) =>
      DriveCommand(
        keys: List.unmodifiable(keys),
        urgency: urgency,
        ts: DateTime.now().millisecondsSinceEpoch,
      );

  /// Frei getippte Anweisung des Fahrlehrers.
  factory DriveCommand.freitext(
    String text, {
    Urgency urgency = Urgency.info,
  }) => DriveCommand(
    keys: const [kFreitextKey],
    urgency: urgency,
    text: text.trim(),
    ts: DateTime.now().millisecondsSinceEpoch,
  );

  /// Primärer Kommando-Key (Komfort/Kompatibilität).
  String get key => keys.first;

  bool get isCombo => keys.length > 1;
  bool get isOff => keys.length == 1 && keys.first == kOffKey;
  bool get isFreitext => text.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'v': v,
    'keys': keys,
    'urgency': urgency.name,
    'ts': ts,
    if (ask) 'ask': true,
    if (text.isNotEmpty) 'text': text,
  };

  factory DriveCommand.fromJson(Map<String, dynamic> j) => DriveCommand(
    v: (j['v'] as int?) ?? kProtocolVersion,
    keys: (j['keys'] as List).cast<String>(),
    urgency: Urgency.values.byName(j['urgency'] as String),
    ts: j['ts'] as int,
    ask: (j['ask'] as bool?) ?? false,
    text: (j['text'] as String?) ?? '',
  );

  @override
  String toString() =>
      'DriveCommand(${keys.join('+')}, ${urgency.name}, ask=$ask, ts=$ts)';
}

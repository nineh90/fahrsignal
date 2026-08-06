/// Rolle eines Geräts in einer Sitzung.
enum Role { sender, receiver }

/// Dringlichkeit einer Fahranweisung – steuert Farbe (und später Vibration).
enum Urgency { info, achtung, dringend }

/// Sonderkommando: blendet die Empfänger-Anzeige aus.
const String kOffKey = 'off';

/// Key für eine frei getippte Anweisung (Freitext).
const String kFreitextKey = 'freitext';

/// Aktuelle Protokollversion des Nachrichtenmodells.
/// v4: Ordinal-Feld `ord` ergänzt („zweite Straße links").
const int kProtocolVersion = 4;

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

  /// Ordnungszahl als Attribut des Kommandos: 0 = keine, sonst 1–9.
  /// Beispiel: „zweite Straße links" = `keys:['abbiegen_links'], ord:2`.
  /// Bewusst **kein** eigener Kombi-Eintrag – ein Ordinal ist kein Kommando,
  /// sondern eine Näherbestimmung des primären Kommandos.
  final int ord;

  const DriveCommand({
    this.v = kProtocolVersion,
    required this.keys,
    required this.urgency,
    required this.ts,
    this.ask = false,
    this.text = '',
    this.ord = 0,
  });

  /// Einzelnes Kommando mit aktuellem Zeitstempel.
  factory DriveCommand.now(
    String key,
    Urgency urgency, {
    bool ask = false,
    int ord = 0,
  }) => DriveCommand(
    keys: [key],
    urgency: urgency,
    ask: ask,
    ord: ord,
    ts: DateTime.now().millisecondsSinceEpoch,
  );

  /// Kombination mehrerer Kommandos (Dringlichkeit = höchste der Teile).
  factory DriveCommand.combo(List<String> keys, Urgency urgency, {int ord = 0}) =>
      DriveCommand(
        keys: List.unmodifiable(keys),
        urgency: urgency,
        ord: ord,
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
  bool get hasOrdinal => ord > 0;

  Map<String, dynamic> toJson() => {
    'v': v,
    'keys': keys,
    'urgency': urgency.name,
    'ts': ts,
    if (ask) 'ask': true,
    if (text.isNotEmpty) 'text': text,
    if (ord != 0) 'ord': ord,
  };

  factory DriveCommand.fromJson(Map<String, dynamic> j) => DriveCommand(
    v: (j['v'] as int?) ?? kProtocolVersion,
    keys: (j['keys'] as List).cast<String>(),
    urgency: Urgency.values.byName(j['urgency'] as String),
    ts: j['ts'] as int,
    ask: (j['ask'] as bool?) ?? false,
    text: (j['text'] as String?) ?? '',
    // Fehlt in v3-Nachrichten – Default 0 hält ältere Sender lesbar.
    ord: (j['ord'] as int?) ?? 0,
  );

  @override
  String toString() =>
      'DriveCommand(${keys.join('+')}, ${urgency.name}, '
      'ask=$ask, ord=$ord, ts=$ts)';
}

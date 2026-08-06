/// Sprechvarianten für den Kommando-Katalog – **reines Dart, keine Imports**.
///
/// Bewusst getrennt von `command_catalog.dart`: der Katalog importiert Flutter
/// (wegen `IconData`), der Parser soll das nicht müssen. Außerdem ist diese
/// Datei das, was nach einem Feldtest noch wächst – eine Datei, ein Reviewpunkt.
///
/// **Alle Phrasen stehen bereits normalisiert da**: kleingeschrieben, Umlaute
/// als `ae/oe/ue`, `ß` als `ss`, keine Satzzeichen, einfache Leerzeichen.
/// `normalizeUtterance()` im Parser erzeugt genau diese Form; ein
/// Invariantentest prüft, dass jede Phrase unter der Normalisierung stabil ist.
library;

/// Kommando-Key → Varianten, unter denen es gesprochen erkannt wird.
///
/// Faustregeln, die sich aus der Katalog-Analyse ergeben haben:
/// - Mehrwortige Varianten *zuerst* denken: der Parser nimmt den längsten
///   Treffer, dadurch schlägt „aussenspiegel links" das kurze „links".
/// - Keine Variante aufnehmen, die ein Fahrlehrer auch beiläufig sagt
///   („lass dir zeit" beim Plaudern) – solche Kommandos bleiben Tasten-only.
/// - Akronyme in Sprechform ergänzen („a b s", „anti blockier system").
const Map<String, List<String>> kCommandPhrases = {
  // ===================== MODUS FAHRT =====================
  // --- Gefahr ---
  'kinder': [
    'kinder',
    'achtung kinder',
    'kind am strassenrand',
    'spielende kinder',
  ],
  'tiere': ['tiere', 'tier', 'wild', 'reh', 'tier auf der strasse'],
  'fussgaenger': ['fussgaenger', 'passant', 'person auf der fahrbahn'],
  'radfahrer': ['radfahrer', 'fahrradfahrer', 'fahrrad', 'velo'],
  'gegenverkehr': ['gegenverkehr', 'entgegenkommender verkehr'],
  'hindernis': ['hindernis', 'baustelle', 'engstelle', 'blockiert'],
  'glaette': ['glaette', 'glatt', 'glatteis', 'rutschig'],
  // Nur als Alleinäußerung ein Kommando – siehe Sonderregel im Parser.
  'achtung': ['achtung', 'vorsicht', 'aufpassen'],

  // --- Richtung ---
  'links': ['links', 'nach links', 'linke seite'],
  'rechts': ['rechts', 'nach rechts', 'rechte seite'],
  'geradeaus': [
    'geradeaus',
    'gerade aus',
    'weiter geradeaus',
    'einfach geradeaus',
  ],
  'abbiegen_links': [
    'links abbiegen',
    'abbiegen links',
    'nach links abbiegen',
    'biege links ab',
    'bieg links ab',
    'links rein',
  ],
  'abbiegen_rechts': [
    'rechts abbiegen',
    'abbiegen rechts',
    'nach rechts abbiegen',
    'biege rechts ab',
    'bieg rechts ab',
    'rechts rein',
  ],
  'wenden': ['wenden', 'umdrehen', 'wende', 'kehrt machen'],
  'einordnen': ['einordnen', 'ordne dich ein', 'spur wechseln', 'einfaedeln'],
  'kreisverkehr': ['kreisverkehr', 'kreisel', 'in den kreisverkehr'],
  'ausfahrt1': ['erste ausfahrt', 'ausfahrt eins'],
  'ausfahrt2': ['zweite ausfahrt', 'ausfahrt zwei'],
  'ausfahrt3': ['dritte ausfahrt', 'ausfahrt drei'],
  'folgen': [
    'der strasse folgen',
    'strasse folgen',
    'folge der strasse',
    'weiter folgen',
  ],
  'rueckwaerts': ['rueckwaerts', 'zurueck setzen', 'rueckwaerts fahren'],
  'seitwaerts': [
    'seitwaerts einparken',
    'seitwaerts parken',
    'laengs einparken',
  ],

  // --- Tempo ---
  'langsamer': [
    'langsamer',
    'mach langsam',
    'langsam',
    'runter vom gas',
    'gas weg',
  ],
  'schneller': ['schneller', 'mehr gas', 'zuegiger', 'etwas schneller'],
  'anhalten': ['anhalten', 'halt an', 'ranfahren', 'rechts ranfahren'],
  'bremsen': ['bremsen', 'brems', 'bremse jetzt'],
  // „halt" fehlt hier bewusst: als Füllwort („ist halt so") würde es
  // dauernd einen roten STOPP auslösen. „halt an" bleibt über `anhalten`.
  'stopp': ['stopp', 'stop', 'sofort anhalten'],
  'parken': ['parken', 'einparken', 'parkluecke', 'halten'],

  // --- Hinweise ---
  'spiegel': ['spiegel', 'in den spiegel schauen', 'spiegel kontrollieren'],
  'schulterblick': [
    'schulterblick',
    'ueber die schulter schauen',
    'toter winkel',
  ],
  'blinker': ['blinker', 'blinken', 'blinker setzen', 'blinker rein'],
  'abstand': ['abstand', 'mehr abstand', 'abstand halten', 'zu dicht'],
  'gang': [
    'gang wechseln',
    'schalten',
    'hochschalten',
    'runterschalten',
    'gang raus',
  ],

  // ===================== MODUS ZEICHEN =====================
  'z_stop': ['stopp schild', 'stoppschild', 'haltelinie'],
  'z_vorfahrt_gewaehren': [
    'vorfahrt gewaehren',
    'vorfahrt achten',
    'vorfahrt beachten',
  ],
  'z_vorfahrtstrasse': [
    'vorfahrtstrasse',
    'vorfahrt strasse',
    'du hast vorfahrt',
  ],
  'z_tempo30': ['tempo dreissig', 'dreissiger zone', 'tempo limit dreissig'],
  'z_ueberholverbot': [
    'ueberholverbot',
    'nicht ueberholen',
    'ueberholen verboten',
  ],
  'z_einbahn': ['einbahnstrasse', 'einbahn'],

  // ===================== MODUS FAHRZEUG =====================
  // --- Abfahrtkontrolle ---
  'tuev': ['tuev plakette', 'tuev', 'hauptuntersuchung', 'hu plakette'],
  'bremse': ['bremse', 'bremse pruefen', 'bremsanlage'],
  'hupe': ['hupe', 'hupe pruefen', 'signalhorn'],
  'scheibenwischer': ['scheibenwischer', 'wischer', 'wischerblaetter'],
  'warndreieck': ['warndreieck'],
  'warnweste': ['warnweste', 'warnwesten'],
  'verbandskasten': ['verbandskasten', 'erste hilfe kasten', 'verbandkasten'],

  // --- Beleuchtung ---
  'abblendlicht': ['abblendlicht'],
  'fernlicht': ['fernlicht', 'aufblendlicht'],
  'standlicht': ['standlicht', 'begrenzungslicht'],
  'blinker_fz': [
    'blinker pruefen',
    'blinker kontrollieren',
    'fahrtrichtungsanzeiger',
  ],
  'warnblinker': ['warnblinker', 'warnblinkanlage'],
  'bremslicht': ['bremslicht', 'bremsleuchte'],
  'ruecklicht': ['ruecklicht', 'schlusslicht'],
  'nebel': ['nebelscheinwerfer', 'nebellicht', 'nebelschlussleuchte'],
  'kennzeichenlicht': ['kennzeichenbeleuchtung', 'kennzeichenlicht'],

  // --- Reifen ---
  'profil': ['profiltiefe', 'profil'],
  'reifendruck': ['reifendruck', 'luftdruck'],
  'reifenzustand': ['reifenzustand', 'reifen pruefen', 'reifen kontrollieren'],
  'felgen': ['felgen', 'felge'],

  // --- Flüssigkeiten ---
  'motoroel': ['motoroel', 'oelstand'],
  'kuehlwasser': ['kuehlwasser', 'kuehlfluessigkeit'],
  'bremsfluessigkeit': ['bremsfluessigkeit'],
  'wischwasser': ['scheibenwaschwasser', 'wischwasser', 'waschwasser'],
  'servooel': ['servooel', 'servofluessigkeit', 'lenkhilfefluessigkeit'],

  // --- Assistenzsysteme ---
  'abs': ['a b s', 'anti blockier system', 'antiblockiersystem'],
  'esp': [
    'e s p',
    'elektronisches stabilitaetsprogramm',
    'stabilitaetsprogramm',
  ],
  'spurhalte': ['spurhalteassistent', 'spurassistent'],
  'notbrems': ['notbremsassistent', 'notbremssystem'],
  'acc': ['abstandstempomat', 'adaptiver tempomat', 'abstandsregeltempomat'],
  'totwinkel': ['totwinkelassistent', 'totwinkel warner'],
  'parkassistent': ['parkassistent', 'einparkhilfe'],
  'tempomat': ['tempomat', 'geschwindigkeitsregler'],

  // --- Fahrzeugeinweisung ---
  'sitz': ['sitz einstellen', 'sitzposition', 'sitz'],
  'innenspiegel': ['innenspiegel', 'rueckspiegel'],
  'aussenspiegel_l': ['aussenspiegel links', 'linker aussenspiegel'],
  'aussenspiegel_r': ['aussenspiegel rechts', 'rechter aussenspiegel'],
  'gurt': ['gurt anlegen', 'anschnallen', 'gurt'],
  'lenkrad': ['lenkrad', 'lenkradeinstellung'],
  'zuendung': ['zuendung', 'zuendschloss', 'motor starten'],
  'kupplung': ['kupplung', 'kupplungspedal'],
  'handbremse': ['handbremse', 'feststellbremse'],
  'schaltung': ['schaltung', 'schalthebel', 'getriebe'],

  // ===================== MODUS FAHRSCHÜLER =====================
  'lob': ['gut gemacht', 'sehr gut', 'gut so', 'prima', 'klasse gemacht'],
  'perfekt': ['perfekt', 'ausgezeichnet'],
  'fehler': ['nicht gut', 'das war nichts', 'noch mal ueben'],

  'ruhig': ['ruhig bleiben', 'ganz ruhig', 'bleib ruhig'],
  'konzentration': ['konzentration', 'konzentrier dich', 'aufmerksam bleiben'],
  'durchatmen': ['tief durchatmen', 'durchatmen', 'einmal durchatmen'],
  'locker': ['locker lassen', 'locker bleiben', 'entspann dich'],
  'vertrauen': ['vertrau dir', 'du schaffst das', 'vertrauen'],
  'nicht_eilig': ['lass dir zeit', 'keine eile', 'nichts ueberstuerzen'],

  'pause': ['pause machen', 'pause'],
  'tanken': ['tanken', 'tankstelle', 'volltanken'],
  'platztausch': ['platz tauschen', 'platztausch', 'wir tauschen'],
  'zur_fahrschule': ['zur fahrschule', 'zurueck zur fahrschule'],
  'trinken': ['trinkpause', 'etwas trinken'],
  'gleich_fertig': ['gleich fertig', 'letzte runde', 'wir sind gleich durch'],
};

/// Basiswort → bereits existierender Katalog-Key je Ordnungszahl.
///
/// Für Kommandos, die den Katalog schon in nummerierter Form belegen. Damit
/// bleibt „zweite Ausfahrt" ohne Katalogumbau möglich: die Ordnungszahl wird
/// **aufgelöst**, statt als Attribut mitgeschickt zu werden.
const Map<String, Map<int, String>> kOrdinalKeys = {
  'ausfahrt': {1: 'ausfahrt1', 2: 'ausfahrt2', 3: 'ausfahrt3'},
};

/// Keys, die eine Ordnungszahl als **Attribut** (`DriveCommand.ord`) tragen.
/// „zweite Straße links" = `abbiegen_links` mit `ord: 2`.
const Set<String> kOrdinalCapable = {'abbiegen_links', 'abbiegen_rechts'};

/// Zählnomen für die Empfängerdarstellung: „2. **Straße** links".
const Map<String, String> kOrdinalNoun = {
  'abbiegen_links': 'Straße',
  'abbiegen_rechts': 'Straße',
};

/// Wörter, die eine Ordnungszahl verankern. Ohne eines davon in Reichweite
/// wird „zweite" nicht als Ordinal gewertet – sonst würde jedes beiläufige
/// „das zweite Mal" ein Kommando auslösen.
const Set<String> kOrdinalAnchors = {
  'strasse',
  'ausfahrt',
  'abzweigung',
  'moeglichkeit',
  'kreuzung',
  'einmuendung',
  'links',
  'rechts',
};

/// Ordnungszahlwörter → Zahl. `naechste` zählt als „die erste kommende".
const Map<String, int> kOrdinalWords = {
  'erste': 1,
  'ersten': 1,
  'erster': 1,
  'naechste': 1,
  'naechsten': 1,
  'zweite': 2,
  'zweiten': 2,
  'zweiter': 2,
  'dritte': 3,
  'dritten': 3,
  'dritter': 3,
  'vierte': 4,
  'vierten': 4,
  'vierter': 4,
};

/// Wörter, die die Dringlichkeit um eine Stufe anheben und dabei verbraucht
/// werden. `achtung`/`vorsicht` stehen bewusst hier **und** als Kommando –
/// die Sonderregel im Parser entscheidet anhand der Satzlänge.
const Set<String> kUrgencyBoosters = {
  'sofort',
  'schnell',
  'dringend',
  'achtung',
  'vorsicht',
  'gleich',
};

/// Füllwörter, die vor dem Abgleich entfernt werden.
const Set<String> kFillerWords = {
  'so', 'jetzt', 'mal', 'bitte', 'dann', 'und', 'aehm', 'aeh', 'okay', 'ok',
  'du', 'ja', 'also', 'hier', 'da', 'wir', 'ich', 'nun', 'eben', 'halt',
  // Reihungswörter – „links und danach rechts" ist der Standardweg für
  // Kombinationen, seit es den Kombi-Modus der Kacheln nicht mehr gibt.
  'danach', 'anschliessend', 'gleich',
  // Artikel/Pronomen – „frag mal den Verbandskasten ab", „erklaere mir das
  // Abblendlicht" sollen volle Abdeckung erreichen. „ab" ist das abgetrennte
  // Präfix von „abfragen" (innerhalb von Phrasen wie „bieg links ab" wird es
  // vorher vom Phrasentreffer konsumiert).
  'der', 'die', 'das', 'den', 'dem', 'ein', 'eine', 'einen', 'mir', 'mich',
  'ab',
};

/// Wörter, die ein Kommando als **Abfrage** markieren („frag den
/// Verbandskasten ab", „zeig mir die Handbremse") – setzt `ask` auf true.
const Set<String> kAskMarkers = {
  'abfragen',
  'abfrage',
  'frag',
  'frage',
  'fragen',
  'zeig',
  'zeige',
};

/// Wörter, die ausdrücklich eine **Erklärung** verlangen („erkläre das
/// Abblendlicht") – setzt `ask` auf false, egal was der Umschalter sagt.
const Set<String> kExplainMarkers = {
  'erklaeren',
  'erklaere',
  'erklaer',
  'erklaerung',
};

/// Verneinungen – blockieren positives Feedback („das war **nicht** gut").
const Set<String> kNegationWords = {'nicht', 'kein', 'keine', 'nichts'};

/// Keys, die bei einer Verneinung im Satz nicht gesendet werden dürfen.
const Set<String> kPositiveFeedbackKeys = {'lob', 'perfekt'};

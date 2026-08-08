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

/// Zahlwort → Ziffer. Die Spracherkennung liefert dasselbe Gesagte mal so,
/// mal so („Tempo 30" / „Tempo dreißig"); `normalizeUtterance()` vereinheitlicht
/// es auf die Ziffer, und die Phrasen unten stehen deshalb in Ziffernform.
const Map<String, String> kNumberWords = {
  'zwanzig': '20',
  'dreissig': '30',
  'vierzig': '40',
  'fuenfzig': '50',
  'sechzig': '60',
  'siebzig': '70',
  'achtzig': '80',
  'neunzig': '90',
  'hundert': '100',
  'einhundert': '100',
  'vier': '4',
  'sieben': '7',
};

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
  // --- Richtung ---
  'links': ['links', 'nach links', 'linke seite', 'links halten'],
  'rechts': ['rechts', 'nach rechts', 'rechte seite', 'rechts halten'],
  'geradeaus': [
    'geradeaus',
    'gerade aus',
    'gerade',
    'weiter geradeaus',
    'einfach geradeaus',
    'immer geradeaus',
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
  'einordnen': [
    'einordnen',
    'ordne dich ein',
    'spur wechseln',
    'einfaedeln',
    'links einordnen',
    'rechts einordnen',
  ],
  'kreisverkehr': [
    'kreisverkehr',
    'kreisel',
    'in den kreisverkehr',
    'im kreisverkehr',
  ],
  'ausfahrt1': ['erste ausfahrt', 'ausfahrt eins'],
  'ausfahrt2': ['zweite ausfahrt', 'ausfahrt zwei'],
  'ausfahrt3': ['dritte ausfahrt', 'ausfahrt drei'],
  'ampel': [
    'ampel',
    'an der ampel',
    'lichtzeichenanlage',
    'die ampel',
    'ampel beachten',
    'auf die ampel achten',
  ],
  'folgen': [
    'der strasse folgen',
    'strasse folgen',
    'folge der strasse',
    'weiter folgen',
  ],
  'rueckwaerts': ['rueckwaerts', 'zurueck setzen', 'rueckwaerts fahren'],

  // --- Tempo ---
  'langsamer': [
    'langsamer',
    'mach langsam',
    'langsam',
    'runter vom gas',
    'gas weg',
    'vom gas gehen',
    'etwas langsamer',
    'nicht so schnell',
  ],
  'schneller': [
    'schneller',
    'mehr gas',
    'zuegiger',
    'etwas schneller',
    'gas geben',
  ],
  'bremsen': ['bremsen', 'brems', 'bremse jetzt', 'abbremsen'],
  'parken': ['parken', 'parkluecke', 'halten', 'hier halten'],
  // Tempovorgaben. Die nackten Zahlen sind bewusst dabei – „fünfzig" sagt
  // eine Fahrlehrperson im Auto sonst nicht beiläufig. Ziffernform, weil
  // `kNumberWords` beim Normalisieren dorthin auflöst.
  't_schritt': [
    'schrittgeschwindigkeit',
    'schritttempo',
    'schritt tempo',
    '4 bis 7',
  ],
  't_30': ['tempo 30', '30', '30er zone', 'dreissiger zone', '30 fahren'],
  't_50': ['tempo 50', '50', '50 fahren', 'innerorts 50'],
  't_70': ['tempo 70', '70', '70 fahren'],
  't_100': ['tempo 100', '100', '100 fahren'],
  't_frei': [
    'unbegrenzt',
    'tempo unbegrenzt',
    'keine begrenzung',
    'aufhebung',
    'freie fahrt',
    'so schnell du willst',
  ],

  // --- Hinweise ---
  'reihenfolge': [
    'reihenfolge',
    'spiegel blinker schulterblick',
    'in der reihenfolge',
  ],
  'spiegel': [
    'spiegel',
    'in den spiegel schauen',
    'spiegel kontrollieren',
    'spiegel schauen',
    'in den spiegel',
    'spiegel gucken',
  ],
  'blinker': [
    'blinker',
    'blinken',
    'blinker setzen',
    'blinker rein',
    'blinker nicht vergessen',
    'blinken nicht vergessen',
  ],
  'schulterblick': [
    'schulterblick',
    'ueber die schulter schauen',
    'toter winkel',
    'schulterblick machen',
    'schulterblick nicht vergessen',
  ],
  'rundumblick': [
    'rundumblick',
    'rundum schauen',
    'rundum blick',
    'rundumsicht',
  ],
  'nach_hinten': [
    'nach hinten schauen',
    'nach hinten sehen',
    'blick nach hinten',
    'nach hinten',
  ],
  'hindernis': [
    'hindernis',
    'baustelle',
    'engstelle',
    'blockiert',
    'da ist ein hindernis',
  ],
  'abstand': [
    'abstand',
    'mehr abstand',
    'abstand halten',
    'zu dicht',
    'mehr abstand halten',
    'zu dicht dran',
  ],
  'gang': [
    'gang wechseln',
    'schalten',
    'hochschalten',
    'runterschalten',
    'gang raus',
  ],
  'anhalten': [
    'anhalten',
    'halt an',
    'ranfahren',
    'rechts ranfahren',
    'rechts ran',
    'stehen bleiben',
    'stehenbleiben',
  ],
  // „halt" fehlt hier bewusst: als Füllwort („ist halt so") würde es
  // dauernd einen roten STOPP auslösen. „halt an" bleibt über `anhalten`.
  'stopp': ['stopp', 'stop', 'sofort anhalten', 'sofort stehen bleiben'],

  // ===================== MODUS GRUNDFAHRAUFGABEN =====================
  // „seitwaerts einparken" hört hier mit: das frühere Richtungs-Kommando
  // ist genau diese Grundfahraufgabe, gesprochen soll es weiter greifen.
  'gfa_laengs': [
    'laengs parken',
    'laengs einparken',
    'seitwaerts einparken',
    'seitwaerts parken',
    'einparken',
  ],
  'gfa_quer': ['quer parken', 'quer einparken', 'rueckwaerts quer einparken'],
  'gfa_bremsung': ['gefahrenbremsung', 'gefahrbremsung', 'zielbremsung'],
  'gfa_ecke': ['rechts um die ecke', 'rueckwaerts um die ecke', 'um die ecke'],
  'gfa_umkehren': ['umkehren', 'umkehr', 'umkehren durch rueckwaertsfahren'],

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

/// Füllwörter: zählen nicht gegen die Abdeckung.
///
/// Das ist der Stellhebel dafür, ob ein **ganzer Satz** noch sicher genug ist:
/// „so, dann fährst du jetzt bitte mal rechts ran" enthält ein Kommando und
/// neun Wörter drumherum. Ohne großzügige Liste rutscht die Abdeckung unter
/// die Schwelle und alles landet in der Rückfrage – genau das Gefühl von
/// „er versteht mich nicht".
///
/// Ungefährlich, weil Phrasen **vor** dieser Liste greifen: „weiter geradeaus"
/// wird als Ganzes getroffen, bevor „weiter" hier überhaupt gefragt wird.
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
  // Präpositionen und Partikeln, die im Auto ständig mitlaufen.
  'in', 'im', 'an', 'am', 'auf', 'zu', 'zum', 'zur', 'bei', 'von', 'vom',
  'mit', 'nach', 'fuer', 'noch', 'ganz', 'etwas', 'kurz', 'weiter', 'wieder',
  'schon', 'sehr', 'bisschen', 'vielleicht', 'einfach',
  // Verben des Aufforderns – tragen keine Bedeutung über das Kommando hinaus.
  'fahr', 'fahre', 'faehrst', 'fahren', 'mach', 'machst', 'machen', 'geh',
  'gehst', 'nimm', 'nimmst', 'musst', 'muss', 'kannst', 'solltest', 'wuerde',
  'werden', 'wirst', 'bist', 'ist', 'sind', 'war', 'hast', 'hat', 'haben',
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

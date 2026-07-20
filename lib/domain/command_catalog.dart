import 'package:flutter/material.dart';
import 'drive_command.dart';

/// Vollflächige Hintergrundfarbe der Empfänger-Anzeige je Dringlichkeit
/// (info=blau, achtung=gelb, dringend=rot).
Color urgencyColor(Urgency u) => switch (u) {
  Urgency.info => const Color(0xFF1565C0),
  Urgency.achtung => const Color(0xFFF9A825),
  Urgency.dringend => const Color(0xFFC62828),
};

/// Kontrastreiche Textfarbe auf der jeweiligen Urgency-Fläche.
/// Gelb braucht dunklen Text, Blau/Rot hellen.
Color urgencyForeground(Urgency u) =>
    u == Urgency.achtung ? const Color(0xFF111417) : Colors.white;

/// Höchste (dringendste) Urgency einer Kombination.
Urgency maxUrgency(Iterable<Urgency> us) =>
    us.reduce((a, b) => a.index >= b.index ? a : b);

/// Form, in der ein Kommando beim Empfänger als Verkehrszeichen erscheint.
enum SignShape { none, triangle, round }

/// Oberbereiche des Sender-Dashboards.
enum DashboardMode { fahrt, zeichen, fahrzeug, fahrschueler }

extension DashboardModeX on DashboardMode {
  String get label => switch (this) {
    DashboardMode.fahrt => 'Fahrt',
    DashboardMode.zeichen => 'Zeichen',
    DashboardMode.fahrzeug => 'Fahrzeug',
    DashboardMode.fahrschueler => 'Fahrschüler',
  };

  IconData get icon => switch (this) {
    DashboardMode.fahrt => Icons.directions_car,
    DashboardMode.zeichen => Icons.signpost,
    DashboardMode.fahrzeug => Icons.build,
    DashboardMode.fahrschueler => Icons.school,
  };
}

/// Themenbereiche (Kategorien). Jede Kategorie gehört zu genau einem Modus.
enum CommandCategory {
  gefahr,
  richtung,
  tempo,
  hinweis,
  zeichen,
  feedback,
  abfahrt,
  beleuchtung,
  reifen,
  fluessigkeit,
  assistenz,
  einweisung,
  coaching,
  organisation,
}

extension CommandCategoryX on CommandCategory {
  DashboardMode get mode => switch (this) {
    CommandCategory.abfahrt ||
    CommandCategory.beleuchtung ||
    CommandCategory.reifen ||
    CommandCategory.fluessigkeit ||
    CommandCategory.assistenz ||
    CommandCategory.einweisung => DashboardMode.fahrzeug,
    CommandCategory.feedback ||
    CommandCategory.coaching ||
    CommandCategory.organisation => DashboardMode.fahrschueler,
    CommandCategory.zeichen => DashboardMode.zeichen,
    _ => DashboardMode.fahrt,
  };

  String get label => switch (this) {
    CommandCategory.gefahr => 'Gefahr',
    CommandCategory.richtung => 'Richtung',
    CommandCategory.tempo => 'Tempo',
    CommandCategory.hinweis => 'Hinweise',
    CommandCategory.zeichen => 'Verkehrszeichen',
    CommandCategory.feedback => 'Lob & Kritik',
    CommandCategory.abfahrt => 'Abfahrtkontrolle',
    CommandCategory.beleuchtung => 'Beleuchtung',
    CommandCategory.reifen => 'Reifen',
    CommandCategory.fluessigkeit => 'Flüssigkeiten',
    CommandCategory.assistenz => 'Assistenzsysteme',
    CommandCategory.einweisung => 'Fahrzeugeinweisung',
    CommandCategory.coaching => 'Coaching',
    CommandCategory.organisation => 'Organisation',
  };

  IconData get icon => switch (this) {
    CommandCategory.gefahr => Icons.warning_amber,
    CommandCategory.richtung => Icons.explore,
    CommandCategory.tempo => Icons.speed,
    CommandCategory.hinweis => Icons.checklist,
    CommandCategory.zeichen => Icons.signpost,
    CommandCategory.feedback => Icons.thumbs_up_down,
    CommandCategory.abfahrt => Icons.fact_check,
    CommandCategory.beleuchtung => Icons.lightbulb,
    CommandCategory.reifen => Icons.trip_origin,
    CommandCategory.fluessigkeit => Icons.water_drop,
    CommandCategory.assistenz => Icons.sensors,
    CommandCategory.einweisung => Icons.event_seat,
    CommandCategory.coaching => Icons.self_improvement,
    CommandCategory.organisation => Icons.event_note,
  };

  /// Regenbogen-Farbe der Kategorie (farbliche Trennung im Dashboard).
  Color get color => switch (this) {
    CommandCategory.gefahr => const Color(0xFFE53935), // Rot
    CommandCategory.richtung => const Color(0xFF1E88E5), // Blau
    CommandCategory.tempo => const Color(0xFFFB8C00), // Orange
    CommandCategory.hinweis => const Color(0xFF8E24AA), // Violett
    CommandCategory.zeichen => const Color(0xFF00897B), // Türkis
    CommandCategory.feedback => const Color(0xFF2E9E44), // Grün
    CommandCategory.abfahrt => const Color(0xFF2E7D32), // Grün
    CommandCategory.beleuchtung => const Color(0xFFF9A825), // Gelb
    CommandCategory.reifen => const Color(0xFF546E7A), // Blaugrau
    CommandCategory.fluessigkeit => const Color(0xFF0097A7), // Cyan
    CommandCategory.assistenz => const Color(0xFF5E35B1), // Violett
    CommandCategory.einweisung => const Color(0xFF3949AB), // Indigo
    CommandCategory.coaching => const Color(0xFF00ACC1), // Cyan
    CommandCategory.organisation => const Color(0xFFEC407A), // Pink
  };
}

/// Ein Eintrag im Kommando-Katalog.
class CommandDef {
  final String key;
  final String label;
  final IconData icon;
  final Urgency urgency;
  final CommandCategory category;

  /// Kurze Erklärung für die Empfängerseite (v. a. Fahrzeug/Abfahrtkontrolle):
  /// worum es geht bzw. wie es geht. Leer = keine Erklärung anzeigen.
  final String explanation;

  const CommandDef(
    this.key,
    this.label,
    this.icon,
    this.urgency,
    this.category, {
    this.explanation = '',
  });

  bool get hasExplanation => explanation.isNotEmpty;

  DashboardMode get mode => category.mode;

  /// Als welches Verkehrszeichen die Empfängerseite dies darstellt.
  SignShape get sign => switch (category) {
    CommandCategory.gefahr => SignShape.triangle,
    CommandCategory.zeichen => SignShape.round,
    _ => SignShape.none,
  };
  bool get isSign => sign != SignShape.none;
}

/// Ausgangskatalog. Erweiterbar; später ggf. konfigurierbar je Fahrschule.
const List<CommandDef> kCommandCatalog = [
  // ===== Modus FAHRT =====
  // --- Gefahr ---
  CommandDef(
    'kinder',
    'Kinder',
    Icons.escalator_warning,
    Urgency.dringend,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'tiere',
    'Tiere',
    Icons.pets,
    Urgency.dringend,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'fussgaenger',
    'Fußgänger',
    Icons.directions_walk,
    Urgency.achtung,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'radfahrer',
    'Radfahrer',
    Icons.directions_bike,
    Urgency.achtung,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'gegenverkehr',
    'Gegenverkehr',
    Icons.sync_alt,
    Urgency.achtung,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'hindernis',
    'Hindernis',
    Icons.dangerous,
    Urgency.dringend,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'glaette',
    'Glätte',
    Icons.ac_unit,
    Urgency.achtung,
    CommandCategory.gefahr,
  ),
  CommandDef(
    'achtung',
    'Achtung!',
    Icons.priority_high,
    Urgency.dringend,
    CommandCategory.gefahr,
  ),

  // --- Richtung ---
  CommandDef(
    'links',
    'Links',
    Icons.turn_left,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'rechts',
    'Rechts',
    Icons.turn_right,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'geradeaus',
    'Geradeaus',
    Icons.straight,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'abbiegen_links',
    'Abbiegen links',
    Icons.turn_sharp_left,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'abbiegen_rechts',
    'Abbiegen rechts',
    Icons.turn_sharp_right,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'wenden',
    'Wenden',
    Icons.u_turn_left,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'einordnen',
    'Einordnen',
    Icons.merge,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'kreisverkehr',
    'Kreisverkehr',
    Icons.roundabout_right,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'ausfahrt1',
    '1. Ausfahrt',
    Icons.filter_1,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'ausfahrt2',
    '2. Ausfahrt',
    Icons.filter_2,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'ausfahrt3',
    '3. Ausfahrt',
    Icons.filter_3,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'folgen',
    'Straße folgen',
    Icons.route,
    Urgency.info,
    CommandCategory.richtung,
  ),
  CommandDef(
    'rueckwaerts',
    'Rückwärts',
    Icons.arrow_downward,
    Urgency.achtung,
    CommandCategory.richtung,
  ),
  CommandDef(
    'seitwaerts',
    'Seitwärts einparken',
    Icons.local_parking,
    Urgency.info,
    CommandCategory.richtung,
  ),

  // --- Tempo ---
  CommandDef(
    'langsamer',
    'Langsamer',
    Icons.trending_down,
    Urgency.achtung,
    CommandCategory.tempo,
  ),
  CommandDef(
    'schneller',
    'Schneller',
    Icons.trending_up,
    Urgency.info,
    CommandCategory.tempo,
  ),
  CommandDef(
    'anhalten',
    'Anhalten',
    Icons.front_hand,
    Urgency.achtung,
    CommandCategory.tempo,
  ),
  CommandDef(
    'bremsen',
    'Bremsen',
    Icons.report_problem,
    Urgency.dringend,
    CommandCategory.tempo,
  ),
  CommandDef(
    'stopp',
    'STOPP',
    Icons.pan_tool,
    Urgency.dringend,
    CommandCategory.tempo,
  ),
  CommandDef(
    'parken',
    'Halten',
    Icons.local_parking,
    Urgency.info,
    CommandCategory.tempo,
  ),

  // --- Hinweise ---
  CommandDef(
    'spiegel',
    'Spiegel',
    Icons.visibility,
    Urgency.info,
    CommandCategory.hinweis,
  ),
  CommandDef(
    'schulterblick',
    'Schulterblick',
    Icons.threesixty,
    Urgency.achtung,
    CommandCategory.hinweis,
  ),
  CommandDef(
    'blinker',
    'Blinker',
    Icons.highlight,
    Urgency.info,
    CommandCategory.hinweis,
  ),
  CommandDef(
    'abstand',
    'Abstand',
    Icons.social_distance,
    Urgency.achtung,
    CommandCategory.hinweis,
  ),
  CommandDef(
    'gang',
    'Gang wechseln',
    Icons.settings,
    Urgency.info,
    CommandCategory.hinweis,
  ),

  // --- Verkehrszeichen ---
  CommandDef(
    'z_stop',
    'Stopp-Schild',
    Icons.do_not_disturb_on,
    Urgency.dringend,
    CommandCategory.zeichen,
  ),
  CommandDef(
    'z_vorfahrt_gewaehren',
    'Vorfahrt gewähren',
    Icons.change_history,
    Urgency.achtung,
    CommandCategory.zeichen,
  ),
  CommandDef(
    'z_vorfahrtstrasse',
    'Vorfahrtstraße',
    Icons.diamond,
    Urgency.info,
    CommandCategory.zeichen,
  ),
  CommandDef(
    'z_tempo30',
    'Tempo 30',
    Icons.speed,
    Urgency.achtung,
    CommandCategory.zeichen,
  ),
  CommandDef(
    'z_ueberholverbot',
    'Überholverbot',
    Icons.block,
    Urgency.achtung,
    CommandCategory.zeichen,
  ),
  CommandDef(
    'z_einbahn',
    'Einbahnstraße',
    Icons.trending_flat,
    Urgency.info,
    CommandCategory.zeichen,
  ),

  // --- Lob & Kritik (Fahrschüler-Bereich) ---
  CommandDef(
    'lob',
    'Gut gemacht',
    Icons.thumb_up,
    Urgency.info,
    CommandCategory.feedback,
  ),
  CommandDef(
    'perfekt',
    'Perfekt!',
    Icons.emoji_events,
    Urgency.info,
    CommandCategory.feedback,
  ),
  CommandDef(
    'fehler',
    'Nicht gut',
    Icons.thumb_down,
    Urgency.achtung,
    CommandCategory.feedback,
  ),

  // ===== Modus FAHRZEUG =====
  // --- Abfahrtkontrolle (allgemein) ---
  CommandDef(
    'tuev',
    'TÜV-Plakette',
    Icons.event_available,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Die Plakette am hinteren Kennzeichen zeigt, bis wann die nächste Hauptuntersuchung (HU) fällig ist. Die oberste Zahl steht für den Monat, die Farbe für das Jahr.',
  ),
  CommandDef(
    'bremse',
    'Bremse',
    Icons.report,
    Urgency.achtung,
    CommandCategory.abfahrt,
    explanation:
        'Bremspedal treten: Der Widerstand muss fest sein und darf nicht bis zum Boden durchgehen. Das Fahrzeug darf mit angezogener Bremse nicht wegrollen.',
  ),
  CommandDef(
    'hupe',
    'Hupe',
    Icons.volume_up,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Kurz auf die Mitte des Lenkrads drücken – die Hupe muss deutlich hörbar sein.',
  ),
  CommandDef(
    'scheibenwischer',
    'Scheibenwischer',
    Icons.cleaning_services,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Wischer und Waschanlage testen. Die Wischerblätter dürfen nicht rissig sein und müssen sauber und schlierenfrei wischen.',
  ),
  CommandDef(
    'warndreieck',
    'Warndreieck',
    Icons.change_history,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Muss im Auto mitgeführt werden. Bei einer Panne gut sichtbar und mit ausreichendem Abstand hinter dem Fahrzeug aufstellen.',
  ),
  CommandDef(
    'warnweste',
    'Warnweste',
    Icons.checkroom,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Die reflektierende Weste muss griffbereit sein und beim Aussteigen an der Straße getragen werden.',
  ),
  CommandDef(
    'verbandskasten',
    'Verbandskasten',
    Icons.medical_services,
    Urgency.info,
    CommandCategory.abfahrt,
    explanation:
        'Muss vorhanden und nicht abgelaufen sein – das Haltbarkeitsdatum auf dem Kasten prüfen.',
  ),

  // --- Beleuchtung ---
  CommandDef(
    'abblendlicht',
    'Abblendlicht',
    Icons.light_mode,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Das normale Fahrlicht bei Dunkelheit. Es beleuchtet die Straße, ohne den Gegenverkehr zu blenden.',
  ),
  CommandDef(
    'fernlicht',
    'Fernlicht',
    Icons.wb_sunny,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Weitreichendes Licht für freie Strecke. Bei Gegenverkehr oder Vorausfahrenden sofort abblenden, um nicht zu blenden.',
  ),
  CommandDef(
    'standlicht',
    'Standlicht',
    Icons.wb_twilight,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Schwaches Licht, um das stehende Fahrzeug sichtbar zu machen – nicht zum Fahren bei Dunkelheit gedacht.',
  ),
  CommandDef(
    'blinker_fz',
    'Blinker',
    Icons.arrow_right_alt,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Zeigt Abbiegen und Spurwechsel rechtzeitig an. Vorne und hinten muss er gleichmäßig blinken.',
  ),
  CommandDef(
    'warnblinker',
    'Warnblinker',
    Icons.warning,
    Urgency.achtung,
    CommandCategory.beleuchtung,
    explanation:
        'Alle Blinker gleichzeitig. Warnt andere bei Panne, Stauende oder Gefahr.',
  ),
  CommandDef(
    'bremslicht',
    'Bremslicht',
    Icons.brightness_high,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Leuchtet beim Bremsen rot auf und warnt den Hintermann. Funktion am besten von einer zweiten Person prüfen lassen.',
  ),
  CommandDef(
    'ruecklicht',
    'Rücklicht',
    Icons.brightness_low,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Die roten Rückleuchten machen das Fahrzeug bei Dunkelheit von hinten sichtbar.',
  ),
  CommandDef(
    'nebel',
    'Nebelscheinwerfer',
    Icons.foggy,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Nur bei Nebel, Schneefall oder Regen mit Sichtweite unter etwa 50 m einschalten.',
  ),
  CommandDef(
    'kennzeichenlicht',
    'Kennzeichen',
    Icons.pin,
    Urgency.info,
    CommandCategory.beleuchtung,
    explanation:
        'Beleuchtet das hintere Kennzeichen. Es muss bei Dunkelheit gut lesbar sein.',
  ),

  // --- Reifen ---
  CommandDef(
    'profil',
    'Profiltiefe',
    Icons.donut_large,
    Urgency.achtung,
    CommandCategory.reifen,
    explanation:
        'Mindestens 1,6 mm sind vorgeschrieben. Empfohlen werden 3 mm (Sommer) bzw. 4 mm (Winter). Ein 1-Euro-Stück hilft beim Schätzen.',
  ),
  CommandDef(
    'reifendruck',
    'Reifendruck',
    Icons.tire_repair,
    Urgency.info,
    CommandCategory.reifen,
    explanation:
        'Regelmäßig prüfen. Der richtige Druck steht im Tankdeckel oder am Türholm. Falscher Druck erhöht Verbrauch und Verschleiß.',
  ),
  CommandDef(
    'reifenzustand',
    'Reifenzustand',
    Icons.trip_origin,
    Urgency.achtung,
    CommandCategory.reifen,
    explanation:
        'Auf Risse, Beulen, Fremdkörper und gleichmäßigen Abrieb achten.',
  ),
  CommandDef(
    'felgen',
    'Felgen',
    Icons.blur_circular,
    Urgency.info,
    CommandCategory.reifen,
    explanation:
        'Auf Beschädigungen prüfen; die Radmuttern müssen fest sitzen.',
  ),

  // --- Flüssigkeiten ---
  CommandDef(
    'motoroel',
    'Motoröl',
    Icons.opacity,
    Urgency.info,
    CommandCategory.fluessigkeit,
    explanation:
        'Bei kaltem Motor auf ebener Fläche mit dem Messstab prüfen: Der Ölstand soll zwischen Min und Max liegen.',
  ),
  CommandDef(
    'kuehlwasser',
    'Kühlwasser',
    Icons.water_drop,
    Urgency.info,
    CommandCategory.fluessigkeit,
    explanation:
        'Der Stand im Ausgleichsbehälter soll zwischen Min und Max liegen. Nie bei heißem Motor öffnen – Verbrühungsgefahr.',
  ),
  CommandDef(
    'bremsfluessigkeit',
    'Bremsflüssigkeit',
    Icons.invert_colors,
    Urgency.achtung,
    CommandCategory.fluessigkeit,
    explanation:
        'Füllstand im Behälter zwischen Min und Max. Zu wenig kann auf Verschleiß oder eine Undichtigkeit hindeuten.',
  ),
  CommandDef(
    'wischwasser',
    'Scheibenwaschwasser',
    Icons.local_car_wash,
    Urgency.info,
    CommandCategory.fluessigkeit,
    explanation:
        'Behälter auffüllen; im Winter mit Frostschutz, damit die Sicht klar bleibt.',
  ),
  CommandDef(
    'servooel',
    'Servoöl',
    Icons.oil_barrel,
    Urgency.info,
    CommandCategory.fluessigkeit,
    explanation:
        'Falls vorhanden: Stand prüfen – wichtig für eine leichtgängige Lenkung.',
  ),

  // --- Assistenzsysteme ---
  CommandDef(
    'abs',
    'ABS',
    Icons.settings_suggest,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Antiblockiersystem: verhindert das Blockieren der Räder beim starken Bremsen. So bleibt das Auto lenkbar – Pedal fest durchtreten.',
  ),
  CommandDef(
    'esp',
    'ESP',
    Icons.moving,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Elektronisches Stabilitätsprogramm: bremst einzelne Räder gezielt ab und verhindert so ein Schleudern.',
  ),
  CommandDef(
    'spurhalte',
    'Spurhalteassistent',
    Icons.straighten,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Warnt oder lenkt gegen, wenn du ohne Blinker die Fahrspur verlässt.',
  ),
  CommandDef(
    'notbrems',
    'Notbremsassistent',
    Icons.dangerous,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Bremst automatisch, wenn ein Hindernis erkannt wird und du nicht rechtzeitig reagierst.',
  ),
  CommandDef(
    'acc',
    'Abstandstempomat',
    Icons.social_distance,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Hält die eingestellte Geschwindigkeit und automatisch den Abstand zum Vorausfahrenden.',
  ),
  CommandDef(
    'totwinkel',
    'Totwinkelassistent',
    Icons.visibility_off,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Warnt vor Fahrzeugen im toten Winkel. Den Schulterblick trotzdem immer machen.',
  ),
  CommandDef(
    'parkassistent',
    'Parkassistent',
    Icons.local_parking,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Unterstützt beim Einparken über Sensoren und Kamera; die Lenkung erfolgt teils automatisch.',
  ),
  CommandDef(
    'tempomat',
    'Tempomat',
    Icons.speed,
    Urgency.info,
    CommandCategory.assistenz,
    explanation:
        'Hält eine eingestellte Geschwindigkeit konstant, ohne dass du Gas geben musst.',
  ),

  // --- Fahrzeugeinweisung ---
  CommandDef(
    'sitz',
    'Sitz einstellen',
    Icons.event_seat,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'So einstellen, dass die Pedale mit leicht gewinkeltem Bein ganz durchgetreten werden können und der Rücken anliegt.',
  ),
  CommandDef(
    'innenspiegel',
    'Innenspiegel',
    Icons.crop_16_9,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Den Innenspiegel so einstellen, dass die Heckscheibe möglichst vollständig im Blick ist – ohne den Kopf zu bewegen.',
  ),
  CommandDef(
    'aussenspiegel_l',
    'Außenspiegel links',
    Icons.chevron_left,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Den linken Außenspiegel so einstellen, dass die eigene Fahrzeugseite gerade noch am inneren Rand sichtbar ist – das verkleinert den toten Winkel.',
  ),
  CommandDef(
    'aussenspiegel_r',
    'Außenspiegel rechts',
    Icons.chevron_right,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Den rechten Außenspiegel genauso einstellen: eigene Fahrzeugseite gerade noch sichtbar, ansonsten viel Blick auf die Fahrbahn daneben.',
  ),
  CommandDef(
    'gurt',
    'Gurt anlegen',
    Icons.safety_check,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Straff über Becken und Schulter führen, nicht verdreht. Vor jeder Fahrt anlegen.',
  ),
  CommandDef(
    'lenkrad',
    'Lenkrad',
    Icons.trip_origin,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Höhe und Abstand so wählen, dass die Handgelenke bei ausgestreckten Armen auf dem Lenkradkranz liegen.',
  ),
  CommandDef(
    'zuendung',
    'Zündung',
    Icons.key,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Schlüssel oder Startknopf: erst Bordnetz, dann Zündung, dann starten – dabei die Kupplung treten.',
  ),
  CommandDef(
    'kupplung',
    'Kupplung',
    Icons.disc_full,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Trennt Motor und Getriebe. Zum Anfahren und Schalten treten; den Schleifpunkt gefühlvoll kommen lassen.',
  ),
  CommandDef(
    'handbremse',
    'Handbremse',
    Icons.back_hand,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Sichert das stehende Fahrzeug gegen Wegrollen. Vor dem Anfahren wieder lösen.',
  ),
  CommandDef(
    'schaltung',
    'Schaltung',
    Icons.settings_input_component,
    Urgency.info,
    CommandCategory.einweisung,
    explanation:
        'Den zur Geschwindigkeit passenden Gang wählen. Beim Schalten die Kupplung ganz durchtreten.',
  ),

  // ===== Modus FAHRSCHÜLER =====
  // --- Coaching (Ermutigung / Ruhe) ---
  CommandDef(
    'ruhig',
    'Ruhig bleiben',
    Icons.self_improvement,
    Urgency.info,
    CommandCategory.coaching,
  ),
  CommandDef(
    'konzentration',
    'Konzentration',
    Icons.psychology_alt,
    Urgency.achtung,
    CommandCategory.coaching,
  ),
  CommandDef(
    'durchatmen',
    'Tief durchatmen',
    Icons.air,
    Urgency.info,
    CommandCategory.coaching,
  ),
  CommandDef(
    'locker',
    'Locker lassen',
    Icons.spa,
    Urgency.info,
    CommandCategory.coaching,
  ),
  CommandDef(
    'vertrauen',
    'Vertrau dir',
    Icons.favorite,
    Urgency.info,
    CommandCategory.coaching,
  ),
  CommandDef(
    'nicht_eilig',
    'Lass dir Zeit',
    Icons.hourglass_empty,
    Urgency.info,
    CommandCategory.coaching,
  ),

  // --- Organisation ---
  CommandDef(
    'pause',
    'Pause machen',
    Icons.free_breakfast,
    Urgency.info,
    CommandCategory.organisation,
  ),
  CommandDef(
    'tanken',
    'Tanken',
    Icons.local_gas_station,
    Urgency.info,
    CommandCategory.organisation,
  ),
  CommandDef(
    'platztausch',
    'Platz tauschen',
    Icons.swap_horiz,
    Urgency.info,
    CommandCategory.organisation,
  ),
  CommandDef(
    'zur_fahrschule',
    'Zur Fahrschule',
    Icons.home,
    Urgency.info,
    CommandCategory.organisation,
  ),
  CommandDef(
    'trinken',
    'Trinkpause',
    Icons.local_cafe,
    Urgency.info,
    CommandCategory.organisation,
  ),
  CommandDef(
    'gleich_fertig',
    'Gleich fertig',
    Icons.flag,
    Urgency.info,
    CommandCategory.organisation,
  ),
];

/// Katalog-Eintrag zu einem Kommando-Key (oder null, z. B. für 'off').
CommandDef? commandByKey(String key) {
  for (final c in kCommandCatalog) {
    if (c.key == key) return c;
  }
  return null;
}

/// Kommandos einer Kategorie in Katalog-Reihenfolge.
List<CommandDef> commandsInCategory(CommandCategory c) =>
    kCommandCatalog.where((d) => d.category == c).toList();

/// Kategorien eines Modus in Enum-Reihenfolge.
List<CommandCategory> categoriesInMode(DashboardMode m) =>
    CommandCategory.values.where((c) => c.mode == m).toList();

/// Positives Lob (Empfänger wird grün statt urgency-farbig).
bool isPositiveFeedback(String key) => key == 'lob' || key == 'perfekt';

/// Farbe der Sender-Kachel. Rückmeldung nutzt Ton-Farbe (grün/orange) statt
/// der Kategoriefarbe, damit Lob und Kritik sofort unterscheidbar sind.
Color tileColor(CommandDef d) {
  if (d.category == CommandCategory.feedback) {
    return isPositiveFeedback(d.key)
        ? const Color(0xFF2E9E44)
        : const Color(0xFFEF6C00);
  }
  return d.category.color;
}

/// Vollflächen-Hintergrund der Empfängeranzeige (positives Lob = grün).
Color commandColor(DriveCommand c) => isPositiveFeedback(c.key)
    ? const Color(0xFF2E9E44)
    : urgencyColor(c.urgency);

/// Passende Vordergrundfarbe zu [commandColor].
Color commandForeground(DriveCommand c) =>
    isPositiveFeedback(c.key) ? Colors.white : urgencyForeground(c.urgency);

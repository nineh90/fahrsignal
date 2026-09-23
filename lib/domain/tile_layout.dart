import 'command_catalog.dart';

/// Kacheln, die der Fahrlehrer nicht sieht, bis er sie selbst zurückholt
/// (SAR-120). Aus dem Katalog verschwinden sie nicht: die Sprachleiste
/// erkennt „rechts abbiegen" weiter, und der Schüler sieht das Zeichen.
const Set<String> kDefaultHiddenKeys = {
  'abbiegen_links',
  'abbiegen_rechts',
  'einordnen_links',
  'einordnen',
  'einordnen_rechts',
  'rueckwaerts',
  // SAR-119: Halten fliegt aus dem Tempo-Bereich.
  'parken',
};

/// Die Standard-Ausblendungen, die gespeicherte Anordnungen ohne
/// `seenDefaults` schon kannten (Stand SAR-120).
const Set<String> _kDefaultsBeforeTracking = {
  'abbiegen_links',
  'abbiegen_rechts',
  'einordnen_links',
  'einordnen',
  'einordnen_rechts',
  'rueckwaerts',
};

/// Die eigene Anordnung des Fahrlehrers: Reihenfolge je Kategorie und welche
/// Kacheln ausgeblendet sind. Kategorien bleiben, wo sie sind – verschoben
/// wird nur innerhalb.
///
/// Gespeichert werden nur Keys. Was der Katalog später dazubekommt, taucht
/// deshalb von selbst auf, an seiner Katalogposition; was er verliert,
/// fällt still heraus.
class TileLayout {
  /// Reihenfolge je Kategorie. Fehlt eine Kategorie: Katalogreihenfolge.
  final Map<CommandCategory, List<String>> order;
  final Set<String> hidden;

  const TileLayout({this.order = const {}, this.hidden = kDefaultHiddenKeys});

  static const standard = TileLayout();

  /// Notkommandos lassen sich nicht ausblenden – die Fahrlehrperson trägt
  /// die Verantwortung im Auto, auch wenn sie ihr Raster aufräumt.
  static bool canHide(String key) => !kExamSafetyKeys.contains(key);

  bool isHidden(String key) => canHide(key) && hidden.contains(key);

  /// Alle Kacheln einer Kategorie in der Reihenfolge des Fahrlehrers –
  /// **auch die ausgeblendeten** (für den Bearbeiten-Bildschirm).
  List<CommandDef> arranged(CommandCategory cat) {
    final all = commandsInCategory(cat);
    final saved = order[cat];
    if (saved == null) return all;
    final byKey = {for (final d in all) d.key: d};
    final result = [for (final k in saved) ?byKey.remove(k)];
    // Neu im Katalog: hinter ihren Katalog-Vorgänger einsortieren, damit
    // „Straße" auch bei einer gespeicherten Anordnung hinter der Ampel landet.
    for (final d in all.where((d) => byKey.containsKey(d.key))) {
      final i = all.indexOf(d);
      final before = i == 0 ? null : all[i - 1].key;
      final at = before == null
          ? 0
          : result.indexWhere((x) => x.key == before) + 1;
      result.insert(at, d);
    }
    return result;
  }

  /// Was im Raster steht: angeordnet, ohne Ausgeblendetes, im
  /// Prüfungsmodus zusätzlich ohne Hilfestellung.
  List<CommandDef> visible(CommandCategory cat, {bool exam = false}) => [
    for (final d in arranged(cat))
      if (!isHidden(d.key) && (!exam || allowedInExam(d))) d,
  ];

  List<CommandCategory> categoriesIn(DashboardMode m, {bool exam = false}) => [
    for (final c in categoriesInMode(m, exam: exam))
      if (visible(c, exam: exam).isNotEmpty) c,
  ];

  List<DashboardMode> modes({bool exam = false}) => [
    for (final m in DashboardMode.values)
      if (categoriesIn(m, exam: exam).isNotEmpty) m,
  ];

  TileLayout withOrder(CommandCategory cat, List<String> keys) => TileLayout(
    order: {...order, cat: List.unmodifiable(keys)},
    hidden: hidden,
  );

  TileLayout withHidden(String key, bool hide) => TileLayout(
    order: order,
    hidden: hide && canHide(key)
        ? ({...hidden, key})
        : ({...hidden}..remove(key)),
  );

  Map<String, dynamic> toJson() => {
    'order': {for (final e in order.entries) e.key.name: e.value},
    'hidden': hidden.toList(),
    'seenDefaults': kDefaultHiddenKeys.toList(),
  };

  /// Unbekanntes (umbenannte Kategorien, Müll im Speicher) wird übergangen
  /// statt zu werfen – ein kaputter Eintrag darf das Raster nicht leeren.
  factory TileLayout.fromJson(Map<String, dynamic> j) {
    final order = <CommandCategory, List<String>>{};
    final rawOrder = j['order'];
    if (rawOrder is Map) {
      for (final e in rawOrder.entries) {
        final cat = CommandCategory.values
            .where((c) => c.name == e.key)
            .firstOrNull;
        if (cat != null && e.value is List) {
          order[cat] = List.unmodifiable((e.value as List).whereType<String>());
        }
      }
    }
    final rawHidden = j['hidden'];
    if (rawHidden is! List) {
      return TileLayout(order: order);
    }
    // Neue Standard-Ausblendungen erreichen auch Geräte mit eigener
    // Anordnung – aber nur einmal: was der Fahrlehrer danach wieder
    // einblendet, steht in `seenDefaults` und bleibt sichtbar.
    final rawSeen = j['seenDefaults'];
    final seen = rawSeen is List
        ? rawSeen.whereType<String>().toSet()
        : _kDefaultsBeforeTracking;
    return TileLayout(
      order: order,
      hidden: {
        ...rawHidden.whereType<String>(),
        ...kDefaultHiddenKeys.difference(seen),
      },
    );
  }
}

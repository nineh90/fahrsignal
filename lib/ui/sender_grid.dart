import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../providers.dart';
import '../transport/signal_transport.dart';
import 'brand.dart';
import 'ptt_panel.dart';
import 'traffic_signs.dart';

/// Senderansicht (Fahrlehrer:in). Zwei umschaltbare Bereiche (Fahrt /
/// Fahrzeug), nach Kategorien in Regenbogenfarben getrennt. Einzeltipp sendet
/// sofort; die Push-to-talk-Leiste unten ist **immer** verfügbar – Kombis
/// („links und dann rechts") gehen ausschließlich über Sprache.
class SenderGrid extends ConsumerStatefulWidget {
  const SenderGrid({super.key});

  @override
  ConsumerState<SenderGrid> createState() => _SenderGridState();
}

class _SenderGridState extends ConsumerState<SenderGrid> {
  DashboardMode _mode = DashboardMode.fahrt;
  // Fahrzeug: Abfragen (true) vs. Erklären (false). Abfragen ist Standard –
  // die Fahrlehrperson prüft üblicherweise, statt vorzutragen; „erkläre …"
  // per Sprache (oder der Umschalter) holt gezielt die Erklärung.
  bool _ask = true;

  void _tap(CommandDef d) {
    // Im Prüfungsmodus wird nur abgefragt, nie erklärt.
    final ask = (_ask || ref.read(examModeProvider)) && d.hasExplanation;
    ref
        .read(transportProvider)
        .sendCommand(DriveCommand.now(d.key, d.urgency, ask: ask));
  }

  Future<void> _composeFreitext() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Freie Anweisung'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          decoration: const InputDecoration(
            hintText: 'z. B. Zeige mir den Verbandskasten und das Ablaufdatum',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Senden'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.trim().isNotEmpty) {
      ref.read(transportProvider).sendCommand(DriveCommand.freitext(text));
    }
  }

  /// Prüfungsmodus umschalten. Der Wechsel verändert das halbe Raster, deshalb
  /// eine kurze Rückmeldung – sonst wirkt es wie ein Fehler.
  void _toggleExam() {
    ref.read(examModeProvider.notifier).toggle();
    final on = ref.read(examModeProvider);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            on
                ? 'Prüfungsmodus an – nur Anweisungen, keine Hilfestellung.'
                : 'Prüfungsmodus aus – alle Kacheln wieder da.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomCodeProvider);
    final exam = ref.watch(examModeProvider);
    final connected =
        ref.watch(connectionStreamProvider).asData?.value ==
        TransportState.connected;

    // Ein Bereich kann im Prüfungsmodus leer laufen (dann fehlt er im
    // Umschalter); stand er gerade offen, auf den ersten verbliebenen wechseln.
    final modes = modesWithContent(exam: exam);
    final mode = modes.contains(_mode) ? _mode : modes.first;
    // Erklärungen sind Hilfestellung – in der Prüfung wird nur abgefragt.
    final ask = exam || _ask;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navy-Header ⇒ immer die helle Variante, sonst verschwindet das
            // Lenkrad im dunklen Grund.
            const SarahLogo(size: 30, signet: true, onDark: true),
            const SizedBox(width: 10),
            const Text('Senden'),
            const SizedBox(width: 10),
            Flexible(child: _RoomBadge(room: room)),
          ],
        ),
        actions: [
          // Verbindungsstatus kompakt als farbiges Icon – der Text hätte den
          // Header überladen. Details per Tooltip.
          Tooltip(
            message: connected ? 'Verbunden' : 'Suche Verbindung …',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                connected ? Icons.link : Icons.link_off,
                color: connected
                    ? const Color(0xFF7CF29B)
                    : const Color(0xFFFFC46B),
              ),
            ),
          ),
          IconButton(
            tooltip: exam ? 'Prüfungsmodus beenden' : 'Prüfungsmodus starten',
            isSelected: exam,
            // Nicht Icons.school – das trägt schon der Bereich „Fahrschüler".
            icon: const Icon(Icons.gavel),
            selectedIcon: const Icon(Icons.gavel, color: Color(0xFFFFC46B)),
            onPressed: _toggleExam,
          ),
          IconButton(
            tooltip: 'Hell/Dunkel',
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const _RainbowStrip(),
      ),
      body: Column(
        children: [
          if (exam) const _ExamBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: LayoutBuilder(
              builder: (context, c) {
                // Kein Scrollen: der Umschalter passt sich dem Platz an.
                // Breit = Icon+Text, mittel = nur Text, schmal (Handy
                // hochkant) = nur Icons mit Tooltip.
                final showIcons = c.maxWidth >= 560;
                final iconOnly = c.maxWidth < 400;
                return SegmentedButton<DashboardMode>(
                  segments: [
                    for (final m in modes)
                      ButtonSegment(
                        value: m,
                        icon: (showIcons || iconOnly) ? Icon(m.icon) : null,
                        label: iconOnly
                            ? null
                            : Text(
                                m.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                              ),
                        tooltip: m.label,
                      ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                );
              },
            ),
          ),
          // In der Prüfung gibt es nichts zu erklären – der Umschalter steht
          // fest auf „Abfragen" und verschwindet.
          if (mode == DashboardMode.fahrzeug && !exam)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.quiz),
                    label: Text('Abfragen'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.menu_book),
                    label: Text('Erklären'),
                  ),
                ],
                selected: {_ask},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: (s) => setState(() => _ask = s.first),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                for (final cat in categoriesInMode(mode, exam: exam))
                  _CategorySection(cat: cat, exam: exam, onTap: _tap),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SenderBottomBar(
        askDefault: ask,
        onFreitext: _composeFreitext,
        onOff: () => ref
            .read(transportProvider)
            .sendCommand(DriveCommand.now(kOffKey, Urgency.info)),
      ),
    );
  }
}

/// Kompaktes Raumcode-Badge im Header (statt langem Titeltext).
class _RoomBadge extends StatelessWidget {
  final String room;
  const _RoomBadge({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.meeting_room, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              room,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dünner Regenbogen-Streifen unter der AppBar – zeigt das Farbsystem.
class _RainbowStrip extends StatelessWidget implements PreferredSizeWidget {
  const _RainbowStrip();

  @override
  Size get preferredSize => const Size.fromHeight(4);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [for (final c in CommandCategory.values) c.color],
        ),
      ),
    );
  }
}

/// Kachelmaße – gelten für **jede** Kachel, egal ob im freien Raster oder in
/// einer Gruppenzeile. Die Breite ist eine Obergrenze: das Raster füllt die
/// Zeile, indem es die Kacheln bis auf diesen Wert wachsen lässt.
const double _kTileMaxWidth = 118;
const double _kTileHeight = 84;
const double _kTileGap = 10;

/// Spaltenzahl und daraus die Kachelbreite – dieselbe Rechnung wie in
/// `SliverGridDelegateWithMaxCrossAxisExtent`, nur selbst gemacht, damit
/// Gruppenzeilen exakt dasselbe Maß verwenden können.
double _tileWidth(double available) {
  final cols = (available / (_kTileMaxWidth + _kTileGap)).ceil().clamp(1, 999);
  return (available - _kTileGap * (cols - 1)) / cols;
}

/// Deutlich sichtbares Band, solange der Prüfungsmodus läuft. Ohne das wäre
/// das halbe fehlende Raster nicht von einem Fehler zu unterscheiden.
class _ExamBanner extends StatelessWidget {
  const _ExamBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFC62828),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.gavel, size: 17, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'PRÜFUNGSMODUS – nur Anweisungen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final CommandCategory cat;
  final bool exam;
  final void Function(CommandDef) onTap;
  const _CategorySection({
    required this.cat,
    required this.exam,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = commandsInCategory(cat, exam: exam);
    return LayoutBuilder(
      builder: (context, c) {
        final width = _tileWidth(c.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
              child: Row(
                children: [
                  Icon(cat.icon, size: 18, color: cat.color),
                  const SizedBox(width: 8),
                  Text(
                    cat.label.toUpperCase(),
                    style: TextStyle(
                      color: cat.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .08,
                    ),
                  ),
                ],
              ),
            ),
            for (final row in _rows(items)) ...[
              if (row.first.group.isEmpty)
                Wrap(
                  spacing: _kTileGap,
                  runSpacing: _kTileGap,
                  children: [
                    for (final d in row)
                      SizedBox(
                        width: width,
                        height: _kTileHeight,
                        child: _CommandTile(def: d, onTap: onTap),
                      ),
                  ],
                )
              else
                // Die Gruppe steht garantiert in einer Zeile. Passt sie bei
                // regulärer Kachelbreite nicht (schmales Handy), schrumpfen
                // nur ihre Kacheln – wachsen dürfen sie nie, sonst hätte
                // dieselbe Kachel auf dem iPad die dreifache Größe.
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: _kTileGap),
                      SizedBox(
                        width: math.min(
                          width,
                          (c.maxWidth - _kTileGap * (row.length - 1)) /
                              row.length,
                        ),
                        height: _kTileHeight,
                        child: _CommandTile(def: row[i], onTap: onTap),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: _kTileGap),
            ],
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

/// Zerlegt die Kommandos einer Kategorie in Blöcke: aufeinanderfolgende
/// Einträge mit derselben `group` bilden einen eigenen Block (= eine Zeile),
/// alles Gruppenlose fließt zusammen im normalen Raster.
List<List<CommandDef>> _rows(List<CommandDef> items) {
  final rows = <List<CommandDef>>[];
  for (final d in items) {
    if (rows.isNotEmpty && rows.last.first.group == d.group) {
      rows.last.add(d);
    } else {
      rows.add([d]);
    }
  }
  return rows;
}

class _CommandTile extends StatelessWidget {
  final CommandDef def;
  final void Function(CommandDef) onTap;
  const _CommandTile({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = tileColor(def);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(def),
        child: Stack(
          // Ohne das richtet der Stack sein Kind oben links aus – und da die
          // Column nur so breit ist wie ihr längstes Wort, klebten kurze
          // Beschriftungen („Links") samt Symbol am linken Kachelrand.
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  def.isSign
                      ? TrafficSign(def: def, size: 34)
                      : Icon(def.icon, color: Colors.white, size: 27),
                  const SizedBox(height: 6),
                  Text(
                    def.tileText,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Urgency-Indikator (Farbe/Vibration beim Empfänger)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: urgencyColor(def.urgency),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Untere Leiste des Senders: dauerhafte Push-to-talk-Leiste plus die zwei
/// Nebenwege (Anzeige aus, Freitext) – bewusst flach gehalten, damit der
/// Halteknopf dominiert.
class _SenderBottomBar extends StatelessWidget {
  final bool askDefault;
  final VoidCallback onFreitext;
  final VoidCallback onOff;
  const _SenderBottomBar({
    required this.askDefault,
    required this.onFreitext,
    required this.onOff,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PttBar(askDefault: askDefault),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.tonalIcon(
                      onPressed: onOff,
                      icon: const Icon(Icons.visibility_off, size: 20),
                      label: const Text('Anzeige aus'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton.tonalIcon(
                      onPressed: onFreitext,
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: const Text('Freie Anweisung'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

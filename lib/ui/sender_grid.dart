import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../providers.dart';
import '../transport/signal_transport.dart';
import 'brand.dart';
import 'traffic_signs.dart';

/// Senderansicht (Fahrlehrer:in). Zwei umschaltbare Bereiche (Fahrt /
/// Fahrzeug), nach Kategorien in Regenbogenfarben getrennt. Einzeltipp sendet
/// sofort; im Kombi-Modus lassen sich 2–3 Kommandos bündeln.
class SenderGrid extends ConsumerStatefulWidget {
  const SenderGrid({super.key});

  @override
  ConsumerState<SenderGrid> createState() => _SenderGridState();
}

class _SenderGridState extends ConsumerState<SenderGrid> {
  DashboardMode _mode = DashboardMode.fahrt;
  bool _combo = false;
  bool _ask = false; // Fahrzeug: Erklären (false) vs. Abfragen (true)
  final List<CommandDef> _staged = [];

  void _tap(CommandDef d) {
    if (_combo) {
      if (_staged.length < 3 && !_staged.any((s) => s.key == d.key)) {
        setState(() => _staged.add(d));
      }
      return;
    }
    ref
        .read(transportProvider)
        .sendCommand(
          DriveCommand.now(d.key, d.urgency, ask: _ask && d.hasExplanation),
        );
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

  void _sendCombo() {
    if (_staged.isEmpty) return;
    final labels = _staged.map((d) => d.label).join(' + ');
    ref
        .read(transportProvider)
        .sendCommand(
          DriveCommand.combo(
            _staged.map((d) => d.key).toList(),
            maxUrgency(_staged.map((d) => d.urgency)),
          ),
        );
    // One-Shot: nach dem Senden Kombi-Modus sofort wieder deaktivieren.
    setState(() {
      _staged.clear();
      _combo = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gesendet: $labels'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomCodeProvider);
    final connected =
        ref.watch(connectionStreamProvider).asData?.value ==
        TransportState.connected;
    final stagedKeys = _staged.map((d) => d.key).toSet();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FahrSignalLogo(
              size: 24,
              wheelColor: Colors.white,
              dotColor: kBrandNavy,
            ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<DashboardMode>(
                segments: [
                  for (final m in DashboardMode.values)
                    ButtonSegment(
                      value: m,
                      icon: Icon(m.icon),
                      label: Text(m.label),
                    ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ),
          if (_mode == DashboardMode.fahrzeug)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.menu_book),
                    label: Text('Erklären'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.quiz),
                    label: Text('Abfragen'),
                  ),
                ],
                selected: {_ask},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _ask = s.first),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                for (final cat in categoriesInMode(_mode))
                  _CategorySection(
                    cat: cat,
                    combo: _combo,
                    stagedKeys: stagedKeys,
                    onTap: _tap,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        combo: _combo,
        staged: _staged,
        onFreitext: _composeFreitext,
        onToggleCombo: () => setState(() {
          _combo = !_combo;
          if (!_combo) _staged.clear();
        }),
        onRemove: (d) => setState(() => _staged.remove(d)),
        onClear: () => setState(_staged.clear),
        onSendCombo: _sendCombo,
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

class _CategorySection extends StatelessWidget {
  final CommandCategory cat;
  final bool combo;
  final Set<String> stagedKeys;
  final void Function(CommandDef) onTap;
  const _CategorySection({
    required this.cat,
    required this.combo,
    required this.stagedKeys,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = commandsInCategory(cat);
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 118,
            mainAxisExtent: 84,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _CommandTile(
            def: items[i],
            combo: combo,
            staged: stagedKeys.contains(items[i].key),
            onTap: onTap,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  final CommandDef def;
  final bool combo;
  final bool staged;
  final void Function(CommandDef) onTap;
  const _CommandTile({
    required this.def,
    required this.combo,
    required this.staged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = tileColor(def);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(def),
        child: Stack(
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
                    def.label,
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
            // Kombi-Auswahl-Haken
            if (combo && staged)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle, size: 18, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool combo;
  final List<CommandDef> staged;
  final VoidCallback onFreitext;
  final VoidCallback onToggleCombo;
  final void Function(CommandDef) onRemove;
  final VoidCallback onClear;
  final VoidCallback onSendCombo;
  final VoidCallback onOff;
  const _BottomBar({
    required this.combo,
    required this.staged,
    required this.onFreitext,
    required this.onToggleCombo,
    required this.onRemove,
    required this.onClear,
    required this.onSendCombo,
    required this.onOff,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (combo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staged.isEmpty
                        ? 'Kachel(n) antippen, um zu kombinieren (max. 3)'
                        : 'Kombination (${staged.length}/3)',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 6),
                  if (staged.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final d in staged)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InputChip(
                                avatar: Icon(
                                  d.icon,
                                  size: 18,
                                  color: tileColor(d),
                                ),
                                label: Text(d.label),
                                onDeleted: () => onRemove(d),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: staged.isEmpty ? null : onSendCombo,
                          icon: const Icon(Icons.send),
                          label: Text('Senden (${staged.length})'),
                        ),
                      ),
                      if (staged.isNotEmpty)
                        TextButton(
                          onPressed: onClear,
                          child: const Text('Leeren'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Freie Anweisung – prominent und direkt erreichbar.
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonalIcon(
                    onPressed: onFreitext,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Freie Anweisung schreiben'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.tonalIcon(
                          onPressed: onOff,
                          icon: const Icon(Icons.visibility_off),
                          label: const Text('Anzeige aus'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: onToggleCombo,
                        style: FilledButton.styleFrom(
                          backgroundColor: combo
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          foregroundColor: combo
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        icon: Icon(combo ? Icons.layers_clear : Icons.layers),
                        label: Text(combo ? 'Fertig' : 'Kombi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

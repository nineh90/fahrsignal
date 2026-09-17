import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/command_catalog.dart';
import '../domain/tile_layout.dart';
import '../providers.dart';
import 'traffic_signs.dart';

/// „Kacheln anpassen" (SAR-120): der Fahrlehrer sortiert sein Raster selbst
/// und blendet Kacheln aus oder wieder ein.
///
/// Eine Liste statt des Rasters: Ziehen in einem Umbruch-Raster springt bei
/// jeder Zeile, und ausgeblendete Kacheln brauchen einen Platz, an dem man
/// sie wiederfindet. Hier stehen sie an ihrer Stelle, nur blasser.
class TileEditor extends ConsumerWidget {
  const TileEditor({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Standard wiederherstellen?'),
        content: const Text(
          'Reihenfolge und ausgeblendete Kacheln werden auf den '
          'Auslieferungszustand zurückgesetzt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(tileLayoutProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const modes = DashboardMode.values;
    return DefaultTabController(
      length: modes.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kacheln anpassen'),
          actions: [
            IconButton(
              tooltip: 'Standard wiederherstellen',
              icon: const Icon(Icons.restart_alt),
              onPressed: () => _confirmReset(context, ref),
            ),
          ],
          // Der Header ist navy – ohne eigene Farben verschwänden die Reiter.
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: const Color(0xFFFFC46B),
            tabs: [for (final m in modes) Tab(text: m.label)],
          ),
        ),
        body: TabBarView(children: [for (final m in modes) _ModeList(mode: m)]),
      ),
    );
  }
}

class _ModeList extends ConsumerWidget {
  final DashboardMode mode;
  const _ModeList({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(tileLayoutProvider);
    final notifier = ref.read(tileLayoutProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Zum Sortieren am Griff ziehen. Der Schalter blendet eine '
              'Kachel aus oder wieder ein.',
              style: TextStyle(color: muted),
            ),
          ),
        ),
        for (final cat in categoriesInMode(mode)) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            sliver: SliverToBoxAdapter(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CategoryList(
            items: layout.arranged(cat),
            layout: layout,
            onReorder: (keys) => notifier.reorder(cat, keys),
            onHidden: notifier.setHidden,
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CommandDef> items;
  final TileLayout layout;
  final void Function(List<String> keys) onReorder;
  final void Function(String key, bool hide) onHidden;

  const _CategoryList({
    required this.items,
    required this.layout,
    required this.onReorder,
    required this.onHidden,
  });

  @override
  Widget build(BuildContext context) {
    return SliverReorderableList(
      itemCount: items.length,
      onReorderItem: (from, to) {
        final keys = [for (final d in items) d.key];
        keys.insert(to, keys.removeAt(from));
        onReorder(keys);
      },
      itemBuilder: (context, i) {
        final d = items[i];
        return _EditorRow(
          key: ValueKey(d.key),
          index: i,
          def: d,
          hidden: layout.isHidden(d.key),
          onHidden: (hide) => onHidden(d.key, hide),
        );
      },
    );
  }
}

class _EditorRow extends StatelessWidget {
  final int index;
  final CommandDef def;
  final bool hidden;
  final ValueChanged<bool> onHidden;

  const _EditorRow({
    super.key,
    required this.index,
    required this.def,
    required this.hidden,
    required this.onHidden,
  });

  @override
  Widget build(BuildContext context) {
    final locked = !TileLayout.canHide(def.key);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      // Langes Drücken zieht auf dem Handy die ganze Zeile, der Griff sofort.
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: Opacity(
          opacity: hidden ? 0.45 : 1,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tileColor(def),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TrafficSign(def: def, size: 26),
            ),
            title: Text(def.tileText),
            subtitle: locked
                ? const Text('Notkommando – bleibt immer sichtbar')
                : hidden
                ? const Text('ausgeblendet')
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: hidden ? 'Einblenden' : 'Ausblenden',
                  child: Switch(
                    value: !hidden,
                    onChanged: locked ? null : (on) => onHidden(!on),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

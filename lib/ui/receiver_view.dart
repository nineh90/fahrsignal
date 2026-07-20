import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../providers.dart';
import '../transport/signal_transport.dart';
import '../platform/keep_awake.dart';
import 'brand.dart';
import 'traffic_signs.dart';

/// Empfängeransicht (Fahrschüler:in). **Keine bedienbaren Elemente** – große,
/// farbcodierte, animierte Anzeige. Hält das Gerät wach.
class ReceiverView extends ConsumerStatefulWidget {
  const ReceiverView({super.key});

  @override
  ConsumerState<ReceiverView> createState() => _ReceiverViewState();
}

class _ReceiverViewState extends ConsumerState<ReceiverView>
    with TickerProviderStateMixin {
  DriveCommand? _current;
  final List<DriveCommand> _history = [];

  // Einblend-Puls: startet bei jedem neuen Kommando (sofortige Erkennbarkeit).
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 430),
    value: 1,
  );

  // Gefahr-Puls: pulsiert dauerhaft, solange ein „dringend"-Kommando anliegt.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    enableKeepAwake();
  }

  @override
  void dispose() {
    _pop.dispose();
    _pulse.dispose();
    disableKeepAwake();
    super.dispose();
  }

  void _onCommand(DriveCommand cmd) {
    setState(() {
      if (cmd.isOff) {
        _current = null; // 'off' blendet die Anzeige aus
      } else {
        _current = cmd;
        _history.insert(0, cmd);
        if (_history.length > 6) _history.removeLast();
      }
    });
    if (!cmd.isOff) _pop.forward(from: 0);

    // Gefahr-Puls nur bei „dringend".
    if (!cmd.isOff && cmd.urgency == Urgency.dringend) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DriveCommand>>(commandStreamProvider, (_, next) {
      final cmd = next.asData?.value;
      if (cmd != null) _onCommand(cmd);
    });

    final connection = ref.watch(connectionStreamProvider).asData?.value;
    final lost = connection == TransportState.disconnected;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final cmd = _current;
    final bg = cmd != null ? commandColor(cmd) : Colors.black;
    final fg = cmd != null ? commandForeground(cmd) : Colors.white70;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 92),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedBuilder(
                  animation: _pop,
                  builder: (context, child) {
                    if (cmd == null || reduceMotion) return child!;
                    final t = Curves.easeOutBack.transform(
                      _pop.value.clamp(0, 1),
                    );
                    return Transform.scale(
                      scale: 0.82 + 0.18 * t,
                      child: child,
                    );
                  },
                  child: _CommandDisplay(cmd: cmd, fg: fg),
                ),
              ),
            ),
          ),
          // kurzer weißer Blitz beim Einblenden
          if (!reduceMotion)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _pop,
                builder: (_, _) => Opacity(
                  opacity: (1 - _pop.value) * 0.5,
                  child: const ColoredBox(
                    color: Colors.white,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          // Gefahr-Puls: rhythmisches Aufleuchten bei „dringend".
          if (cmd != null && cmd.urgency == Urgency.dringend && !reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, _) => Opacity(
                    opacity: 0.24 * _pulse.value,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_history.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: _HistoryStrip(history: _history, fg: fg),
            ),
          // Dezente Marke oben links (nicht bedienbar).
          Positioned(
            top: 14,
            left: 16,
            child: Opacity(
              opacity: 0.9,
              child: FahrSignalLogo(size: 26, wheelColor: fg, dotColor: bg),
            ),
          ),
          if (lost) const _ConnectionLostOverlay(),
        ],
      ),
    );
  }
}

class _CommandDisplay extends StatelessWidget {
  final DriveCommand? cmd;
  final Color fg;
  const _CommandDisplay({required this.cmd, required this.fg});

  @override
  Widget build(BuildContext context) {
    final c = cmd;
    if (c == null) {
      return Text(
        'BEREIT',
        style: TextStyle(color: fg, fontSize: 40, fontWeight: FontWeight.w600),
      );
    }
    // Frei getippte Anweisung des Fahrlehrers.
    if (c.isFreitext) {
      return _FreitextDisplay(text: c.text, fg: fg);
    }
    final primary = commandByKey(c.keys.first);
    // Fahrzeug-/Abfahrtkontroll-Themen: erklärende Anzeige statt Riesen-Wort.
    if (primary != null && primary.hasExplanation && !c.isCombo) {
      return _ExplainedDisplay(def: primary, fg: fg, ask: c.ask);
    }
    final secondaries = c.keys.skip(1).map(commandByKey).nonNulls.toList();
    final visual = primary != null && primary.isSign
        ? TrafficSign(def: primary, size: 172)
        : Icon(primary?.icon ?? Icons.info, color: fg, size: 150);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        visual,
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            (primary?.label ?? c.keys.first).toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: secondaries.isEmpty ? 68 : 52,
              fontWeight: FontWeight.bold,
              height: 1.03,
            ),
          ),
        ),
        if (secondaries.isNotEmpty) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final s in secondaries) _SecondaryChip(def: s, fg: fg),
            ],
          ),
        ],
      ],
    );
  }
}

/// Erklärende Anzeige (Fahrzeug/Abfahrtkontrolle): Icon + Titel + kurzer Text,
/// damit die Fahrschüler:in versteht, worum es geht bzw. wie es geht.
class _ExplainedDisplay extends StatelessWidget {
  final CommandDef def;
  final Color fg;
  final bool ask;
  const _ExplainedDisplay({
    required this.def,
    required this.fg,
    this.ask = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ask) ...[
            Text(
              'ZEIGE MIR',
              style: TextStyle(
                color: fg.withValues(alpha: 0.85),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Icon(def.icon, color: fg, size: ask ? 108 : 92),
          const SizedBox(height: 18),
          Text(
            def.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              // Ohne Erklärung darf der Titel größer/präsenter sein.
              fontSize: ask ? 52 : 40,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          // Erklärung nur im „Erklären"-Modus – bei „Abfragen" bleibt die
          // Lösung bewusst verborgen (Schüler:in soll es selbst zeigen).
          if (!ask) ...[
            const SizedBox(height: 16),
            Text(
              def.explanation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 22,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Freitext-Anweisung des Fahrlehrers, groß und lesbar.
class _FreitextDisplay extends StatelessWidget {
  final String text;
  final Color fg;
  const _FreitextDisplay({required this.text, required this.fg});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, color: fg, size: 60),
          const SizedBox(height: 22),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryChip extends StatelessWidget {
  final CommandDef def;
  final Color fg;
  const _SecondaryChip({required this.def, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(def.icon, color: fg, size: 30),
          const SizedBox(width: 10),
          Text(
            def.label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  final List<DriveCommand> history;
  final Color fg;
  const _HistoryStrip({required this.history, required this.fg});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final c in history.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _HistoryChip(cmd: c, fg: fg),
            ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final DriveCommand cmd;
  final Color fg;
  const _HistoryChip({required this.cmd, required this.fg});

  @override
  Widget build(BuildContext context) {
    final def = commandByKey(cmd.keys.first);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(def?.icon ?? Icons.info, color: fg, size: 17),
          const SizedBox(width: 6),
          Text(
            def?.label ?? cmd.keys.first,
            style: TextStyle(
              color: fg,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (cmd.isCombo)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '+${cmd.keys.length - 1}',
                style: TextStyle(
                  color: fg.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectionLostOverlay extends StatelessWidget {
  const _ConnectionLostOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, color: Colors.redAccent, size: 96),
            SizedBox(height: 16),
            Text(
              'VERBINDUNG\nVERLOREN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

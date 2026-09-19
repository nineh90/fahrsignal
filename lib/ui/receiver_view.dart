import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../domain/spoken_text.dart';
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
        if (_history.length > 2) _history.removeLast();
      }
    });
    if (!cmd.isOff) _pop.forward(from: 0);
    _speak(cmd);

    // Gefahr-Puls nur bei „dringend".
    if (!cmd.isOff && cmd.urgency == Urgency.dringend) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  /// Sprachausgabe (SAR-121), wenn der Fahrlehrer eine Sprache gewählt hat.
  /// Alles andere – auch 'off' – bricht eine laufende Ansage ab: was nicht
  /// mehr auf dem Schirm steht, soll auch nicht mehr im Ohr sein.
  void _speak(DriveCommand cmd) {
    final voice = ref.read(speechOutputProvider);
    final a = announcementFor(cmd);
    if (a == null) {
      voice.stop();
    } else {
      voice.speak(a.say, fallback: a.fallback, urgency: cmd.urgency);
    }
  }

  /// Der Hinweis **vor** dem aktiven. Das aktive steht groß in der Mitte –
  /// im Verlauf noch einmal wäre es doppelt. Ist die Anzeige aus, ist es der
  /// zuletzt gezeigte.
  List<DriveCommand> get _past {
    final skip = _current != null && identical(_history.first, _current);
    return _history.skip(skip ? 1 : 0).take(1).toList();
  }

  /// Zurück zum Startbildschirm – bewusst mit Rückfrage, damit während der
  /// Fahrt keine versehentliche Bedienung die Anzeige verlässt.
  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zurück zum Start?'),
        content: const Text(
          'Die Anzeige wird beendet und du kehrst zu Raumcode & Rollenwahl zurück.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bleiben'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
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
              // Unten ist Platz für den Verlauf (_HistoryStrip) reserviert.
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 205),
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
          if (_past.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: _HistoryStrip(past: _past, fg: fg),
            ),
          // Dezente Marke oben links (nicht bedienbar).
          Positioned(
            top: 14,
            left: 16,
            child: Opacity(
              opacity: 0.9,
              // Helle Variante überall außer auf Gelb ("achtung") – dort ist
              // der Grund hell und die Schrift dunkel.
              child: SarahLogo(
                size: 34,
                signet: true,
                onDark: fg.computeLuminance() > 0.5,
              ),
            ),
          ),
          // Dezenter Ausgang oben rechts – klein & mit Rückfrage, damit die
          // Sicherheits-Leitplanke "keine versehentliche Bedienung" gewahrt bleibt.
          Positioned(
            top: 6,
            right: 6,
            child: Opacity(
              opacity: 0.55,
              child: IconButton(
                tooltip: 'Zurück zum Start',
                iconSize: 22,
                color: fg,
                onPressed: _confirmExit,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          if (lost) const _ConnectionLostOverlay(),
        ],
      ),
    );
  }
}

/// Schriftgröße des Worts unter dem Schild – **eine Zeile** (SAR-122).
///
/// Das Schild trägt die Anweisung, das Wort bestätigt sie nur. Vorher stand
/// „LINKS" in 68 pt und längere Hinweise brachen über drei Zeilen um; jetzt
/// ist das die Obergrenze, und ein langer Hinweis wird kleiner statt höher.
const double _kLabelSize = 44;
const double _kComboLabelSize = 38;

class _CommandDisplay extends StatelessWidget {
  final DriveCommand? cmd;
  final Color fg;
  const _CommandDisplay({required this.cmd, required this.fg});

  @override
  Widget build(BuildContext context) {
    final c = cmd;
    if (c == null) {
      // Ruhezustand: keine aktive Anweisung → freundlicher Gruß.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car, color: fg, size: 96),
          const SizedBox(height: 22),
          Text(
            'Gute Fahrt',
            style: TextStyle(
              color: fg,
              fontSize: 46,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    // Ein Verkehrszeichen trägt mehr Details als ein Piktogramm (drei Pfeile
    // im Kreisverkehr, die Ampel im Dreieck) und darf deshalb größer stehen –
    // mitwachsend mit dem Gerät, aber gedeckelt, damit auf einem kleinen
    // Handy neben dem Wort darunter noch Platz bleibt.
    final signSize = (MediaQuery.sizeOf(context).shortestSide * 0.5).clamp(
      150.0,
      260.0,
    );
    final baseVisual = primary != null
        ? TrafficSign(def: primary, size: signSize, color: fg)
        : Icon(Icons.info, color: fg, size: 150);

    // Ordnungszahl als Plakette am Symbol: „zweite Straße links" muss auf
    // einen Blick von „links" unterscheidbar sein.
    final visual = c.hasOrdinal
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              baseVisual,
              Positioned(
                top: -6,
                right: -10,
                child: _OrdinalBadge(ord: c.ord, fg: fg, bg: commandColor(c)),
              ),
            ],
          )
        : baseVisual;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        visual,
        const SizedBox(height: 20),
        // Nur das **Wort** passt sich an, nicht das Zeichen: ohne eigene
        // Begrenzung zog ein langes Label den umgebenden FittedBox zusammen
        // und das Schild wurde nebenbei halb so groß wie bei „LINKS" –
        // gleiche Anzeige, zwei Größen. Das Wort steht deshalb in eigener,
        // fester Breite – in einer Zeile, bei Überlänge verkleinert.
        SizedBox(
          width: MediaQuery.sizeOf(context).width - 40,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              displayLabel(c).toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: fg,
                fontSize: secondaries.isNotEmpty
                    ? _kComboLabelSize
                    : _kLabelSize,
                fontWeight: FontWeight.bold,
                height: 1.05,
              ),
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

/// Ordnungszahl-Plakette am Symbol („2." bei „zweite Straße links").
/// Gefüllter Kreis in der Vordergrundfarbe, Ziffer im Flächenton – dadurch
/// bleibt sie auf blauem, gelbem und rotem Grund gleich gut lesbar.
class _OrdinalBadge extends StatelessWidget {
  final int ord;
  final Color fg;
  final Color bg;

  const _OrdinalBadge({required this.ord, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
      child: Text(
        '$ord.',
        style: TextStyle(
          color: bg,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
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
          TrafficSign(def: def, size: ask ? 132 : 116, color: fg),
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
          // Auch hier das Schild: „links und dann rechts" zeigte sonst oben
          // ein Schild und daneben einen Icon-Pfeil für dieselbe Sache.
          TrafficSign(def: def, size: 34, color: fg),
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

/// Verlauf unter der Anzeige (SAR-122): der Hinweis **vor** dem aktiven, als
/// Karte mit dem Schild über dem Wort. Nur einer – zwei waren auf dem Handy
/// zu klein, um sie aus dem Augenwinkel zu lesen.
///
/// Trotzdem eindeutig vergangen: Überschrift „ZUVOR", gedämpft, und das
/// Schild bleibt deutlich kleiner als das aktive in der Mitte (84 gegenüber
/// 150–260).
class _HistoryStrip extends StatelessWidget {
  /// Neuester zuerst (links).
  final List<DriveCommand> past;
  final Color fg;
  const _HistoryStrip({required this.past, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ZUVOR',
            style: TextStyle(
              color: fg.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in past)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _HistoryCard(cmd: c, fg: fg),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const double _kPastSignSize = 84;

class _HistoryCard extends StatelessWidget {
  final DriveCommand cmd;
  final Color fg;
  const _HistoryCard({required this.cmd, required this.fg});

  @override
  Widget build(BuildContext context) {
    final def = commandByKey(cmd.keys.first);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Opacity(
        opacity: 0.78,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fg.withValues(alpha: 0.28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dasselbe Schild wie groß in der Mitte – der Verlauf spricht
              // dieselbe Bildsprache wie die Anzeige.
              SizedBox(
                height: _kPastSignSize,
                child: def != null
                    ? TrafficSign(def: def, size: _kPastSignSize, color: fg)
                    : Icon(Icons.chat_bubble_outline, color: fg, size: 64),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      // Trägt die Ordnungszahl mit: sonst stünden „links"
                      // und „2. Straße links" im Verlauf identisch da.
                      cmd.isFreitext ? cmd.text : displayLabel(cmd),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (cmd.isCombo)
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Text(
                        '+${cmd.keys.length - 1}',
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.8),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

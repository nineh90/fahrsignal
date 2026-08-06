import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../domain/speech/command_parser.dart';
import '../platform/speech/speech_recognizer.dart';
import '../providers.dart';
import 'traffic_signs.dart';

/// Dauerhaft sichtbare Push-to-talk-Leiste des Senders.
///
/// Sprache ist kein eigener Modus mehr, sondern immer verfügbar: Knopf halten
/// → sprechen → loslassen. Sicher Erkanntes geht **ohne Verzögerung** raus
/// (im Auto zählt jede Zehntelsekunde), mit „Zurücknehmen" als Notausgang in
/// der Bestätigung. Unsicheres wird zur Auswahl gestellt, Unverstandenes kann
/// als Freitext raus. Mehrere Kommandos in einem Satz („links und dann
/// rechts") gehen als Kombination raus – das ersetzt den früheren Kombi-Modus
/// der Kacheln.
class PttBar extends ConsumerStatefulWidget {
  /// Keys des aktuell gewählten Dashboard-Bereichs – Treffer außerhalb werden
  /// abgewertet, damit „Felgen" im Fahrtmodus nicht gegen „folgen" gewinnt.
  final Set<String> scopeKeys;

  const PttBar({super.key, required this.scopeKeys});

  @override
  ConsumerState<PttBar> createState() => _PttBarState();
}

class _PttBarState extends ConsumerState<PttBar> {
  StreamSubscription<SpeechResult>? _resultSub;
  StreamSubscription<SpeechStatus>? _statusSub;

  bool _holding = false;
  bool _listening = false;
  String _interim = '';

  /// Letztes Ergebnis, das zur Auswahl steht (unsicher/mehrdeutig).
  ParsedIntent? _pending;

  /// Schutz gegen Doppelauslösung: gleicher Key+Ordinal in kurzer Folge.
  String _lastSentSignature = '';
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    final recognizer = ref.read(speechRecognizerProvider);
    _resultSub = recognizer.results.listen(_onResult);
    _statusSub = recognizer.status.listen((s) {
      if (!mounted) return;
      setState(() => _listening = s == SpeechStatus.listening);
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Urgency _urgencyOf(String key) => commandByKey(key)?.urgency ?? Urgency.info;

  void _onResult(SpeechResult r) {
    if (!mounted) return;

    if (!r.isFinal) {
      setState(() => _interim = r.transcript);
      return;
    }

    setState(() => _interim = '');
    final intent = parseUtterance(
      r.transcript,
      asrConfidence: r.confidence <= 0 ? 0.9 : r.confidence,
      scopeKeys: widget.scopeKeys,
      urgencyOf: _urgencyOf,
    );

    if (intent.canAutoSend) {
      _send(intent.toCommand());
      setState(() => _pending = null);
    } else {
      setState(() => _pending = intent);
    }
  }

  void _send(DriveCommand cmd) {
    // Doppelte Auslösung innerhalb von 1,5 s verwerfen – die Erkennung
    // liefert nach einem Neustart gelegentlich dasselbe Ergebnis erneut.
    final signature = '${cmd.keys.join('+')}|${cmd.ord}';
    final now = DateTime.now();
    if (signature == _lastSentSignature &&
        now.difference(_lastSentAt) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastSentSignature = signature;
    _lastSentAt = now;

    ref.read(transportProvider).sendCommand(cmd);

    // Bestätigung mit Notausgang – als Snackbar statt fester Karte, damit die
    // Leiste kompakt bleibt und der Halteknopf nie verdeckt wird.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Gesendet: ${displayLabel(cmd)}'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Zurücknehmen',
            onPressed: () => ref
                .read(transportProvider)
                .sendCommand(DriveCommand.now(kOffKey, Urgency.info)),
          ),
        ),
      );
  }

  Future<void> _startHold() async {
    final recognizer = ref.read(speechRecognizerProvider);
    if (!recognizer.isSupported) {
      _showError(
        'Dieses Gerät bietet keine Spracherkennung – '
        'am Handy im Browser öffnen.',
      );
      return;
    }

    // Mikrofonfreigabe beim ersten Halten anfragen – das ist eine echte
    // Nutzergeste (Safari verlangt das) und passiert, bevor es losgeht.
    if (ref.read(micPermissionProvider) != true) {
      final granted = await recognizer.warmUp();
      if (!mounted) return;
      ref.read(micPermissionProvider.notifier).set(granted);
      if (!granted) {
        _showError(recognizer.lastError);
        return;
      }
    }

    setState(() {
      _holding = true;
      _pending = null;
      _interim = '';
    });
    await recognizer.start();
  }

  Future<void> _endHold() async {
    if (!_holding) return;
    setState(() => _holding = false);
    await ref.read(speechRecognizerProvider).stop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? 'Mikrofon nicht verfügbar' : message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supported = ref.watch(speechRecognizerProvider).isSupported;
    final active = _holding || _listening;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Candidates(
              intent: _pending!,
              onPick: (cmd) {
                _send(cmd);
                setState(() => _pending = null);
              },
              onFreitext: () {
                final text = _pending!.transcript.trim();
                if (text.isNotEmpty) {
                  ref
                      .read(transportProvider)
                      .sendCommand(DriveCommand.freitext(text));
                }
                setState(() => _pending = null);
              },
              onDiscard: () => setState(() => _pending = null),
            ),
          ),
        // Live-Mitschrift während des Sprechens – sonst unsichtbar, damit die
        // Leiste im Normalzustand flach bleibt.
        if (active)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _interim.isEmpty ? 'Sprechen …' : _interim,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: _interim.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
        _HoldButton(
          active: active,
          enabled: supported,
          onStart: _startHold,
          onEnd: _endHold,
        ),
      ],
    );
  }
}

/// Der Halteknopf – volle Breite, bewusst hoch: er wird im Fahrbetrieb blind
/// getroffen und ist der wichtigste Bedienpunkt des Senders.
class _HoldButton extends StatelessWidget {
  final bool active;
  final bool enabled;
  final Future<void> Function() onStart;
  final Future<void> Function() onEnd;

  const _HoldButton({
    required this.active,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = !enabled
        ? scheme.surfaceContainerHighest
        : active
        ? scheme.error
        : scheme.primary;
    final foreground = !enabled
        ? scheme.onSurfaceVariant
        : active
        ? scheme.onError
        : scheme.onPrimary;

    return Semantics(
      button: true,
      label: 'Zum Sprechen halten',
      child: GestureDetector(
        onTapDown: (_) => onStart(),
        onTapUp: (_) => onEnd(),
        onTapCancel: () => onEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 64,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: background.withValues(alpha: active ? .45 : .3),
                  blurRadius: active ? 22 : 10,
                  spreadRadius: active ? 2 : 0,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.mic : Icons.mic_none,
                size: 30,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Text(
                active ? 'Ich höre …' : 'Halten & sprechen',
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unsicher erkannt: zur Auswahl stellen statt raten.
class _Candidates extends StatelessWidget {
  final ParsedIntent intent;
  final void Function(DriveCommand) onPick;
  final VoidCallback onFreitext;
  final VoidCallback onDiscard;

  const _Candidates({
    required this.intent,
    required this.onPick,
    required this.onFreitext,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unmatched = intent.outcome == ParseOutcome.unmatched;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              unmatched ? 'Nicht als Kommando erkannt' : 'Bitte bestätigen',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('„${intent.transcript}"', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            if (!unmatched)
              _CandidateTile(
                cmd: intent.toCommand(),
                onTap: () => onPick(intent.toCommand()),
              ),

            for (final key in intent.alternatives)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _CandidateTile(
                  cmd: DriveCommand.now(
                    key,
                    commandByKey(key)?.urgency ?? Urgency.info,
                  ),
                  onTap: () => onPick(
                    DriveCommand.now(
                      key,
                      commandByKey(key)?.urgency ?? Urgency.info,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onFreitext,
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Als Freitext'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: onDiscard,
                    child: const Text('Verwerfen'),
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

class _CandidateTile extends StatelessWidget {
  final DriveCommand cmd;
  final VoidCallback onTap;

  const _CandidateTile({required this.cmd, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final def = commandByKey(cmd.key);
    final color = commandColor(cmd);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (def != null && def.isSign)
                TrafficSign(def: def, size: 34)
              else
                Icon(
                  def?.icon ?? Icons.info,
                  size: 30,
                  color: commandForeground(cmd),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayLabel(cmd).toUpperCase(),
                  style: TextStyle(
                    color: commandForeground(cmd),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.send, size: 20, color: commandForeground(cmd)),
            ],
          ),
        ),
      ),
    );
  }
}

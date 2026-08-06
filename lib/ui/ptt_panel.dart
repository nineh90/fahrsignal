import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/command_catalog.dart';
import '../domain/drive_command.dart';
import '../domain/speech/command_parser.dart';
import '../platform/speech/speech_recognizer.dart';
import '../providers.dart';
import 'traffic_signs.dart';

/// Push-to-talk-Bedienteil des Senders.
///
/// Ablauf: Knopf halten → sprechen → loslassen. Sicher Erkanntes geht **ohne
/// Verzögerung** raus (im Auto zählt jede Zehntelsekunde), mit „Zurücknehmen"
/// als Notausgang. Unsicheres wird zur Auswahl gestellt, Unverstandenes kann
/// als Freitext raus.
class PttPanel extends ConsumerStatefulWidget {
  /// Keys des aktuell gewählten Dashboard-Bereichs – Treffer außerhalb werden
  /// abgewertet, damit „Felgen" im Fahrtmodus nicht gegen „folgen" gewinnt.
  final Set<String> scopeKeys;

  const PttPanel({super.key, required this.scopeKeys});

  @override
  ConsumerState<PttPanel> createState() => _PttPanelState();
}

class _PttPanelState extends ConsumerState<PttPanel> {
  StreamSubscription<SpeechResult>? _resultSub;
  StreamSubscription<SpeechStatus>? _statusSub;

  bool _holding = false;
  bool _listening = false;
  String _interim = '';

  /// Letztes Ergebnis, das zur Auswahl steht (unsicher/mehrdeutig).
  ParsedIntent? _pending;

  /// Zuletzt gesendetes Kommando – Grundlage für „Zurücknehmen".
  DriveCommand? _sent;

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

  Urgency _urgencyOf(String key) =>
      commandByKey(key)?.urgency ?? Urgency.info;

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
    setState(() => _sent = cmd);
  }

  void _undo() {
    ref.read(transportProvider).sendCommand(
      DriveCommand.now(kOffKey, Urgency.info),
    );
    setState(() => _sent = null);
  }

  Future<void> _startHold() async {
    final recognizer = ref.read(speechRecognizerProvider);
    if (!recognizer.isSupported) return;

    // Falls beim Umschalten noch nicht gefragt wurde (oder abgelehnt war),
    // hier nachholen – auch das ist eine echte Nutzergeste.
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.isEmpty ? 'Mikrofon nicht verfügbar' : message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _endHold() async {
    if (!_holding) return;
    setState(() => _holding = false);
    await ref.read(speechRecognizerProvider).stop();
  }

  Future<void> _warmUp() async {
    final recognizer = ref.read(speechRecognizerProvider);
    final granted = await recognizer.warmUp();
    if (!mounted) return;
    ref.read(micPermissionProvider.notifier).set(granted);
    if (!granted) _showError(recognizer.lastError);
  }

  @override
  Widget build(BuildContext context) {
    final recognizer = ref.watch(speechRecognizerProvider);
    final micGranted = ref.watch(micPermissionProvider);
    final theme = Theme.of(context);

    if (!recognizer.isSupported) {
      return _Notice(
        icon: Icons.mic_off,
        title: 'Sprache hier nicht verfügbar',
        detail:
            'Dieses Gerät bietet keine Spracherkennung. Am Handy im Browser '
            'öffnen, oder auf Tasten umschalten.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // Nur zeigen, wenn die Freigabe fehlt. Ist sie erteilt, wäre der Knopf
        // nur Ballast auf einem Bildschirm, der im Auto schnell lesbar sein muss.
        if (micGranted != true)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              onPressed: _warmUp,
              icon: Icon(
                micGranted == false ? Icons.mic_off : Icons.mic_none,
              ),
              label: Text(
                micGranted == false
                    ? 'Mikrofon erneut anfragen'
                    : 'Mikrofon aktivieren',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        if (micGranted == false)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              recognizer.lastError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),

        // Was gerade verstanden wird – noch nichts Gesendetes.
        SizedBox(
          height: 34,
          child: Center(
            child: Text(
              _interim.isEmpty
                  ? (_holding ? 'Sprechen …' : 'Knopf halten und sprechen')
                  : _interim,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: _interim.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        Center(child: _MicButton(
          active: _holding || _listening,
          onStart: _startHold,
          onEnd: _endHold,
        )),
        const SizedBox(height: 20),

        if (_pending != null) _Candidates(
          intent: _pending!,
          onPick: (cmd) {
            _send(cmd);
            setState(() => _pending = null);
          },
          onFreitext: () {
            final text = _pending!.transcript.trim();
            if (text.isNotEmpty) {
              ref.read(transportProvider).sendCommand(
                DriveCommand.freitext(text),
              );
            }
            setState(() => _pending = null);
          },
          onDiscard: () => setState(() => _pending = null),
        ),

        if (_pending == null && _sent != null)
          _SentCard(cmd: _sent!, onUndo: _undo),
      ],
    );
  }
}

/// Der Halteknopf. Bewusst groß – er wird im Fahrbetrieb blind getroffen.
class _MicButton extends StatelessWidget {
  final bool active;
  final Future<void> Function() onStart;
  final Future<void> Function() onEnd;

  const _MicButton({
    required this.active,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Zum Sprechen halten',
      child: GestureDetector(
        onTapDown: (_) => onStart(),
        onTapUp: (_) => onEnd(),
        onTapCancel: () => onEnd(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: active ? 168 : 152,
          height: active ? 168 : 152,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? scheme.error : scheme.primary,
            boxShadow: [
              BoxShadow(
                color: (active ? scheme.error : scheme.primary)
                    .withValues(alpha: .35),
                blurRadius: active ? 28 : 12,
                spreadRadius: active ? 4 : 0,
              ),
            ],
          ),
          child: Icon(
            active ? Icons.mic : Icons.mic_none,
            size: 68,
            color: active ? scheme.onError : scheme.onPrimary,
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

/// Bestätigung des Gesendeten – mit Notausgang.
class _SentCard extends StatelessWidget {
  final DriveCommand cmd;
  final VoidCallback onUndo;

  const _SentCard({required this.cmd, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = commandByKey(cmd.key);
    return Card(
      margin: EdgeInsets.zero,
      color: commandColor(cmd),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (def != null && def.isSign)
              TrafficSign(def: def, size: 38)
            else
              Icon(
                def?.icon ?? Icons.info,
                size: 34,
                color: commandForeground(cmd),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'gesendet',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: commandForeground(cmd).withValues(alpha: .8),
                    ),
                  ),
                  Text(
                    displayLabel(cmd).toUpperCase(),
                    style: TextStyle(
                      color: commandForeground(cmd),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Zurücknehmen'),
              style: TextButton.styleFrom(
                foregroundColor: commandForeground(cmd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
/// (im Auto zählt jede Zehntelsekunde); die Bestätigung erscheint kurz im
/// Halteknopf selbst, ein Fehlgriff wird über „Anzeige aus" korrigiert.
/// Unsicheres wird zur Auswahl gestellt, Unverstandenes kann als Freitext
/// raus. Mehrere Kommandos in einem Satz („links und dann rechts") gehen als
/// Kombination raus – das ersetzt den früheren Kombi-Modus der Kacheln.
class PttBar extends ConsumerStatefulWidget {
  /// Stand des Erklären/Abfragen-Umschalters. Gilt als Vorgabe für Kommandos
  /// mit Erklärung; ein gesprochener Marker („frag … ab", „erkläre …")
  /// übersteuert ihn.
  final bool askDefault;

  const PttBar({super.key, this.askDefault = false});

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

  /// Kurz angezeigte Sendebestätigung – erscheint **im** Halteknopf, damit
  /// sie keine Kacheln verdeckt. Zurücknehmen läuft über „Anzeige aus".
  DriveCommand? _confirmed;

  /// Kurzer Hinweis im Halteknopf („Nichts verstanden").
  String? _notice;
  Timer? _flashTimer;

  /// Kam in diesem Haltevorgang ein Endergebnis an? Safari/Chrome liefern
  /// bei leiser oder abgebrochener Aufnahme manchmal keines – dann werten
  /// wir das letzte Zwischenergebnis aus, statt stumm zu bleiben.
  bool _gotFinal = false;

  @override
  void initState() {
    super.initState();
    final recognizer = ref.read(speechRecognizerProvider);
    _resultSub = recognizer.results.listen(_onResult);
    _statusSub = recognizer.status.listen((s) {
      if (!mounted) return;
      final listening = s == SpeechStatus.listening;
      if (!listening && !_holding) _handleRecognitionEnd();
      setState(() => _listening = listening);
      // Fehler der Erkennung selbst (Funkloch, Mikrofon weg) blieben bisher
      // unsichtbar: der Knopf ging einfach in den Normalzustand zurück und es
      // passierte nichts. Im Auto ist das nicht von „nicht verstanden" zu
      // unterscheiden – deshalb der Klartext.
      if (s == SpeechStatus.error && recognizer.lastError.isNotEmpty) {
        _flashNotice(recognizer.lastError);
      }
    });
  }

  @override
  void dispose() {
    _resultSub?.cancel();
    _statusSub?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  Urgency _urgencyOf(String key) => commandByKey(key)?.urgency ?? Urgency.info;

  /// Löst die Abfrage-Entscheidung auf: gesprochener Marker vor Umschalter,
  /// und nur für Einzelkommandos, die überhaupt eine Erklärung haben.
  bool _resolveAsk(ParsedIntent intent, String key) =>
      !intent.isCombo &&
      (commandByKey(key)?.hasExplanation ?? false) &&
      (intent.ask ?? widget.askDefault);

  /// Bleibt für diese Äußerung im Prüfungsmodus überhaupt etwas übrig?
  bool _examBlocks(ParsedIntent intent) {
    if (!ref.read(examModeProvider)) return false;
    final primaryOk =
        intent.key != null && commandAllowedInExam(intent.toCommand());
    if (primaryOk || intent.alternatives.any(keyAllowedInExam)) return false;
    // Ohne jeden Katalogtreffer war es freie Rede – dann bleibt der
    // Freitext-Weg offen, den der Prüfer ohnehin selbst formuliert.
    return intent.key != null || intent.alternatives.isNotEmpty;
  }

  /// Alternativen der Rückfrage, in der Prüfung um die Hilfestellungen
  /// gekürzt – eine gesperrte Kachel darf auch hier nicht auftauchen.
  List<String> _offeredAlternatives(ParsedIntent intent) =>
      ref.read(examModeProvider)
      ? intent.alternatives.where(keyAllowedInExam).toList()
      : intent.alternatives;

  void _onResult(SpeechResult r) {
    if (!mounted) return;

    if (!r.isFinal) {
      setState(() => _interim = r.transcript);
      return;
    }

    _gotFinal = true;
    setState(() => _interim = '');
    _handleTranscript(r.hypotheses, r.confidence <= 0 ? 0.9 : r.confidence);
  }

  void _handleTranscript(
    List<String> hypotheses,
    double asrConfidence, {
    bool provisional = false,
  }) {
    final intent = parseBestOf(
      hypotheses,
      asrConfidence: asrConfidence,
      provisional: provisional,
      urgencyOf: _urgencyOf,
    );

    if (intent.canAutoSend) {
      _send(intent.toCommand(asAsk: _resolveAsk(intent, intent.key!)));
      setState(() => _pending = null);
      return;
    }

    // Rückfrage: im Prüfungsmodus erst gar nichts Gesperrtes zur Auswahl
    // stellen. Bleibt nichts übrig, kurz Bescheid geben statt eine leere
    // Karte zu zeigen.
    if (_examBlocks(intent)) {
      setState(() => _pending = null);
      _flashNotice('Im Prüfungsmodus gesperrt');
      return;
    }
    setState(() => _pending = intent);
  }

  /// Erkennung ist zu Ende (Status idle/error nach dem Loslassen), aber es
  /// kam kein Endergebnis: letztes Zwischenergebnis auswerten – mit
  /// gedrückter Konfidenz, sodass es immer in der Rückfrage landet. War gar
  /// nichts zu hören, kurz Bescheid geben statt stumm zu bleiben.
  void _handleRecognitionEnd() {
    if (_gotFinal) return;
    _gotFinal = true;
    final text = _interim.trim();
    setState(() => _interim = '');
    if (text.isEmpty) {
      _flashNotice('Nichts verstanden – nochmal versuchen');
    } else {
      _handleTranscript([text], 0.6, provisional: true);
    }
  }

  void _flashNotice(String text) {
    _flashTimer?.cancel();
    setState(() {
      _notice = text;
      _confirmed = null;
    });
    _flashTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _send(DriveCommand cmd) {
    // Die Sprache erreicht den Katalog an den Kacheln vorbei – der
    // Prüfungsmodus wäre löchrig, wenn „Schulterblick" gesprochen doch
    // durchginge. Notkommandos sind davon ausgenommen (siehe Katalog).
    if (ref.read(examModeProvider) && !commandAllowedInExam(cmd)) {
      _flashNotice('Im Prüfungsmodus gesperrt');
      return;
    }

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

    _flashTimer?.cancel();
    setState(() {
      _confirmed = cmd;
      _notice = null;
    });
    _flashTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _confirmed = null);
    });
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
    _gotFinal = false;
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
    final exam = ref.watch(examModeProvider);

    // Primärvorschlag der Rückfrage; im Prüfungsmodus fällt er weg, wenn er
    // dort nichts zu suchen hat. Die Alternativen sind schon gefiltert.
    DriveCommand? primary;
    if (_pending?.outcome == ParseOutcome.matched) {
      final cmd = _pending!.toCommand(
        asAsk: _resolveAsk(_pending!, _pending!.key!),
      );
      if (!exam || commandAllowedInExam(cmd)) primary = cmd;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pending != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Candidates(
              intent: _pending!,
              alternatives: _offeredAlternatives(_pending!),
              primary: primary,
              alternativeOf: (key) => DriveCommand.now(
                key,
                _urgencyOf(key),
                ask: _resolveAsk(_pending!, key),
              ),
              onPick: (cmd) {
                _send(cmd);
                setState(() => _pending = null);
              },
              onFreitext: () {
                final text = _pending!.transcript.trim();
                if (text.isNotEmpty) {
                  _send(DriveCommand.freitext(text));
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
          confirmedLabel: _confirmed == null ? null : displayLabel(_confirmed!),
          noticeLabel: _notice,
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

  /// Label des gerade Gesendeten – wird für ~2,5 s im Knopf bestätigt.
  final String? confirmedLabel;

  /// Kurzer Hinweis („Nichts verstanden") – ebenfalls im Knopf.
  final String? noticeLabel;

  final Future<void> Function() onStart;
  final Future<void> Function() onEnd;

  const _HoldButton({
    required this.active,
    required this.enabled,
    required this.confirmedLabel,
    required this.noticeLabel,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Bestätigung/Hinweis nur zeigen, wenn nicht gerade gesprochen wird –
    // beim erneuten Halten hat das Zuhören Vorrang.
    final confirming = !active && confirmedLabel != null;
    final noticing = !active && !confirming && noticeLabel != null;
    final background = !enabled
        ? scheme.surfaceContainerHighest
        : active
        ? scheme.error
        : confirming
        ? const Color(0xFF2E7D32)
        : noticing
        ? const Color(0xFF546E7A)
        : scheme.primary;
    final foreground = !enabled
        ? scheme.onSurfaceVariant
        : active
        ? scheme.onError
        : Colors.white;

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
                confirming
                    ? Icons.check_circle
                    : noticing
                    ? Icons.hearing_disabled
                    : active
                    ? Icons.mic
                    : Icons.mic_none,
                size: 30,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  confirming
                      ? 'Gesendet: ${confirmedLabel!.toUpperCase()}'
                      : noticing
                      ? noticeLabel!
                      : active
                      ? 'Ich höre …'
                      : 'Halten & sprechen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
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

  /// Zur Auswahl gestellte Alternativ-Keys – im Prüfungsmodus bereits um die
  /// gesperrten gekürzt, deshalb nicht direkt aus [intent] gelesen.
  final List<String> alternatives;

  /// Sendefertiges Primärkommando; null bei „nicht erkannt" oder wenn es die
  /// Prüfung nicht erlaubt.
  final DriveCommand? primary;

  /// Baut das sendefertige Kommando zu einem Alternativ-Key (inkl. Abfrage-
  /// Entscheidung – die kennt nur der Aufrufer).
  final DriveCommand Function(String key) alternativeOf;

  final void Function(DriveCommand) onPick;
  final VoidCallback onFreitext;
  final VoidCallback onDiscard;

  const _Candidates({
    required this.intent,
    required this.alternatives,
    required this.primary,
    required this.alternativeOf,
    required this.onPick,
    required this.onFreitext,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // „Nicht erkannt" gilt auch, wenn der Treffer im Prüfungsmodus wegfiel –
    // aus Sicht des Bedieners steht dann genauso nichts zur Auswahl.
    final unmatched =
        intent.outcome == ParseOutcome.unmatched || primary == null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              unmatched
                  ? (alternatives.isEmpty
                        ? 'Nicht als Kommando erkannt'
                        : 'Meintest du …?')
                  : 'Bitte bestätigen',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text('„${intent.transcript}"', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            if (primary != null)
              _CandidateTile(cmd: primary!, onTap: () => onPick(primary!)),

            for (final key in alternatives)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _CandidateTile(
                  cmd: alternativeOf(key),
                  onTap: () => onPick(alternativeOf(key)),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/drive_command.dart';
import '../providers.dart';
import 'brand.dart';
import 'receiver_view.dart';
import 'sender_grid.dart';

/// Startscreen: 6-stelliger Raumcode + Rollenwahl. Prod-Einstieg.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  final _controller = TextEditingController(text: 'DEV');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter(Role role) {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen Raumcode eingeben.')),
      );
      return;
    }
    ref.read(roomCodeProvider.notifier).set(code);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            role == Role.sender ? const SenderGrid() : const ReceiverView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FahrSignalLogo(size: 92),
                const SizedBox(height: 14),
                const FahrSignalWordmark(fontSize: 34),
                const SizedBox(height: 10),
                Text(
                  kBrandTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gleicher Raumcode auf beiden Geräten',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 28, letterSpacing: 4),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[A-Z0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Raumcode',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: () => _enter(Role.sender),
                    icon: const Icon(Icons.send),
                    label: const Text('Senden (Fahrlehrer)'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _enter(Role.receiver),
                    icon: const Icon(Icons.tv),
                    label: const Text('Empfangen (Fahrschüler)'),
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

/// Erzwingt Großbuchstaben im Raumcode-Feld.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}

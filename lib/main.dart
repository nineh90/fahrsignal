import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'transport/signal_transport.dart';
import 'transport/ws_transport.dart';
import 'ui/brand.dart';
import 'ui/start_screen.dart';

/// Wohin sich die Geräte verbinden, per `--dart-define=RELAY_URL=wss://…`.
/// Ohne Angabe gilt der Relay neben der Seite: live hinter derselben Domain
/// unter `/ws` (Traefik routet dorthin, siehe `deploy/docker-compose.yml`),
/// lokal über http der Relay aus `bin/relay_server.dart` auf Port 8080.
const _relayOverride = String.fromEnvironment('RELAY_URL');

String get _relayUrl {
  final override = _relayOverride.trim();
  if (override.isNotEmpty) return override;
  final base = Uri.base;
  final host = base.host.isEmpty ? 'localhost' : base.host;
  if (base.scheme == 'https') return 'wss://$host/ws';
  return 'ws://$host:8080';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        // Transport-Wahl an genau EINER Stelle – die UI bleibt unverändert.
        transportProvider.overrideWith((ref) {
          final room = ref.watch(roomCodeProvider);
          final SignalTransport t = WsTransport(room, relayUrl: _relayUrl);
          ref.onDispose(t.dispose);
          return t;
        }),
      ],
      child: const FahrSignalApp(),
    ),
  );
}

class FahrSignalApp extends ConsumerWidget {
  const FahrSignalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'FahrSignal',
      debugShowCheckedModeBanner: false,
      theme: fahrSignalTheme(Brightness.light),
      darkTheme: fahrSignalTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const StartScreen(),
    );
  }
}

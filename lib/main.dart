import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'transport/ws_transport.dart';
import 'ui/brand.dart';
import 'ui/start_screen.dart';

/// Relay-URL: gleicher Host wie die geladene Seite, Port 8080.
/// So funktioniert es lokal (localhost) und im LAN (IP des Rechners).
String get _relayUrl {
  final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
  return 'ws://$host:8080';
}

void main() => runApp(
  ProviderScope(
    overrides: [
      // Echte App: WebSocket-Relay statt In-Process-Fake.
      transportProvider.overrideWith((ref) {
        final room = ref.watch(roomCodeProvider);
        final t = WsTransport(room, relayUrl: _relayUrl);
        ref.onDispose(t.dispose);
        return t;
      }),
    ],
    child: const FahrSignalApp(),
  ),
);

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

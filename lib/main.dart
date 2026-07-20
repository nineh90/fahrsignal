import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers.dart';
import 'transport/signal_transport.dart';
import 'transport/supabase_transport.dart';
import 'transport/ws_transport.dart';
import 'ui/brand.dart';
import 'ui/start_screen.dart';

/// Konfiguration per `--dart-define` (Build-Zeit) – **niemals im Repo**:
///   flutter build web \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_KEY=sb_publishable_...
/// Sind beide gesetzt → Supabase Realtime (Cloud). Sonst → lokaler WS-Relay.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

/// Relay-URL für den lokalen WS-Fallback (nur ohne Supabase-Konfiguration):
/// gleicher Host wie die geladene Seite, Port 8080.
String get _relayUrl {
  final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
  return 'ws://$host:8080';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env-Werte defensiv säubern: ein versehentliches Leerzeichen/Newline in der
  // Build-Umgebung (z. B. Vercel) darf Supabases Uri.parse nicht sprengen
  // ("Scheme not starting with alphabetic character" → weißer Bildschirm).
  final supabaseUrl = _supabaseUrl.trim();
  final supabaseKey = _supabaseKey.trim();

  final useSupabase = supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
  if (useSupabase) {
    await Supabase.initialize(
      url: supabaseUrl,
      // Neues Supabase-Key-Format (sb_publishable_…). Ist client-öffentlich.
      publishableKey: supabaseKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        // Transport-Wahl an genau EINER Stelle – die UI bleibt unverändert.
        transportProvider.overrideWith((ref) {
          final room = ref.watch(roomCodeProvider);
          final SignalTransport t = useSupabase
              ? SupabaseTransport(room)
              : WsTransport(room, relayUrl: _relayUrl);
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

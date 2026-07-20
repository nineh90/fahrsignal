import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/drive_command.dart';
import 'transport/signal_transport.dart';
import 'transport/fake_transport.dart';

/// Hell-/Dunkelmodus. Standard: hell.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Aktiver 6-stelliger Raumcode. Im Dev-Harness fix "DEV".
class RoomCodeNotifier extends Notifier<String> {
  @override
  String build() => 'DEV';

  void set(String code) => state = code;
}

final roomCodeProvider = NotifierProvider<RoomCodeNotifier, String>(
  RoomCodeNotifier.new,
);

/// **Transport-Injection.** In Dev/Test hängt hier [FakeTransport].
/// Später wird an dieser einen Stelle `HybridTransport` (BLE→Cloud) eingehängt –
/// die gesamte UI bleibt unverändert.
final transportProvider = Provider<SignalTransport>((ref) {
  final room = ref.watch(roomCodeProvider);
  final t = FakeTransport(room);
  ref.onDispose(t.dispose);
  return t;
});

/// Strom eingehender Kommandos (Empfängerseite).
final commandStreamProvider = StreamProvider<DriveCommand>((ref) {
  return ref.watch(transportProvider).commands;
});

/// Verbindungszustand für Watchdog/Statusanzeige.
final connectionStreamProvider = StreamProvider<TransportState>((ref) {
  return ref.watch(transportProvider).connection;
});

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/drive_command.dart';
import 'signal_transport.dart';

/// Transport über **Supabase Realtime (Broadcast)** – der Cloud-/Fern-Weg.
///
/// Jeder Raumcode ist ein eigener Broadcast-Channel; Kommandos werden als
/// Event `cmd` gesendet und empfangen. Gleiche [SignalTransport]-Schnittstelle
/// wie [FakeTransport]/[WsTransport], daher UI-seitig austauschbar.
///
/// Voraussetzung: `Supabase.initialize(...)` wurde in `main()` aufgerufen
/// (URL + anon-Key kommen per `--dart-define`, nie ins Repo).
class SupabaseTransport implements SignalTransport {
  final String room;

  final _commands = StreamController<DriveCommand>.broadcast();
  final _connection = StreamController<TransportState>.broadcast();
  late final RealtimeChannel _channel;

  static const String _event = 'cmd';

  SupabaseTransport(this.room) {
    _connection.add(TransportState.connecting);

    final client = Supabase.instance.client;
    // Channel-Name eindeutig je Raum. Prefix beugt Kollisionen vor.
    _channel = client.channel('fahrsignal-$room')
      ..onBroadcast(event: _event, callback: _onBroadcast);

    _channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          _connection.add(TransportState.connected);
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          _connection.add(TransportState.disconnected);
      }
    });
  }

  void _onBroadcast(Map<String, dynamic> payload) {
    // Supabase liefert je nach Version entweder direkt die Nutzlast oder ein
    // Objekt { event, payload, type }. Beide Formen robust abfangen.
    final raw = payload['payload'];
    final data = raw is Map ? raw.cast<String, dynamic>() : payload;
    try {
      _commands.add(DriveCommand.fromJson(data));
    } catch (_) {
      // ungültige Nachricht ignorieren
    }
  }

  @override
  Stream<DriveCommand> get commands => _commands.stream;

  @override
  Stream<TransportState> get connection => _connection.stream;

  @override
  Future<void> sendCommand(DriveCommand cmd) async {
    await _channel.sendBroadcastMessage(event: _event, payload: cmd.toJson());
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_channel);
    _commands.close();
    _connection.close();
  }
}

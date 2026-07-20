import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/drive_command.dart';
import 'signal_transport.dart';

/// Transport über einen WebSocket-Relay (siehe `relay_server.dart`).
/// Koppelt zwei getrennte Geräte/Browser-Fenster im selben WLAN über den
/// Raumcode – Zwischenlösung, bis BLE steht. Gleiche Schnittstelle wie
/// [FakeTransport], daher UI-seitig austauschbar.
class WsTransport implements SignalTransport {
  final String room;
  late final WebSocketChannel _ch;
  final _commands = StreamController<DriveCommand>.broadcast();
  final _connection = StreamController<TransportState>.broadcast();

  WsTransport(this.room, {required String relayUrl}) {
    _connection.add(TransportState.connecting);
    _ch = WebSocketChannel.connect(Uri.parse(relayUrl));

    _ch.ready
        .then((_) {
          _connection.add(TransportState.connected);
          _ch.sink.add(jsonEncode({'type': 'join', 'room': room}));
        })
        .catchError((Object _) {
          _connection.add(TransportState.disconnected);
        });

    _ch.stream.listen(
      (dynamic data) {
        try {
          final j = jsonDecode(data as String) as Map<String, dynamic>;
          if (j['type'] == 'cmd') {
            _commands.add(
              DriveCommand.fromJson((j['cmd'] as Map).cast<String, dynamic>()),
            );
          }
        } catch (_) {
          // ungültige Nachricht ignorieren
        }
      },
      onDone: () => _connection.add(TransportState.disconnected),
      onError: (_) => _connection.add(TransportState.disconnected),
    );
  }

  @override
  Stream<DriveCommand> get commands => _commands.stream;

  @override
  Stream<TransportState> get connection => _connection.stream;

  @override
  Future<void> sendCommand(DriveCommand cmd) async {
    _ch.sink.add(
      jsonEncode({'type': 'cmd', 'room': room, 'cmd': cmd.toJson()}),
    );
  }

  @override
  void dispose() {
    _ch.sink.close();
    _commands.close();
    _connection.close();
  }
}

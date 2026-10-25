import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../domain/drive_command.dart';
import 'signal_transport.dart';

/// Transport über den WebSocket-Relay (siehe `relay_server.dart`) – live der
/// Weg zwischen den beiden Geräten im Auto, lokal zwei Fenster im WLAN.
/// Gleiche Schnittstelle wie [FakeTransport], daher UI-seitig austauschbar.
///
/// Im Auto reißt die Mobilfunkverbindung ab, ohne dass der Socket es merkt –
/// ein WebSocket im Browser meldet ein totes Netz oft erst nach Minuten.
/// Deshalb:
/// - **Heartbeat:** alle [heartbeat] ein `ping`; bleibt [deadAfter] lang jede
///   Antwort aus, gilt die Verbindung als tot → `disconnected`, neu verbinden.
/// - **Neu verbinden** mit kurzem, wachsendem Abstand (bis 5 s), dabei den
///   Raum erneut betreten.
/// - **Verbunden** heißt erst, wenn der Relay den Beitritt bestätigt hat.
/// - Was ohne Verbindung gesendet wird, **verfällt**: eine Anweisung, die
///   Sekunden später ankommt, ist im Straßenverkehr falsch. Die Warnung auf
///   beiden Geräten sagt, dass gerade nichts durchgeht.
class WsTransport implements SignalTransport {
  final String room;
  final String relayUrl;
  final Duration heartbeat;
  final Duration deadAfter;

  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  Timer? _beat;
  Timer? _retry;
  DateTime _lastHeard = DateTime.now();
  int _attempt = 0;
  bool _joined = false;
  bool _disposed = false;

  TransportState _state = TransportState.connecting;
  final _commands = StreamController<DriveCommand>.broadcast();
  final _connection = StreamController<TransportState>.broadcast();

  WsTransport(
    this.room, {
    required this.relayUrl,
    this.heartbeat = const Duration(seconds: 4),
    this.deadAfter = const Duration(seconds: 10),
  }) {
    _connect();
  }

  void _setState(TransportState s) {
    if (s == _state || _disposed) return;
    _state = s;
    _connection.add(s);
  }

  void _connect() {
    if (_disposed) return;
    _joined = false;
    final WebSocketChannel ch;
    try {
      ch = WebSocketChannel.connect(Uri.parse(relayUrl));
    } catch (_) {
      _lost();
      return;
    }
    _ch = ch;
    _lastHeard = DateTime.now();

    ch.ready.then(
      (_) {
        if (!identical(_ch, ch)) return;
        ch.sink.add(jsonEncode({'type': 'join', 'room': room}));
        _beat?.cancel();
        _beat = Timer.periodic(heartbeat, (_) => _tick(ch));
      },
      onError: (Object _) {
        if (identical(_ch, ch)) _lost();
      },
    );

    _sub = ch.stream.listen(
      (dynamic data) {
        if (!identical(_ch, ch)) return;
        _lastHeard = DateTime.now();
        final Map<String, dynamic> j;
        try {
          j = jsonDecode(data as String) as Map<String, dynamic>;
        } catch (_) {
          return; // ungültige Nachricht ignorieren
        }
        switch (j['type']) {
          case 'joined':
            _joined = true;
            _attempt = 0;
            _setState(TransportState.connected);
          case 'cmd':
            try {
              _commands.add(
                DriveCommand.fromJson(
                  (j['cmd'] as Map).cast<String, dynamic>(),
                ),
              );
            } catch (_) {
              // ungültiges Kommando ignorieren
            }
        }
      },
      onDone: () {
        if (identical(_ch, ch)) _lost();
      },
      onError: (_) {
        if (identical(_ch, ch)) _lost();
      },
    );
  }

  void _tick(WebSocketChannel ch) {
    if (DateTime.now().difference(_lastHeard) > deadAfter) {
      _lost();
      return;
    }
    ch.sink.add('{"type":"ping"}');
  }

  /// Verbindung aufgeben und nach kurzer Pause neu aufbauen.
  void _lost() {
    _beat?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    _joined = false;
    if (_disposed) return;
    _setState(TransportState.disconnected);
    _retry?.cancel();
    // 0,5 – 1 – 2 – 4 – 5 – 5 … Sekunden: nach einem Funkloch soll es sofort
    // weitergehen, ein dauerhaft fehlender Server wird nicht bestürmt.
    final ms = (500 * (1 << _attempt.clamp(0, 4))).clamp(500, 5000);
    _attempt++;
    _retry = Timer(Duration(milliseconds: ms), _connect);
  }

  @override
  Stream<DriveCommand> get commands => _commands.stream;

  /// Liefert jedem neuen Zuhörer zuerst den aktuellen Zustand – sonst sähe
  /// eine Ansicht, die nach dem Verbinden aufgeht, nie ein "verbunden".
  @override
  Stream<TransportState> get connection => Stream.multi((c) {
    c.add(_state);
    final sub = _connection.stream.listen(c.add, onDone: c.close);
    c.onCancel = sub.cancel;
  });

  @override
  Future<void> sendCommand(DriveCommand cmd) async {
    final ch = _ch;
    if (ch == null || !_joined) return;
    ch.sink.add(jsonEncode({'type': 'cmd', 'room': room, 'cmd': cmd.toJson()}));
  }

  @override
  void dispose() {
    _disposed = true;
    _beat?.cancel();
    _retry?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    _ch = null;
    _commands.close();
    _connection.close();
  }
}

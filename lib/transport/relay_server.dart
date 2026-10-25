import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// WebSocket-Relay: reicht Nachrichten je **Raumcode** an die anderen
/// Teilnehmer desselben Raums weiter. Läuft lokal (`dart run
/// bin/relay_server.dart`) und live als Container auf dem VPS
/// (`deploy/relay/`), dort hinter Traefik unter `wss://…/ws`.
///
/// Protokoll (JSON pro Nachricht):
///   {"type":"join","room":"ABC123"}          → Antwort {"type":"joined"}
///   {"type":"ping"}                          → Antwort {"type":"pong"}
///   {"type":"cmd","room":"ABC123","cmd":{…}} – DriveCommand.toJson(),
///                                              geht an alle anderen im Raum
///
/// Der Relay liest keine Kommandos, er spiegelt sie nur. Gespeichert wird
/// nichts, geloggt nur Zahlen – kein Raumcode, kein Inhalt.
///
/// Nur für Server/Desktop (dart:io) – wird von der Web-App nie importiert.
/// Bewusst ohne Paket-Importe: der Container übersetzt genau diese Datei.
Future<RelayServer> startRelay({
  int port = 8080,
  Set<String> allowedOrigins = const {},
  bool log = false,
}) async {
  final rooms = <String, Set<WebSocket>>{};
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  Timer? stats;

  void protokoll(String text) {
    if (log) stdout.writeln('${DateTime.now().toIso8601String()}  $text');
  }

  void leave(WebSocket ws, String? room) {
    if (room == null) return;
    final set = rooms[room];
    set?.remove(ws);
    if (set != null && set.isEmpty) rooms.remove(room);
  }

  server.listen((HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('FahrSignal WebSocket-Relay');
      await req.response.close();
      return;
    }

    // Fremde Webseiten sollen den Relay nicht mitbenutzen. Eine App ohne
    // Browser schickt keinen Origin – die darf.
    final origin = req.headers.value('origin');
    if (allowedOrigins.isNotEmpty &&
        origin != null &&
        !allowedOrigins.contains(origin)) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      protokoll('abgewiesen: fremder Origin');
      return;
    }

    if (rooms.values.fold<int>(0, (n, s) => n + s.length) >= _kMaxClients) {
      req.response.statusCode = HttpStatus.serviceUnavailable;
      await req.response.close();
      protokoll('abgewiesen: voll');
      return;
    }

    final WebSocket ws;
    try {
      ws = await WebSocketTransformer.upgrade(req);
    } catch (_) {
      return;
    }
    // Räumt Verbindungen ab, deren Gegenstelle still verschwunden ist
    // (Funkloch, Handy aus) – sonst stünden sie ewig im Raum.
    ws.pingInterval = const Duration(seconds: 30);
    String? room;

    ws.listen(
      (dynamic data) {
        if (data is! String || data.length > _kMaxMessage) return;
        final Map<String, dynamic> msg;
        try {
          msg = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          return; // ungültige Nachricht ignorieren
        }
        switch (msg['type']) {
          case 'ping':
            ws.add('{"type":"pong"}');
          case 'join':
            final r = msg['room'];
            if (r is! String || !_kRoom.hasMatch(r)) return;
            if ((rooms[r]?.length ?? 0) >= _kMaxPerRoom) return;
            leave(ws, room);
            room = r;
            rooms.putIfAbsent(r, () => <WebSocket>{}).add(ws);
            ws.add('{"type":"joined"}');
          case 'cmd':
            // Nur in den Raum, dem diese Verbindung beigetreten ist – ein
            // "room" in der Nachricht selbst zählt nicht.
            final r = room;
            if (r == null) return;
            for (final peer in rooms[r] ?? const <WebSocket>{}) {
              if (!identical(peer, ws) && peer.readyState == WebSocket.open) {
                peer.add(data);
              }
            }
        }
      },
      onDone: () => leave(ws, room),
      onError: (_) => leave(ws, room),
      cancelOnError: true,
    );
  });

  if (log) {
    stats = Timer.periodic(const Duration(hours: 1), (_) {
      final n = rooms.values.fold<int>(0, (n, s) => n + s.length);
      protokoll('${rooms.length} Räume, $n Verbindungen');
    });
  }

  return RelayServer._(server, rooms, () => stats?.cancel());
}

/// Der laufende Relay. [close] beendet auch die offenen WebSockets – die
/// hängen nach dem Upgrade nicht mehr am [HttpServer] und blieben sonst
/// stehen, die Geräte merkten den Neustart erst über den Heartbeat.
class RelayServer {
  final HttpServer _server;
  final Map<String, Set<WebSocket>> _rooms;
  final void Function() _stop;
  RelayServer._(this._server, this._rooms, this._stop);

  int get port => _server.port;

  Future<void> close() async {
    _stop();
    await _server.close(force: true);
    final alle = [for (final s in _rooms.values) ...s];
    _rooms.clear();
    // 1001 "going away": die Geräte verbinden sofort neu.
    await Future.wait(alle.map((ws) => ws.close(WebSocketStatus.goingAway)));
  }
}

/// Raumcodes wie im Startbildschirm (Großbuchstaben, Ziffern) – großzügig
/// genug für Tests und den Dev-Raum, eng genug gegen Unsinn.
final _kRoom = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

/// Ein DriveCommand ist ein paar hundert Byte; 8 kB tragen auch einen
/// langen Freitext.
const _kMaxMessage = 8 * 1024;

/// In einem Auto sitzen zwei Geräte. Etwas Luft für ein neu geladenes
/// Fenster, dessen alte Verbindung noch nicht abgeräumt ist.
const _kMaxPerRoom = 8;

const _kMaxClients = 500;

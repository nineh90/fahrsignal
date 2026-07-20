import 'dart:convert';
import 'dart:io';

/// Winziger WebSocket-Relay: reicht Nachrichten je **Raumcode** an die anderen
/// Teilnehmer desselben Raums weiter. Zwischenlösung, bis BLE steht.
///
/// Protokoll (JSON pro Nachricht):
///   {"type":"join","room":"ABC123"}         – einmalig nach dem Verbinden
///   {"type":"cmd","room":"ABC123","cmd":{…}} – DriveCommand.toJson()
///
/// Nur für Server/Desktop (dart:io) – wird von der Web-App nie importiert.
Future<HttpServer> startRelay({int port = 8080}) async {
  final rooms = <String, Set<WebSocket>>{};
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  server.listen((HttpRequest req) async {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('FahrSignal WebSocket-Relay');
      await req.response.close();
      return;
    }

    final ws = await WebSocketTransformer.upgrade(req);
    String? room;

    ws.listen(
      (dynamic data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          if (msg['type'] == 'join') {
            room = msg['room'] as String;
            rooms.putIfAbsent(room!, () => <WebSocket>{}).add(ws);
            return;
          }
        } catch (_) {
          return; // ungültige Nachricht ignorieren
        }
        // Alles außer join an die übrigen Teilnehmer desselben Raums spiegeln.
        final r = room;
        if (r == null) return;
        for (final peer in rooms[r] ?? const <WebSocket>{}) {
          if (!identical(peer, ws) && peer.readyState == WebSocket.open) {
            peer.add(data);
          }
        }
      },
      onDone: () {
        final r = room;
        if (r != null) {
          final set = rooms[r];
          set?.remove(ws);
          if (set != null && set.isEmpty) rooms.remove(r);
        }
      },
    );
  });

  return server;
}

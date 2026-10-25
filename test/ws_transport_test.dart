import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/relay_server.dart';
import 'package:fahrsignal/transport/signal_transport.dart';
import 'package:fahrsignal/transport/ws_transport.dart';

/// Wartet, bis [t] den Zustand [s] meldet.
Future<void> until(SignalTransport t, TransportState s) =>
    t.connection.firstWhere((x) => x == s).timeout(const Duration(seconds: 5));

void main() {
  test(
    'WsTransport koppelt zwei Clients über den Relay (per Raumcode)',
    () async {
      final server = await startRelay(port: 0); // 0 = freier Port
      final url = 'ws://localhost:${server.port}';

      final sender = WsTransport('ROOM1', relayUrl: url);
      final receiver = WsTransport('ROOM1', relayUrl: url);
      // Anderer Raum – darf nichts mitbekommen.
      final fremd = WsTransport('ROOM2', relayUrl: url);
      var fremdGotMessage = false;
      fremd.commands.listen((_) => fremdGotMessage = true);

      // "verbunden" kommt erst, wenn der Relay den Beitritt bestätigt hat.
      await Future.wait([
        until(sender, TransportState.connected),
        until(receiver, TransportState.connected),
        until(fremd, TransportState.connected),
      ]);

      final received = receiver.commands.first;
      await sender.sendCommand(DriveCommand.now('links', Urgency.info));
      final cmd = await received.timeout(const Duration(seconds: 3));

      expect(cmd.key, 'links');
      expect(cmd.urgency, Urgency.info);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(fremdGotMessage, isFalse);

      sender.dispose();
      receiver.dispose();
      fremd.dispose();
      await server.close();
    },
  );

  test('neuer Zuhörer bekommt sofort den aktuellen Zustand', () async {
    final server = await startRelay(port: 0);
    final t = WsTransport('ROOM1', relayUrl: 'ws://localhost:${server.port}');
    await until(t, TransportState.connected);

    // Die Ansicht geht erst nach dem Verbinden auf – sie muss trotzdem
    // "verbunden" sehen und nicht ewig auf ein Ereignis warten.
    expect(await t.connection.first, TransportState.connected);

    t.dispose();
    await server.close();
  });

  test(
    'Relay weg → disconnected, Relay wieder da → von selbst verbunden',
    () async {
      final first = await startRelay(port: 0);
      final port = first.port;
      final url = 'ws://localhost:$port';
      final a = WsTransport('ROOM1', relayUrl: url);
      final b = WsTransport('ROOM1', relayUrl: url);
      await Future.wait([
        until(a, TransportState.connected),
        until(b, TransportState.connected),
      ]);

      final lost = Future.wait([
        until(a, TransportState.disconnected),
        until(b, TransportState.disconnected),
      ]);
      await first.close();
      await lost;

      // Während der Pause gesendet: verfällt, statt später anzukommen.
      await a.sendCommand(DriveCommand.now('rechts', Urgency.info));

      final second = await startRelay(port: port);
      await Future.wait([
        until(a, TransportState.connected),
        until(b, TransportState.connected),
      ]);

      final received = b.commands.first;
      await a.sendCommand(DriveCommand.now('links', Urgency.info));
      expect((await received.timeout(const Duration(seconds: 3))).key, 'links');

      a.dispose();
      b.dispose();
      await second.close();
    },
  );

  test('stiller Abriss wird über den Heartbeat erkannt', () async {
    // Ein Server, der die Verbindung annimmt, aber nie antwortet – wie ein
    // Mobilfunknetz, das Pakete still verschluckt.
    final stumm = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final offen = <WebSocket>[];
    stumm.listen((req) async {
      offen.add(await WebSocketTransformer.upgrade(req));
    });

    final t = WsTransport(
      'ROOM1',
      relayUrl: 'ws://localhost:${stumm.port}',
      heartbeat: const Duration(milliseconds: 100),
      deadAfter: const Duration(milliseconds: 300),
    );
    final states = <TransportState>[];
    final sub = t.connection.listen(states.add);

    await until(t, TransportState.disconnected);
    expect(states, isNot(contains(TransportState.connected)));

    await sub.cancel();
    t.dispose();
    for (final ws in offen) {
      await ws.close();
    }
    await stumm.close(force: true);
  });

  test('Relay weist fremde Webseiten und ungültige Raumcodes ab', () async {
    final server = await startRelay(
      port: 0,
      allowedOrigins: {'https://fahrsignal.fahrlehrerinsarah.de'},
    );
    final url = 'ws://localhost:${server.port}';

    await expectLater(
      WebSocket.connect(url, headers: {'origin': 'https://example.com'}),
      throwsA(isA<WebSocketException>()),
    );

    final ok = await WebSocket.connect(
      url,
      headers: {'origin': 'https://fahrsignal.fahrlehrerinsarah.de'},
    );
    final antworten = <dynamic>[];
    ok.listen(antworten.add);
    ok.add('{"type":"join","room":"../../etc"}');
    ok.add('{"type":"ping"}');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(antworten, ['{"type":"pong"}']); // kein "joined"

    await ok.close();
    await server.close();
  });
}

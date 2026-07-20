import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/relay_server.dart';
import 'package:fahrsignal/transport/ws_transport.dart';

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

      final received = receiver.commands.first;
      // warten, bis beide „join" beim Relay angekommen sind
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await sender.sendCommand(DriveCommand.now('links', Urgency.info));
      final cmd = await received.timeout(const Duration(seconds: 3));

      expect(cmd.key, 'links');
      expect(cmd.urgency, Urgency.info);
      expect(fremdGotMessage, isFalse);

      sender.dispose();
      receiver.dispose();
      fremd.dispose();
      await server.close(force: true);
    },
  );
}

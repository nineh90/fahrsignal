// ignore_for_file: avoid_print
import 'package:fahrsignal/transport/relay_server.dart';

/// Startet den WebSocket-Relay für die lokale Zwei-Geräte-Zwischenlösung.
/// Start: `dart run bin/relay_server.dart`
Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 8080 : 8080;
  final server = await startRelay(port: port);
  print('FahrSignal WebSocket-Relay läuft auf ws://<host>:${server.port}');
  print('(Strg+C zum Beenden)');
}

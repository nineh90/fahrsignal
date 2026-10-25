// ignore_for_file: avoid_print
import 'dart:io';

import 'package:fahrsignal/transport/relay_server.dart';

/// Startet den WebSocket-Relay.
/// Lokal: `dart run bin/relay_server.dart [port]` (Standard 8080).
/// Live läuft dieselbe `relay_server.dart` im Container (`deploy/relay/`).
Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 8080 : 8080;
  final server = await startRelay(port: port);
  print('FahrSignal WebSocket-Relay läuft auf ws://<host>:${server.port}');
  print('(Strg+C zum Beenden)');
  ProcessSignal.sigint.watch().first.then((_) async {
    await server.close();
    exit(0);
  });
}

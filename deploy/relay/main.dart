import 'dart:io';

import 'relay_server.dart';

/// Einstieg im Container. Erlaubte Seiten kommen aus FS_ORIGINS
/// (kommagetrennt, siehe deploy/docker-compose.yml).
Future<void> main() async {
  final origins = (Platform.environment['FS_ORIGINS'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final server = await startRelay(
    port: 8080,
    allowedOrigins: origins,
    log: true,
  );
  stdout.writeln('FahrSignal-Relay läuft auf :${server.port}');

  // Als PID 1 im Container gibt es keine Standardreaktion auf SIGTERM –
  // ohne diesen Handler wartete "docker stop" zehn Sekunden und schlüge
  // dann hart zu. So bekommen die Geräte ein sauberes "going away" und
  // verbinden sich nach dem Neustart sofort wieder.
  for (final signal in [ProcessSignal.sigterm, ProcessSignal.sigint]) {
    signal.watch().listen((_) async {
      await server.close();
      exit(0);
    });
  }
}

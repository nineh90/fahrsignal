import 'dart:async';
import '../domain/drive_command.dart';
import 'signal_transport.dart';

/// Ein Broadcast-Bus pro Raumcode: koppelt alle Instanzen desselben Raums
/// im selben Prozess (Loopback für Entwicklung & Tests).
class _Hub {
  static final _rooms = <String, StreamController<DriveCommand>>{};
  static StreamController<DriveCommand> of(String room) => _rooms.putIfAbsent(
    room,
    () => StreamController<DriveCommand>.broadcast(),
  );
}

/// In-Process-Loopback-Transport. Keine Hardware, kein Netz.
/// Sender und Empfänger im selben Raum teilen sich denselben Bus.
class FakeTransport implements SignalTransport {
  final String room;
  FakeTransport(this.room);

  @override
  Stream<DriveCommand> get commands => _Hub.of(room).stream;

  // Fake ist konzeptionell sofort und dauerhaft "verbunden".
  @override
  Stream<TransportState> get connection async* {
    yield TransportState.connected;
  }

  @override
  Future<void> sendCommand(DriveCommand cmd) async => _Hub.of(room).add(cmd);

  @override
  void dispose() {
    // Der Hub bleibt bestehen, damit weitere Instanzen desselben Raums
    // (z. B. im Split-Screen) weiter gekoppelt sind.
  }
}

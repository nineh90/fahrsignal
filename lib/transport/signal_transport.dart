import 'dart:async';
import '../domain/drive_command.dart';

/// Verbindungszustand, den die UI anzeigt (Watchdog/Heartbeat).
enum TransportState { connecting, connected, disconnected }

/// Die einzige Schnittstelle, die die UI kennt. Dahinter steckt Fake, BLE
/// oder Cloud – die UI weiß nie, welcher Transport aktiv ist.
///
/// **Regel:** Neue synchronisierte Daten immer über diese Schnittstelle
/// führen, nie direkt gegen BLE/Cloud in der UI.
abstract class SignalTransport {
  /// Eingehende Kommandos (Empfängerseite).
  Stream<DriveCommand> get commands;

  /// Verbindungszustand für Watchdog/Statusanzeige.
  Stream<TransportState> get connection;

  /// Kommando senden (Senderseite).
  Future<void> sendCommand(DriveCommand cmd);

  void dispose();
}

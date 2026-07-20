import 'package:wakelock_plus/wakelock_plus.dart';

/// Hält das Empfängergerät wach (Display bleibt an). "Best effort":
/// auf nicht unterstützten Plattformen werden Fehler bewusst geschluckt.
Future<void> enableKeepAwake() async {
  try {
    await WakelockPlus.enable();
  } catch (_) {
    // z. B. Linux-Desktop ohne Support – unkritisch.
  }
}

Future<void> disableKeepAwake() async {
  try {
    await WakelockPlus.disable();
  } catch (_) {}
}

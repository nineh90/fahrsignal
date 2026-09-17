import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/drive_command.dart';
import 'domain/voice_phrases.dart';
import 'platform/speech/fake_speech_recognizer.dart';
import 'platform/speech/speech_output.dart';
import 'platform/speech/speech_recognizer.dart';
import 'transport/signal_transport.dart';
import 'transport/fake_transport.dart';

/// Hell-/Dunkelmodus. Standard: hell.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Prüfungsmodus: blendet im Sender jede Hilfestellung aus, es bleiben nur
/// Anweisungen. Reiner Senderzustand – der Empfänger zeigt ohnehin nur, was
/// ankommt. Standard: aus.
class ExamModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final examModeProvider = NotifierProvider<ExamModeNotifier, bool>(
  ExamModeNotifier.new,
);

/// Aktiver 6-stelliger Raumcode. Im Dev-Harness fix "DEV".
class RoomCodeNotifier extends Notifier<String> {
  @override
  String build() => 'DEV';

  void set(String code) => state = code;
}

final roomCodeProvider = NotifierProvider<RoomCodeNotifier, String>(
  RoomCodeNotifier.new,
);

/// **Transport-Injection.** In Dev/Test hängt hier [FakeTransport].
/// Später wird an dieser einen Stelle `HybridTransport` (BLE→Cloud) eingehängt –
/// die gesamte UI bleibt unverändert.
final transportProvider = Provider<SignalTransport>((ref) {
  final room = ref.watch(roomCodeProvider);
  final t = FakeTransport(room);
  ref.onDispose(t.dispose);
  return t;
});

/// Mikrofonfreigabe: `null` = noch nicht gefragt, `true` = erteilt,
/// `false` = abgelehnt. Wird geteilt, damit der Umschalter danach fragen kann
/// und das Bedienteil weiß, ob es einen Hinweis zeigen muss.
class MicPermissionNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool? granted) => state = granted;
}

final micPermissionProvider = NotifierProvider<MicPermissionNotifier, bool?>(
  MicPermissionNotifier.new,
);

/// Skript für den Fake-Erkenner: erlaubt die Vorführung ohne Mikrofon und
/// ist zugleich der Dev-Loop am Linux-Desktop.
const _fakeSpeech = bool.fromEnvironment('FAKE_SPEECH');
const _kFakeScript = [
  'rechts abbiegen',
  'zweite Straße links',
  'sofort bremsen',
  'Achtung Fußgänger',
  'Spiegel und Schulterblick',
];

/// Spracherkennung. Auf Web die echte Web Speech API, sonst ein Stub, der
/// `isSupported == false` meldet. In Tests per `overrideWithValue` ersetzbar.
final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final r = _fakeSpeech
      ? FakeSpeechRecognizer(_kFakeScript)
      : createSpeechRecognizer();
  ref.onDispose(r.dispose);
  return r;
});

/// Sprachausgabe beim Fahrschüler (SAR-121): gewählte Sprache oder `null`
/// für stumm. **Stellt der Fahrlehrer ein** – jede Anweisung trägt die Wahl
/// mit (`DriveCommand.voice`), das Schülergerät hat keinen eigenen Schalter.
/// Standard: stumm. FahrSignal ist für gehörlose Fahrschüler gebaut; dort
/// hörte nur die Fahrlehrperson ihr eigenes Kommando ein zweites Mal.
class VoiceLanguageNotifier extends Notifier<VoiceLanguage?> {
  @override
  VoiceLanguage? build() => null;

  void set(VoiceLanguage? lang) => state = lang;
}

final voiceLanguageProvider =
    NotifierProvider<VoiceLanguageNotifier, VoiceLanguage?>(
      VoiceLanguageNotifier.new,
    );

/// Die Stimme auf dem Schülergerät. In Tests per `overrideWithValue` ersetzbar.
final speechOutputProvider = Provider<SpeechOutput>((ref) {
  final s = createSpeechOutput();
  ref.onDispose(s.dispose);
  return s;
});

/// Senden vom Fahrlehrergerät: **der eine Weg**, auf dem eine Anweisung
/// hinausgeht – er hängt die gewählte Sprachausgabe an. Kacheln, Freitext
/// und Sprachleiste gehen alle hier durch.
extension SendCommand on WidgetRef {
  Future<void> sendCommand(DriveCommand cmd) => read(
    transportProvider,
  ).sendCommand(cmd.withVoice(read(voiceLanguageProvider)?.code ?? ''));
}

/// Strom eingehender Kommandos (Empfängerseite).
final commandStreamProvider = StreamProvider<DriveCommand>((ref) {
  return ref.watch(transportProvider).commands;
});

/// Verbindungszustand für Watchdog/Statusanzeige.
final connectionStreamProvider = StreamProvider<TransportState>((ref) {
  return ref.watch(transportProvider).connection;
});

/// Sprachausgabe der App (iOS/Android) über `flutter_tts`.
///
/// „Best effort" wie `keep_awake.dart`: Linux-Desktop und Tests haben kein
/// Plugin, und eine fehlende Stimme darf die Anzeige nie stören – Fehler
/// werden geschluckt.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../domain/drive_command.dart';
import '../../domain/spoken_text.dart';
import 'speech_output.dart';

SpeechOutput createSpeechOutput() => DeviceSpeechOutput();

class DeviceSpeechOutput implements SpeechOutput {
  final _tts = FlutterTts();
  Future<void>? _ready;
  final _available = <String, bool>{};

  Future<void> _setup() async {
    try {
      await _tts.setVolume(1);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Wie eine Navigationsansage: läuft auch bei Stummschalter,
        // senkt Musik kurz ab und geht über Bluetooth/CarPlay ins Auto.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.allowAirPlay,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android Auto / Autoradio behandeln das als Navigationsansage.
        await _tts.setAudioAttributesForNavigation();
      }
    } catch (_) {
      // Plattform ohne Sprachausgabe – unkritisch.
    }
  }

  Future<bool> _supports(String locale) async {
    final known = _available[locale];
    if (known != null) return known;
    var ok = true; // im Zweifel versuchen
    try {
      final r = await _tts.isLanguageAvailable(locale);
      if (r is bool) ok = r;
    } catch (_) {}
    return _available[locale] = ok;
  }

  @override
  Future<void> speak(
    Utterance say, {
    Utterance? fallback,
    Urgency urgency = Urgency.info,
  }) async {
    await (_ready ??= _setup());
    try {
      final u = fallback != null && !await _supports(say.locale)
          ? fallback
          : say;
      await _tts.stop();
      await _tts.setLanguage(u.locale);
      // Auf den Geräten ist 0,5 die normale Geschwindigkeit. Dringendes
      // etwas zügiger – es soll vor dem Ereignis zu Ende gesprochen sein.
      await _tts.setSpeechRate(urgency == Urgency.dringend ? 0.58 : 0.5);
      await _tts.speak(u.text, focus: true);
    } catch (_) {}
  }

  /// Apps brauchen keine Freischaltung durch eine Geste.
  @override
  void prime() {}

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() => stop();
}

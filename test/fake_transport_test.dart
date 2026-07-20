import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/transport/fake_transport.dart';

void main() {
  test('FakeTransport-Loopback liefert das gesendete Kommando', () async {
    final t = FakeTransport('TESTROOM_A');
    final received = t.commands.first; // vor dem Senden abonnieren
    await t.sendCommand(DriveCommand.now('links', Urgency.info));
    final cmd = await received;
    expect(cmd.key, 'links');
    expect(cmd.urgency, Urgency.info);
  });

  test('gleicher Raum koppelt getrennte Instanzen', () async {
    final sender = FakeTransport('TESTROOM_B');
    final receiver = FakeTransport('TESTROOM_B');
    final received = receiver.commands.first;
    await sender.sendCommand(DriveCommand.now('stopp', Urgency.dringend));
    expect((await received).key, 'stopp');
  });

  test('Kombi-Kommando trägt alle Keys und höchste Urgency', () async {
    final sender = FakeTransport('TESTROOM_C');
    final receiver = FakeTransport('TESTROOM_C');
    final received = receiver.commands.first;
    await sender.sendCommand(
      DriveCommand.combo(['kreisverkehr', 'rechts'], Urgency.info),
    );
    final cmd = await received;
    expect(cmd.keys, ['kreisverkehr', 'rechts']);
    expect(cmd.isCombo, true);
    expect(cmd.key, 'kreisverkehr');
  });

  test('DriveCommand JSON-Roundtrip', () {
    final c = DriveCommand.now('stopp', Urgency.dringend);
    final r = DriveCommand.fromJson(c.toJson());
    expect(r.key, 'stopp');
    expect(r.urgency, Urgency.dringend);
    expect(r.v, kProtocolVersion);
  });

  test('Freitext-Anweisung überträgt den Text', () async {
    final sender = FakeTransport('TESTROOM_F');
    final receiver = FakeTransport('TESTROOM_F');
    final received = receiver.commands.first;
    await sender.sendCommand(
      DriveCommand.freitext('Zeige mir den Verbandskasten'),
    );
    final cmd = await received;
    expect(cmd.isFreitext, true);
    expect(cmd.text, 'Zeige mir den Verbandskasten');
    expect(DriveCommand.fromJson(cmd.toJson()).text, cmd.text);
  });

  test('Abfrage-Flag (ask) überträgt sich', () {
    final c = DriveCommand.now('reifendruck', Urgency.info, ask: true);
    expect(c.ask, true);
    expect(DriveCommand.fromJson(c.toJson()).ask, true);
  });

  test('off ist Sonderkommando', () {
    expect(DriveCommand.now(kOffKey, Urgency.info).isOff, true);
    expect(DriveCommand.now('links', Urgency.info).isOff, false);
  });
}

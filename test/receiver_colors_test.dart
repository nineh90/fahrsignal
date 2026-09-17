import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/drive_command.dart';

/// Kontrastverhältnis nach WCAG zwischen zwei Farben.
double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hell = la > lb ? la : lb;
  final dunkel = la > lb ? lb : la;
  return (hell + 0.05) / (dunkel + 0.05);
}

void main() {
  group('Empfängerfarben (SAR-86)', () {
    test('jedes Kommando kommt in der Farbe seiner Sender-Kachel an', () {
      // Der Kern des Tickets: Fahrlehrer und Fahrschüler sprechen dieselbe
      // Farbe. Vorher war die Kachel kategoriefarbig und der Schülerschirm
      // urgency-farbig – „Tempo 50" ging rot los und kam blau an.
      for (final def in kCommandCatalog) {
        final cmd = DriveCommand.now(def.key, def.urgency);
        expect(
          commandColor(cmd),
          tileColor(def),
          reason: '${def.key}: Schülerschirm weicht von der Kachel ab',
        );
      }
    });

    test('Notkommandos sind auf beiden Seiten rot', () {
      // „Stop" und „Anhalten" liegen in der grünen Kategorie „Hinweise".
      // Ohne diese Ausnahme leuchtete ein Not-Stop grün.
      for (final key in kExamSafetyKeys) {
        final def = commandByKey(key);
        expect(def, isNotNull, reason: '$key fehlt im Katalog');
        expect(
          tileColor(def!),
          urgencyColor(Urgency.dringend),
          reason: '$key ist ein Notkommando und muss rot sein',
        );
        expect(
          commandColor(DriveCommand.now(key, def.urgency)),
          urgencyColor(Urgency.dringend),
        );
      }
    });

    test('Notkommando in einer Kombination färbt trotzdem rot', () {
      // `key` ist das *erste* Kommando. Ohne den Sicherheitsboden bekäme
      // „links und bremsen" die blaue Richtungsfarbe.
      final kombi = DriveCommand.combo(const [
        'links',
        'bremsen',
      ], Urgency.dringend);
      expect(kombi.key, 'links');
      expect(commandColor(kombi), urgencyColor(Urgency.dringend));
    });

    test('Freitext ohne Katalog-Eintrag fällt auf die Urgency-Farbe', () {
      expect(commandByKey(kFreitextKey), isNull);
      expect(
        commandColor(DriveCommand.freitext('Rechts ranfahren')),
        urgencyColor(Urgency.info),
      );
      expect(
        commandColor(
          DriveCommand.freitext('Sofort halten', urgency: Urgency.dringend),
        ),
        urgencyColor(Urgency.dringend),
      );
    });

    test('Schrift steht auf jeder Fläche mit mindestens 3:1', () {
      // Die Fläche trägt jetzt Kategoriefarben, und die reichen von hellem
      // Gelb bis zu dunklem Violett – eine feste Textfarbe würde auf einem
      // der beiden Enden verschwinden. Hält die Schwelle in `foregroundOn`.
      for (final def in kCommandCatalog) {
        final bg = tileColor(def);
        expect(
          _kontrast(bg, foregroundOn(bg)),
          greaterThanOrEqualTo(3.0),
          reason: '${def.key}: Schrift auf der Fläche zu schwach',
        );
      }
    });
  });
}

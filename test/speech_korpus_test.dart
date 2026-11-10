import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrsignal/domain/command_catalog.dart';
import 'package:fahrsignal/domain/drive_command.dart';
import 'package:fahrsignal/domain/speech/command_parser.dart';
import 'package:fahrsignal/domain/spoken_text.dart';
import 'package:fahrsignal/providers.dart';
import 'package:fahrsignal/transport/signal_transport.dart';
import 'package:fahrsignal/ui/sender_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sätze, wie sie im Auto fallen – vom Prüfer gesagt und von der
/// Fahrlehrerin nachgesprochen. Angelegt am 10.11.2026, als von 92 Sätzen 41
/// danebenlagen („nächste Kreuzung links" verlor die Kreuzung, „rechts vor
/// links" wurde zu zwei Pfeilen, „Bitte wenden" kam gar nicht an).
///
/// Jede Zeile: Satz → gesendete Keys (Reihenfolge zählt) und Ordnungszahl.
/// Und jeder Satz muss **ohne Rückfrage** rausgehen. Ein neuer Satz, der im
/// Auto danebenging, gehört hier dazu.
const _korpus = <(String, String, int)>[
  (
    'Bitte an der nächsten Kreuzung links abbiegen',
    'abbiegen_links,kreuzung',
    0,
  ),
  ('An der nächsten Ampel rechts', 'rechts,ampel', 0),
  ('Nächste Straße links', 'links,strasse', 0),
  ('nächste Kreuzung links', 'links,kreuzung', 0),
  ('nächste Ampel rechts', 'rechts,ampel', 0),
  ('an der nächsten Einmündung rechts', 'rechts,strasse', 0),
  ('die nächste Möglichkeit links', 'links,strasse', 0),
  ('Die nächste rechts', 'abbiegen_rechts', 0),
  ('Zweite Straße rechts', 'rechts,strasse', 2),
  ('Die zweite links', 'abbiegen_links', 2),
  ('Dritte Kreuzung links', 'links,kreuzung', 3),
  ('an der zweiten Ampel links abbiegen', 'abbiegen_links,ampel', 2),
  ('An der Ampel geradeaus', 'geradeaus,ampel', 0),
  ('An der Kreuzung geradeaus weiter', 'geradeaus,kreuzung', 0),
  ('Kreuzung links', 'links,kreuzung', 0),
  ('Hier rechts rein', 'abbiegen_rechts', 0),
  ('Gleich links', 'links', 0),
  ('Jetzt links abbiegen', 'abbiegen_links', 0),
  ('Im Kreisverkehr die zweite Ausfahrt', 'ausfahrt2', 0),
  ('Im Kreisverkehr die erste Ausfahrt raus', 'ausfahrt1', 0),
  ('Am Kreisverkehr dritte Ausfahrt nehmen', 'ausfahrt3', 0),
  ('Kreisverkehr', 'kreisverkehr', 0),
  ('Der Straße folgen', 'folgen', 0),
  ('Weiter der Straße folgen', 'folgen', 0),
  ('Bitte überholen', 'ueberholen', 0),
  ('Links einordnen', 'einordnen_links', 0),
  ('Fahren Sie bitte rückwärts', 'rueckwaerts', 0),
  ('Bitte wenden', 'gfa_umkehren', 0),
  ('Etwas langsamer bitte', 'langsamer', 0),
  ('Fuß vom Gas', 'langsamer', 0),
  ('Du kannst ruhig schneller fahren', 'schneller', 0),
  ('Gib Gas', 'schneller', 0),
  ('Bremsen', 'bremsen', 0),
  ('Hier ist dreißig', 't_30', 0),
  ('Hier gilt Tempo fünfzig', 't_50', 0),
  ('Achtzig', 't_80', 0),
  ('Hier sind 70 erlaubt', 't_70', 0),
  ('Tempo vierzig', 't_40', 0),
  ('Dreißiger Zone', 't_zone30', 0),
  ('Schrittgeschwindigkeit', 't_schritt', 0),
  ('Spielstraße', 't_schritt', 0),
  ('Verkehrsberuhigter Bereich', 't_schritt', 0),
  ('Aufhebung', 't_frei', 0),
  ('Schau in den Rückspiegel', 'spiegel', 0),
  ('Blinker setzen', 'blinker', 0),
  ('Blinken nicht vergessen', 'blinker', 0),
  ('Schulterblick nicht vergessen', 'schulterblick', 0),
  ('Achtung Radfahrer', 'radfahrer', 0),
  ('Da vorne kommt ein Fahrradfahrer', 'radfahrer', 0),
  ('Pass auf den Radfahrer auf', 'radfahrer', 0),
  ('Vorsicht Bahnübergang', 'bahnuebergang', 0),
  ('Achtung da kommt ein Bahnübergang', 'bahnuebergang', 0),
  ('Vorfahrt beachten', 'vorfahrt_gewaehren', 0),
  ('Rechts vor links', 'rechts_vor_links', 0),
  ('Achtung Hindernis', 'hindernis', 0),
  ('Mehr Abstand', 'abstand', 0),
  ('Hochschalten', 'gang', 0),
  ('Runterschalten', 'gang', 0),
  ('In den dritten Gang', 'gang', 0),
  ('Anhalten', 'anhalten', 0),
  ('Sofort anhalten', 'stopp', 0),
  ('Halt', 'stopp', 0),
  ('Stopp', 'stopp', 0),
  ('Rechts ran', 'anhalten', 0),
  ('Halten Sie bitte am rechten Fahrbahnrand', 'parken', 0),
  ('Kreuzung', 'kreuzung', 0),
  ('Nächste Kreuzung', 'kreuzung', 0),
  ('Achtung Kreuzung', 'kreuzung', 0),
  ('Ampel', 'ampel', 0),
  ('Achtung Ampel', 'ampel', 0),
  ('Die Ampel ist rot', 'ampel', 0),
  ('Spiegel und Schulterblick', 'spiegel,schulterblick', 0),
  ('Blinker links', 'blinker,links', 0),
  ('Links blinken', 'links,blinker', 0),
  ('Du hast Vorfahrt', 'vorfahrt', 0),
  ('Abknickende Vorfahrt rechts', 'abknickend_rechts', 0),
  ('Parken', 'parken', 0),
  ('Einparken', 'gfa_laengs', 0),
  ('Gefahrenbremsung', 'gfa_bremsung', 0),
  ('Wir machen jetzt eine Gefahrenbremsung', 'gfa_bremsung', 0),
  ('Rechts um die Ecke rückwärts', 'gfa_ecke', 0),
  ('Geradeaus', 'geradeaus', 0),
  ('Weiter geradeaus', 'geradeaus', 0),
  ('Immer geradeaus', 'geradeaus', 0),
  ('Tanken', 'tanken', 0),
  ('Gut gemacht', 'lob', 0),
  ('Das war nicht gut', 'fehler', 0),
  ('Ganz ruhig', 'ruhig', 0),
  ('Halt halt', 'stopp', 0),
  ('Fahr halt etwas langsamer', 'langsamer', 0),
  ('Achtung Radfahrer von rechts', 'radfahrer', 0),
  ('An der Ampel rechts und dann Spiegel', 'rechts,ampel,spiegel', 0),
  ('Zweite Kreuzung', 'kreuzung', 2),
  ('Nächste Straße', 'strasse', 0),
  ('Bitte die nächste Straße rechts abbiegen', 'abbiegen_rechts,strasse', 0),
  ('Am Kreisverkehr rechts', 'rechts,kreisverkehr', 0),
  (
    'Fahren Sie bitte an der nächsten Kreuzung geradeaus',
    'geradeaus,kreuzung',
    0,
  ),
  ('Folgen Sie der Vorfahrtstraße', 'folgen,vorfahrtstrasse', 0),
  ('Vorsicht Radfahrer von links', 'radfahrer', 0),
  ('Rechts vor links beachten', 'rechts_vor_links', 0),
];

Urgency _urgency(String k) => commandByKey(k)?.urgency ?? Urgency.info;

void main() {
  group('Satzkatalog', () {
    for (final (satz, keys, ord) in _korpus) {
      test(satz, () {
        final p = parseUtterance(satz, urgencyOf: _urgency);
        expect(p.allKeys.join(','), keys);
        expect(p.ordinal, ord);
        expect(p.canAutoSend, isTrue, reason: 'landet in der Rückfrage');
      });
    }
  });

  group('Ort + Richtung (Sarah, 11/2026)', () {
    String sagt(String satz) {
      final c = parseUtterance(satz, urgencyOf: _urgency).toCommand();
      return spokenGerman(c)!.text;
    }

    test('angesagt wird der Satz, wie der Prüfer ihn sagt', () {
      expect(sagt('nächste Kreuzung links'), 'Nächste Kreuzung links');
      expect(sagt('an der Ampel rechts'), 'Nächste Ampel rechts');
      expect(sagt('zweite Straße rechts'), 'zweite Straße rechts');
      expect(sagt('am Kreisverkehr rechts'), 'Im Kreisverkehr rechts');
    });

    test('„Achtung" färbt gelb, nie rot – Rot bleibt Bremsen und Stopp', () {
      final r = parseUtterance('Achtung Radfahrer', urgencyOf: _urgency);
      expect(r.urgency, Urgency.achtung);
      final s = parseUtterance('Achtung Spiegel', urgencyOf: _urgency);
      expect(s.urgency, Urgency.achtung);
      final b = parseUtterance('sofort bremsen', urgencyOf: _urgency);
      expect(b.urgency, Urgency.dringend);
    });

    testWidgets('lang gedrückte Kreuzung → Richtung wählen → eine Kombi', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final sent = <DriveCommand>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [transportProvider.overrideWithValue(_Mitschnitt(sent))],
          child: const MaterialApp(home: SenderGrid()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Kreuzung'));
      await tester.pumpAndSettle();
      expect(find.text('Nächste Kreuzung …'), findsOneWidget);

      // Im Blatt steht „Links" ein zweites Mal – das untere ist die Wahl.
      await tester.tap(find.text('Links').last);
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.keys, ['links', 'kreuzung']);
    });
  });
}

class _Mitschnitt implements SignalTransport {
  final List<DriveCommand> sent;
  _Mitschnitt(this.sent);
  @override
  Stream<DriveCommand> get commands => const Stream.empty();
  @override
  Stream<TransportState> get connection =>
      Stream.value(TransportState.connected);
  @override
  Future<void> sendCommand(DriveCommand cmd) async => sent.add(cmd);
  @override
  void dispose() {}
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'ui/brand.dart';
import 'ui/receiver_view.dart';
import 'ui/sender_grid.dart';

/// Dev-Einstieg: Sender (iPad) **und** Empfänger (Smartphone) nebeneinander in
/// Geräte-Rahmen, gekoppelt über denselben FakeTransport (Raum "DEV").
///
/// Start: `flutter run -d chrome -t lib/dev_harness.dart`
void main() => runApp(const ProviderScope(child: _DevApp()));

class _DevApp extends ConsumerWidget {
  const _DevApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'FahrSignal Dev',
      debugShowCheckedModeBanner: false,
      theme: fahrSignalTheme(Brightness.light),
      darkTheme: fahrSignalTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      home: const DevHarness(),
    );
  }
}

class DevHarness extends StatelessWidget {
  const DevHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF26292E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(
                flex: 5,
                child: _DeviceFrame(
                  label: 'Fahrlehrer · iPad',
                  aspectRatio: 3 / 4,
                  bezel: 16,
                  radius: 34,
                  child: SenderGrid(),
                ),
              ),
              SizedBox(width: 28),
              Expanded(
                flex: 3,
                child: _DeviceFrame(
                  label: 'Fahrschüler · Smartphone',
                  aspectRatio: 0.462,
                  bezel: 12,
                  radius: 44,
                  child: ReceiverView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Zeichnet den Inhalt in einem gerätetypischen Rahmen (Bezel + Rundungen),
/// passend in den verfügbaren Platz skaliert.
class _DeviceFrame extends StatelessWidget {
  final String label;
  final double aspectRatio;
  final double bezel;
  final double radius;
  final Widget child;
  const _DeviceFrame({
    required this.label,
    required this.aspectRatio,
    required this.bezel,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              var w = c.maxWidth;
              var h = w / aspectRatio;
              if (h > c.maxHeight) {
                h = c.maxHeight;
                w = h * aspectRatio;
              }
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Container(
                    padding: EdgeInsets.all(bezel),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0B0C),
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius - bezel),
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

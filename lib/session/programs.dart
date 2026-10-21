import '../protocol/pulsetto_protocol.dart';

/// A program only picks a duration and a default LED level. The device gets
/// the same start sequence for every one of them.
enum Program {
  stress('Stress', 4),
  anxiety('Anxiety', 6),
  sleep('Sleep', 10, led: Led.low),
  burnout('Burnout', 6),
  pain('Pain', 20),
  headPain('Head Pain', 6),
  inflammation('Inflammation', 4),
  gutHealth('Gut Health', 5),
  personal('Personal', 8);

  const Program(this.label, this.minutes, {this.led = Led.medium});

  final String label;
  final int minutes;
  final Led led;

  static Program? byName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

const customLabel = 'Custom';

String programLabel(Program? p) => p?.label ?? customLabel;

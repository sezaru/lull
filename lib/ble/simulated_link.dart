import 'dart:async';

import '../protocol/pulsetto_protocol.dart';
import 'pulsetto_link.dart';

/// A pretend Pulsetto, for running the app without hardware
/// (`--dart-define=LULL_SIMULATE=true`). It answers queries the way the
/// real device does.
class SimulatedLink implements PulsettoLink {
  static const _device = FoundDevice(
    id: 'c4:7f:51:0e:3f:a1',
    name: 'Pulsetto',
    rssi: -52,
  );

  final _found = StreamController<FoundDevice>.broadcast();
  final _received = StreamController<String>.broadcast();
  final _lost = StreamController<void>.broadcast();
  Timer? _scanTimer;
  bool _connected = false;
  double _volts = 3.83;

  @override
  Stream<Availability> get availability => const Stream.empty();

  @override
  Future<Availability> currentAvailability() async => Availability.on;

  @override
  Future<void> enableBluetooth() async {}

  @override
  Stream<FoundDevice> get found => _found.stream;

  @override
  Future<void> startScan() async {
    _scanTimer = Timer(const Duration(milliseconds: 1500), () {
      _found.add(_device);
    });
  }

  @override
  Future<void> stopScan() async => _scanTimer?.cancel();

  @override
  Future<void> connect(
    String id, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _connected = true;
  }

  @override
  Future<void> disconnect() async => _connected = false;

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Stream<void> get lost => _lost.stream;

  @override
  Stream<String> get received => _received.stream;

  @override
  Future<void> send(Command command) async {
    if (!_connected) throw StateError('Not connected');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final reply = switch (command.code) {
      'Q' => 'Batt:${_volts.toStringAsFixed(2)}\n',
      'u' => 'u\x010\n',
      'v' => 'fw:1.1.22\n',
      'i' => 'Pulsetto_ST_02\nmode:0\nBR:100\n',
      _ => null,
    };
    if (command.code == 'Q') _volts = (_volts - 0.001).clamp(3.5, 4.2);
    if (reply != null) {
      Timer(const Duration(milliseconds: 60), () => _received.add(reply));
    }
  }
}

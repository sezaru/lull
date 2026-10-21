import 'dart:async';

import 'package:universal_ble/universal_ble.dart';

import '../protocol/pulsetto_protocol.dart';
import 'pulsetto_link.dart';

class UniversalBleLink implements PulsettoLink {
  String? _deviceId;
  bool _closing = false;
  Future<void> _tail = Future.value();
  final _lost = StreamController<void>.broadcast();
  final _received = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _deviceSubs = [];

  static Availability _map(AvailabilityState s) => switch (s) {
    AvailabilityState.poweredOn => Availability.on,
    AvailabilityState.poweredOff => Availability.off,
    AvailabilityState.unsupported => Availability.unsupported,
    _ => Availability.unknown,
  };

  @override
  Stream<Availability> get availability =>
      UniversalBle.availabilityStream.map(_map);

  @override
  Future<Availability> currentAvailability() async =>
      _map(await UniversalBle.getBluetoothAvailabilityState());

  @override
  Future<void> enableBluetooth() async {
    await UniversalBle.enableBluetooth();
  }

  @override
  Stream<FoundDevice> get found => UniversalBle.scanStream
      .where((d) => isConnectableName(d.name))
      .map((d) => FoundDevice(id: d.deviceId, name: d.name!, rssi: d.rssi));

  @override
  Future<void> startScan() => UniversalBle.startScan();

  @override
  Future<void> stopScan() => UniversalBle.stopScan();

  @override
  Future<void> connect(
    String id, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _dropSubs();
    _deviceId = id;
    _closing = false;
    try {
      await _seeAgain(id, timeout);
      await UniversalBle.connect(id, timeout: timeout);
      await UniversalBle.discoverServices(id);
    } catch (_) {
      // A timed-out connect stays pending in Android's stack; without this
      // each retry stacks another attempt on the same device.
      _closing = true;
      _deviceId = null;
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
      rethrow;
    }
    _deviceSubs
      ..add(
        UniversalBle.characteristicValueStream(
          id,
          txCharacteristic,
        ).listen((bytes) => _received.add(String.fromCharCodes(bytes))),
      )
      ..add(
        UniversalBle.connectionStream(id).listen((connected) {
          if (!connected && !_closing && _deviceId == id) _lost.add(null);
        }),
      );
    await UniversalBle.subscribeNotifications(
      id,
      serviceUuid,
      txCharacteristic,
    );
  }

  /// The Pulsetto's address is random static (`C0:…`). After Bluetooth
  /// restarts (GrapheneOS switches it off when idle) Android forgets that and
  /// a connect by address alone times out, until a scan has seen it again.
  Future<void> _seeAgain(String id, Duration timeout) async {
    final seen = UniversalBle.scanStream
        .firstWhere((d) => d.deviceId.toLowerCase() == id.toLowerCase())
        .timeout(timeout);
    await UniversalBle.startScan();
    try {
      await seen;
    } finally {
      await UniversalBle.stopScan();
    }
  }

  @override
  Future<bool> isConnected() async {
    final id = _deviceId;
    if (id == null) return false;
    try {
      return await UniversalBle.getConnectionState(id) ==
          BleConnectionState.connected;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final id = _deviceId;
    _closing = true;
    _deviceId = null;
    await _dropSubs();
    if (id != null) await UniversalBle.disconnect(id);
  }

  Future<void> _dropSubs() async {
    for (final s in _deviceSubs) {
      await s.cancel();
    }
    _deviceSubs.clear();
  }

  @override
  Stream<void> get lost => _lost.stream;

  @override
  Stream<String> get received => _received.stream;

  /// The Pulsetto drops a command that lands right behind another one (seen:
  /// `v i u Q` written together, only `v` and `Q` answered).
  static const writeGap = Duration(milliseconds: 150);

  /// A write to a dead GATT handle can hang forever and stall every write
  /// queued behind it.
  static const writeTimeout = Duration(seconds: 3);

  @override
  Future<void> send(Command command) {
    final next = _tail.then((_) => _write(command).timeout(writeTimeout));
    _tail = next.catchError((_) {}).then((_) => Future<void>.delayed(writeGap));
    return next;
  }

  Future<void> _write(Command command) {
    final id = _deviceId;
    if (id == null) throw StateError('Not connected');
    return UniversalBle.write(
      id,
      serviceUuid,
      rxCharacteristic,
      command.bytes,
      withoutResponse: command.mode == WriteMode.withoutResponse,
    );
  }
}

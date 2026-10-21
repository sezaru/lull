import '../protocol/pulsetto_protocol.dart';

enum Availability { on, off, unsupported, unknown }

class FoundDevice {
  const FoundDevice({required this.id, required this.name, this.rssi});

  final String id;
  final String name;
  final int? rssi;
}

/// The BLE transport to one Pulsetto. Writes are serialized by the
/// implementation, in call order.
abstract class PulsettoLink {
  Stream<Availability> get availability;
  Future<Availability> currentAvailability();
  Future<void> enableBluetooth();

  /// Devices that advertise as a Pulsetto (never one in DFU mode).
  Stream<FoundDevice> get found;
  Future<void> startScan();
  Future<void> stopScan();

  /// Connects, discovers the UART service and subscribes to notifications.
  Future<void> connect(String id, {Duration timeout});
  Future<void> disconnect();

  /// Asks the OS, not our own bookkeeping: a link can die unnoticed while
  /// Android has the app frozen or Bluetooth is switched off.
  Future<bool> isConnected();

  /// Fires when the connected device drops without [disconnect] being called.
  Stream<void> get lost;

  /// Raw notification payloads; one may hold several lines.
  Stream<String> get received;

  Future<void> send(Command command);
}

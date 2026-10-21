import 'dart:typed_data';

const serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const rxCharacteristic = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const txCharacteristic = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

const deviceNamePrefix = 'Pulsetto';

/// The name a Pulsetto advertises in DFU mode. Never connect to it.
const dfuNamePrefix = 'PulsUp';

bool isConnectableName(String? name) =>
    name != null &&
    name.startsWith(deviceNamePrefix) &&
    !name.startsWith(dfuNamePrefix);

enum WriteMode { withResponse, withoutResponse }

enum Side {
  both('D'),
  left('A'),
  right('C');

  const Side(this.code);
  final String code;
}

enum Led {
  low('E'),
  medium('F'),
  high('G');

  const Led(this.code);
  final String code;
}

/// The only commands the app can send. The constructor is private so there
/// is no way to put an arbitrary byte on the wire (`U` reboots to DFU, and
/// undocumented commands can disable the device's safety limits).
class Command {
  const Command._(this.code, this.mode);

  static const rampUp = Command._('+', WriteMode.withResponse);
  static const rampDown = Command._('-', WriteMode.withResponse);
  static const queryBattery = Command._('Q', WriteMode.withoutResponse);
  static const queryCharging = Command._('u', WriteMode.withoutResponse);
  static const queryFirmware = Command._('v', WriteMode.withoutResponse);
  static const queryIdentity = Command._('i', WriteMode.withoutResponse);

  factory Command.level(int level) =>
      Command._('${level.clamp(0, 9)}', WriteMode.withoutResponse);
  factory Command.side(Side side) =>
      Command._(side.code, WriteMode.withoutResponse);
  factory Command.led(Led led) =>
      Command._(led.code, WriteMode.withoutResponse);

  final String code;
  final WriteMode mode;

  Uint8List get bytes => Uint8List.fromList([code.codeUnitAt(0), 0x0A]);

  @override
  bool operator ==(Object other) =>
      other is Command && other.code == code && other.mode == mode;

  @override
  int get hashCode => Object.hash(code, mode);

  @override
  String toString() => 'Command($code)';
}

sealed class DeviceEvent {
  const DeviceEvent();
}

class BatteryEvent extends DeviceEvent {
  const BatteryEvent(this.volts);
  final double volts;
  int get percent => (((volts - 3.5) / 0.4) * 100).round().clamp(0, 100);
}

class ChargingEvent extends DeviceEvent {
  const ChargingEvent(this.charging);
  final bool charging;
}

class FirmwareEvent extends DeviceEvent {
  const FirmwareEvent(this.version);
  final String version;
}

class IdentityEvent extends DeviceEvent {
  const IdentityEvent(this.identity);
  final String identity;
}

class ModeEvent extends DeviceEvent {
  const ModeEvent(this.value);
  final String value;
}

class BrEvent extends DeviceEvent {
  const BrEvent(this.value);
  final String value;
}

/// The device repeats each level, side and LED command it accepts.
class EchoEvent extends DeviceEvent {
  const EchoEvent(this.code);
  final String code;
  int? get level => int.tryParse(code);
}

/// The reply to `+`: `+1` when stimulation is on, `+0` when off.
class RampEvent extends DeviceEvent {
  const RampEvent(this.running);
  final bool running;
}

class UnknownLine extends DeviceEvent {
  const UnknownLine(this.line);
  final String line;
}

/// Splits the device's reply stream into tokens like `Batt:3.80`.
///
/// Firmware 1.1.22 separates replies with spaces, not newlines
/// (`u\x010 mode:0 BR:100 Batt:3.80`), sends command echoes with no separator
/// at all (`9D`, `50`, `9u\x010`), and can cut a token across two
/// notifications (`BR:` + `100`), so a trailing fragment waits for the rest.
class ReplyAssembler {
  String _partial = '';

  bool get hasPartial => _partial.trim().isNotEmpty;

  /// Complete tokens in [payload].
  List<String> add(String payload) {
    final parts = (_partial + payload).split(RegExp(r'\s'));
    _partial = parts.removeLast();
    return _join(
      parts.where((t) => t.isNotEmpty).toList(),
    ).expand(splitGlued).toList();
  }

  /// Gives up waiting for a separator, for a reply that never sends one.
  List<String> flush() {
    final last = _partial.trim();
    _partial = '';
    return last.isEmpty ? [] : splitGlued(last);
  }

  void reset() => _partial = '';

  /// Some firmware answers `u` with the text `Not Charging`.
  static List<String> _join(List<String> tokens) {
    final out = <String>[];
    for (final t in tokens) {
      if (t == 'Charging' && out.isNotEmpty && out.last == 'Not') {
        out.last = 'Not Charging';
      } else {
        out.add(t);
      }
    }
    return out;
  }
}

// Longest shapes first. Battery always has two decimals, which keeps a
// level echo glued after it from being read as part of the voltage.
final _token = RegExp(
  r'Not Charging|Charging|Batt:\d\.\d\d|fw:[0-9.]+|mode:[0-9A-Z]|BR:\d+|'
  r'u\x01[01]|Pulsetto\w*|\+[01]|[0-9ACDEFG]',
);

/// Splits one space-free chunk into the reply tokens glued inside it.
/// Anything unrecognised is kept whole, so it still shows in the log.
List<String> splitGlued(String chunk) {
  final out = <String>[];
  var unknown = StringBuffer();
  var i = 0;
  while (i < chunk.length) {
    final m = _token.matchAsPrefix(chunk, i);
    if (m == null) {
      unknown.write(chunk[i]);
      i++;
      continue;
    }
    if (unknown.isNotEmpty) {
      out.add(unknown.toString());
      unknown = StringBuffer();
    }
    out.add(m[0]!);
    i = m.end;
  }
  if (unknown.isNotEmpty) out.add(unknown.toString());
  return out;
}

DeviceEvent parseLine(String line) {
  if (line.startsWith('Batt:')) {
    final volts = double.tryParse(line.substring(5));
    if (volts != null) return BatteryEvent(volts);
  }
  if (line == 'u\x011' || line == 'Charging') return const ChargingEvent(true);
  if (line == 'u\x010' || line == 'Not Charging') {
    return const ChargingEvent(false);
  }
  if (line.startsWith('fw:')) return FirmwareEvent(line.substring(3));
  if (line.startsWith('mode:')) return ModeEvent(line.substring(5));
  if (line.startsWith('BR:')) return BrEvent(line.substring(3));
  if (line.startsWith(deviceNamePrefix)) return IdentityEvent(line);
  if (line == '+1' || line == '+0') return RampEvent(line == '+1');
  if (RegExp(r'^[0-9ACDEFG]$').hasMatch(line)) return EchoEvent(line);
  return UnknownLine(line);
}

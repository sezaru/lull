import 'package:flutter_test/flutter_test.dart';
import 'package:lull/protocol/protocol_log.dart';
import 'package:lull/protocol/pulsetto_protocol.dart';

void main() {
  group('Command', () {
    test('bytes and write mode for every command', () {
      final cases = <Command, (List<int>, WriteMode)>{
        Command.rampUp: ([0x2B, 0x0A], WriteMode.withResponse),
        Command.rampDown: ([0x2D, 0x0A], WriteMode.withResponse),
        Command.queryBattery: ([0x51, 0x0A], WriteMode.withoutResponse),
        Command.queryCharging: ([0x75, 0x0A], WriteMode.withoutResponse),
        Command.queryFirmware: ([0x76, 0x0A], WriteMode.withoutResponse),
        Command.queryIdentity: ([0x69, 0x0A], WriteMode.withoutResponse),
        Command.side(Side.both): ([0x44, 0x0A], WriteMode.withoutResponse),
        Command.side(Side.left): ([0x41, 0x0A], WriteMode.withoutResponse),
        Command.side(Side.right): ([0x43, 0x0A], WriteMode.withoutResponse),
        Command.led(Led.low): ([0x45, 0x0A], WriteMode.withoutResponse),
        Command.led(Led.medium): ([0x46, 0x0A], WriteMode.withoutResponse),
        Command.led(Led.high): ([0x47, 0x0A], WriteMode.withoutResponse),
      };
      cases.forEach((cmd, expected) {
        expect(cmd.bytes, expected.$1, reason: cmd.code);
        expect(cmd.mode, expected.$2, reason: cmd.code);
      });
      for (var n = 0; n <= 9; n++) {
        expect(Command.level(n).bytes, ['0'.codeUnitAt(0) + n, 0x0A]);
        expect(Command.level(n).mode, WriteMode.withoutResponse);
      }
    });

    test('level is clamped to 0..9', () {
      expect(Command.level(12).code, '9');
      expect(Command.level(-3).code, '0');
    });
  });

  group('parseNotification', () {
    test('battery voltage maps to a clamped percentage', () {
      expect((parseLine('Batt:3.83') as BatteryEvent).percent, 83);
      expect((parseLine('Batt:3.97') as BatteryEvent).percent, 100);
      expect((parseLine('Batt:3.40') as BatteryEvent).percent, 0);
    });

    test('both charging formats', () {
      expect((parseLine('u\x011') as ChargingEvent).charging, true);
      expect((parseLine('u\x010') as ChargingEvent).charging, false);
      expect((parseLine('Charging') as ChargingEvent).charging, true);
      expect((parseLine('Not Charging') as ChargingEvent).charging, false);
    });

    test('unknown lines are kept, not dropped', () {
      expect(parseLine('zzz'), isA<UnknownLine>());
      expect(parseLine('Batt:x'), isA<UnknownLine>());
    });
  });

  test('replies split on spaces, tokens rebuilt across notifications', () {
    final rx = ReplyAssembler();
    expect(rx.add('u\x010 mode:0 BR:'), ['u\x010', 'mode:0']);
    expect(rx.hasPartial, true);
    expect(rx.add('100 Batt:3.'), ['BR:100']);
    expect(rx.add('80\r\n'), ['Batt:3.80']);
    expect(rx.hasPartial, false);
    expect(rx.add('fw:1.1.22'), isEmpty);
    expect(rx.flush(), ['fw:1.1.22']);
    expect(rx.add('Not Charging\n'), ['Not Charging']);
  });

  test('glued echoes from a real session are split', () {
    final rx = ReplyAssembler();
    expect(rx.add('+1 0 50 9D '), ['+1', '0', '5', '0', '9', 'D']);
    expect(rx.add('9u\x010 mode:D BR:0 Batt:3.73 +0 '), [
      '9',
      'u\x010',
      'mode:D',
      'BR:0',
      'Batt:3.73',
      '+0',
    ]);
    expect(rx.add('BR:100 Batt:3.809 Pulsetto_ST_02 zz9 '), [
      'BR:100',
      'Batt:3.80',
      '9',
      'Pulsetto_ST_02',
      'zz',
      '9',
    ]);
  });

  test('echoes and ramp replies are events', () {
    expect((parseLine('9') as EchoEvent).level, 9);
    expect((parseLine('D') as EchoEvent).level, isNull);
    expect((parseLine('+1') as RampEvent).running, true);
    expect((parseLine('+0') as RampEvent).running, false);
    expect(parseLine('mode:D'), isA<ModeEvent>());
  });

  test('DFU devices are never connectable', () {
    expect(isConnectableName('Pulsetto'), true);
    expect(isConnectableName('Pulsetto_ST_02'), true);
    expect(isConnectableName('PulsUp'), false);
    expect(isConnectableName(null), false);
    expect(isConnectableName('Other'), false);
  });

  test('log escapes control characters and notes write mode', () {
    final log = ProtocolLog(capacity: 3);
    log.received('u\x010');
    log.sent(Command.rampUp);
    expect(log.entries.first.text, r'u\x010');
    expect(log.entries.last.note, '(with response)');
    log
      ..sent(Command.queryBattery)
      ..sent(Command.queryBattery);
    expect(log.entries.length, 3);
  });
}

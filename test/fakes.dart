import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lull/ble/pulsetto_link.dart';
import 'package:lull/platform/permissions.dart';
import 'package:lull/platform/session_host.dart';
import 'package:lull/protocol/pulsetto_protocol.dart';

class Write {
  Write(this.at, this.command);
  final DateTime at;
  final Command command;
  String get code => command.code;
}

class FakeLink implements PulsettoLink {
  final writes = <Write>[];
  final _found = StreamController<FoundDevice>.broadcast(sync: true);
  final _lost = StreamController<void>.broadcast(sync: true);
  final _received = StreamController<String>.broadcast(sync: true);
  final _availability = StreamController<Availability>.broadcast(sync: true);
  bool connectSucceeds = true;
  bool writesFail = false;
  bool connected = false;
  int connectAttempts = 0;

  @override
  Stream<Availability> get availability => _availability.stream;
  @override
  Future<Availability> currentAvailability() async => Availability.on;
  @override
  Future<void> enableBluetooth() async {}
  @override
  Stream<FoundDevice> get found => _found.stream;
  @override
  Future<void> startScan() async {}
  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String id, {Duration? timeout}) async {
    connectAttempts++;
    if (!connectSucceeds) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      throw StateError('unreachable');
    }
    connected = true;
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<void> get lost => _lost.stream;
  @override
  Stream<String> get received => _received.stream;

  @override
  Future<void> send(Command command) async {
    if (!connected || writesFail) throw StateError('write failed');
    writes.add(Write(clock.now(), command));
  }

  void drop() {
    connected = false;
    _lost.add(null);
  }

  void reply(String payload) => _received.add(payload);
  void setAvailability(Availability a) => _availability.add(a);
  void advertise(FoundDevice d) => _found.add(d);

  List<String> codesFrom(int index) =>
      writes.skip(index).map((w) => w.code).toList();
}

class FakeHost implements SessionHost {
  final stops = StreamController<void>.broadcast(sync: true);
  String? title;
  String? text;
  bool shown = false;
  @override
  Stream<void> get stopRequests => stops.stream;
  @override
  Future<void> show(String title, String text) async {
    shown = true;
    this.title = title;
    this.text = text;
  }

  @override
  Future<void> hide() async => shown = false;
  final alerts = <String>[];
  @override
  Future<void> alertEnded(String title, String text) async =>
      alerts.add('$title: $text');
  @override
  Future<void> keepAwake(bool on) async {}
}

class FakePermissions extends GrantedPermissions {}

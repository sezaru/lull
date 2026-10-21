import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'pulsetto_protocol.dart';

enum Direction { sent, received }

class LogEntry {
  const LogEntry(this.time, this.direction, this.text, {this.mode, this.error});

  final DateTime time;
  final Direction direction;
  final String text;
  final WriteMode? mode;
  final String? error;

  String get timestamp {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.$ms';
  }

  String get arrow => direction == Direction.sent ? '→' : '←';

  String? get note => error != null
      ? '(failed: $error)'
      : mode == WriteMode.withResponse
      ? '(with response)'
      : null;

  String toLine() {
    final n = note;
    return n == null
        ? '$timestamp $arrow $text'
        : '$timestamp $arrow ${text.padRight(6)} $n';
  }
}

/// Control characters are shown as `\xNN`, so the charging reply
/// `u` 0x01 `0` reads `u\x010` exactly like the protocol notes write it.
String escapeControl(String s) => s.runes.map((r) {
  if (r < 0x20 || r == 0x7f) {
    return '\\x${r.toRadixString(16).padLeft(2, '0')}';
  }
  return String.fromCharCode(r);
}).join();

class ProtocolLog extends ChangeNotifier {
  ProtocolLog({this.capacity = 2000});

  final int capacity;
  final _entries = ListQueue<LogEntry>();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void sent(Command command) => _add(
    LogEntry(clock.now(), Direction.sent, command.code, mode: command.mode),
  );

  void failed(Command command, Object error) => _add(
    LogEntry(
      clock.now(),
      Direction.sent,
      command.code,
      mode: command.mode,
      error: error.toString().split('\n').first,
    ),
  );

  void received(String line) =>
      _add(LogEntry(clock.now(), Direction.received, escapeControl(line)));

  void _add(LogEntry entry) {
    _entries.add(entry);
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    notifyListeners();
  }

  String asText() => _entries.map((e) => e.toLine()).join('\n');
}

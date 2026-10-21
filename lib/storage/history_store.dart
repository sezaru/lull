import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/pulsetto_protocol.dart';
import '../session/programs.dart';

enum Outcome { completed, stopped, interrupted }

class SessionRecord {
  const SessionRecord({
    required this.startedAt,
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.strength,
    required this.program,
    required this.side,
    required this.outcome,
  });

  final DateTime startedAt;
  final int plannedSeconds;
  final int actualSeconds;
  final int strength;
  final Program? program;
  final Side side;
  final Outcome outcome;

  /// Sessions shorter than this don't count towards the daily goal.
  static const countsFromSeconds = 60;

  bool get counts => actualSeconds >= countsFromSeconds;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'plannedSeconds': plannedSeconds,
    'actualSeconds': actualSeconds,
    'strength': strength,
    'program': program?.name,
    'side': side.name,
    'outcome': outcome.name,
  };

  static SessionRecord fromJson(Map<String, Object?> j) => SessionRecord(
    startedAt: DateTime.parse(j['startedAt'] as String),
    plannedSeconds: j['plannedSeconds'] as int,
    actualSeconds: j['actualSeconds'] as int,
    strength: j['strength'] as int,
    program: Program.byName(j['program'] as String?),
    side: Side.values.byName(j['side'] as String),
    outcome: Outcome.values.byName(j['outcome'] as String),
  );
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime weekStart(DateTime t) =>
    dayOf(t).subtract(Duration(days: t.weekday - DateTime.monday));

class HistoryStore extends ChangeNotifier {
  HistoryStore(this._prefs) : _records = _load(_prefs);

  static Future<HistoryStore> open() async =>
      HistoryStore(await SharedPreferences.getInstance());

  static const _key = 'history';

  final SharedPreferences _prefs;
  final List<SessionRecord> _records;

  static List<SessionRecord> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((j) => SessionRecord.fromJson((j as Map).cast<String, Object?>()))
        .toList();
  }

  /// Newest first.
  List<SessionRecord> get records => List.unmodifiable(
    [..._records]..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
  );

  void add(SessionRecord r) {
    _records.add(r);
    _save();
  }

  void delete(SessionRecord r) {
    _records.remove(r);
    _save();
  }

  void clear() {
    _records.clear();
    _save();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
    notifyListeners();
  }

  bool isComplete(DateTime day, int goal) =>
      _records
          .where((r) => r.counts && dayOf(r.startedAt) == dayOf(day))
          .length >=
      goal;

  /// Mon..Sun of the week holding [now].
  List<bool> week(DateTime now, int goal) {
    final start = weekStart(now);
    return [
      for (var i = 0; i < 7; i++)
        isComplete(DateTime(start.year, start.month, start.day + i), goal),
    ];
  }
}

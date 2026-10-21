import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/pulsetto_protocol.dart';
import '../session/programs.dart';

enum LedMode {
  auto('Auto (per program)'),
  low('Low'),
  medium('Medium'),
  high('High');

  const LedMode(this.label);
  final String label;

  Led resolve(Program? program) => switch (this) {
    LedMode.auto => program?.led ?? Led.medium,
    LedMode.low => Led.low,
    LedMode.medium => Led.medium,
    LedMode.high => Led.high,
  };
}

class SettingsStore {
  SettingsStore(this._prefs);

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _customProgram = 'custom';

  Program? get program {
    final name = _prefs.getString('program');
    if (name == _customProgram) return null;
    return Program.byName(name) ?? Program.stress;
  }

  set program(Program? p) =>
      _prefs.setString('program', p?.name ?? _customProgram);

  int get minutes => _prefs.getInt('minutes') ?? Program.stress.minutes;
  set minutes(int v) => _prefs.setInt('minutes', v);

  int get intensity => _prefs.getInt('intensity') ?? 1;
  set intensity(int v) => _prefs.setInt('intensity', v);

  Side get side => Side.values.firstWhere(
    (s) => s.name == _prefs.getString('side'),
    orElse: () => Side.both,
  );
  set side(Side v) => _prefs.setString('side', v.name);

  LedMode get ledMode => LedMode.values.firstWhere(
    (m) => m.name == _prefs.getString('ledMode'),
    orElse: () => LedMode.auto,
  );
  set ledMode(LedMode v) => _prefs.setString('ledMode', v.name);

  bool get alertOnEnd => _prefs.getBool('alertOnEnd') ?? true;
  set alertOnEnd(bool v) => _prefs.setBool('alertOnEnd', v);

  bool get keepScreenOn => _prefs.getBool('keepScreenOn') ?? false;
  set keepScreenOn(bool v) => _prefs.setBool('keepScreenOn', v);

  int get dailyGoal => _prefs.getInt('dailyGoal') ?? 2;
  set dailyGoal(int v) => _prefs.setInt('dailyGoal', v);

  String? get deviceId => _prefs.getString('deviceId');
  set deviceId(String? v) =>
      v == null ? _prefs.remove('deviceId') : _prefs.setString('deviceId', v);

  bool get notificationsAsked => _prefs.getBool('notificationsAsked') ?? false;
  set notificationsAsked(bool v) => _prefs.setBool('notificationsAsked', v);
}

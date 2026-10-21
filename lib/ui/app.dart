import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../protocol/protocol_log.dart';
import '../session/session_controller.dart';
import '../storage/history_store.dart';
import 'device_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'icons.dart';
import 'settings_screen.dart';
import 'theme.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.controller,
    required this.history,
    required this.log,
    required super.child,
  });

  final SessionController controller;
  final HistoryStore history;
  final ProtocolLog log;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) =>
      old.controller != controller || old.history != history || old.log != log;
}

class LullApp extends StatelessWidget {
  const LullApp({
    super.key,
    required this.controller,
    required this.history,
    required this.log,
  });

  final SessionController controller;
  final HistoryStore history;
  final ProtocolLog log;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      history: history,
      log: log,
      child: MaterialApp(
        title: 'Lull',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _openedDevice = false;
  SessionController? _c;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context).controller;
    if (_c != c) {
      _c?.removeListener(_firstRun);
      _c = c..addListener(_firstRun);
      WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
    }
  }

  /// First launch goes straight to finding the device.
  void _firstRun() {
    final c = _c!;
    if (_openedDevice || c.gate != Gate.ready || c.hasDevice || !mounted) {
      return;
    }
    _openedDevice = true;
    Navigator.of(context).push(DeviceScreen.route());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _c;
    if (c == null) return;
    if (state == AppLifecycleState.resumed) c.refreshGate();
    if (state == AppLifecycleState.detached) c.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.removeListener(_firstRun);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(b, context.colors),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const [HomeScreen(), HistoryScreen(), SettingsScreen()],
          ),
        ),
        bottomNavigationBar: _NavBar(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _tabs = [
    (LullGlyph.home, 'Home'),
    (LullGlyph.history, 'History'),
    (LullGlyph.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.chrome,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              for (final (i, (glyph, label)) in _tabs.indexed)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 64,
                            height: 32,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? c.fgSoft2
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: LullIcon(
                              glyph,
                              color: i == index ? c.fg : c.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index ? c.fg : c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

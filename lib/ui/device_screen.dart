import 'package:flutter/material.dart';

import '../ble/pulsetto_link.dart';
import '../session/session_controller.dart';
import 'app.dart';
import 'blocking.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets/basics.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const DeviceScreen());

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final c = AppScope.of(context).controller;
    if (!c.hasDevice &&
        c.linkState == LinkState.disconnected &&
        c.scanState != ScanState.scanning) {
      c.startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).controller;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageBar(title: 'Device'),
              Expanded(child: _body(context, c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SessionController c) {
    if (c.gate != Gate.ready) return BlockingView(c: c);
    if (c.hasDevice) return _Info(c: c);
    return switch (c.scanState) {
      ScanState.scanning => const CenteredState(
        glyph: LullGlyph.nearby,
        pulse: true,
        title: 'Looking for your Pulsetto…',
        body: 'Make sure it’s switched on and nearby.',
        extra: _ScanBar(),
      ),
      ScanState.several => _Picker(c: c),
      ScanState.none => CenteredState(
        glyph: LullGlyph.device,
        title: 'No Pulsetto found',
        body: 'Make sure it’s switched on and nearby.',
        action: AccentButton(label: 'Try again', onTap: c.startScan),
      ),
      ScanState.idle =>
        c.linkState == LinkState.connecting
            ? CenteredState(
                glyph: LullGlyph.device,
                title: 'Connecting…',
                extra: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Spinner(color: context.colors.muted),
                ),
              )
            : CenteredState(
                glyph: LullGlyph.device,
                title: 'No Pulsetto found',
                body: 'Make sure it’s switched on and nearby.',
                action: AccentButton(label: 'Try again', onTap: c.startScan),
              ),
    };
  }
}

/// Back arrow and a title.
class PageBar extends StatelessWidget {
  const PageBar({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Row(
          children: [
            CircleIconButton(
              glyph: LullGlyph.back,
              filled: false,
              tooltip: 'Back',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SizedBox(
        width: 160,
        child: FillBar(
          duration: SessionController.scanWindow,
          color: c.fg,
          track: c.fgSoft2,
        ),
      ),
    );
  }
}

String shortAddress(String id) {
  final up = id.toUpperCase();
  return up.length > 5 ? '…${up.substring(up.length - 5)}' : up;
}

class _Picker extends StatelessWidget {
  const _Picker({required this.c});
  final SessionController c;

  int _bars(int? rssi) {
    if (rssi == null) return 1;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(
            'Which one is yours?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            'Tap it to connect.',
            style: TextStyle(fontSize: 15, color: col.muted),
          ),
        ),
        for (final FoundDevice d in c.found) ...[
          Material(
            color: col.fgSoft,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              overlayColor: WidgetStatePropertyAll(col.fgSoft),
              onTap: () => c.pick(d),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      LullIcon(LullGlyph.device, color: col.fg),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              shortAddress(d.id),
                              style: monoStyle(14, col.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _bars(d.rssi) >= 3 ? 'Strong' : 'Weak',
                        style: TextStyle(fontSize: 14, color: col.muted),
                      ),
                      const SizedBox(width: 8),
                      SignalBars(
                        bars: _bars(d.rssi),
                        on: col.fg,
                        off: col.border,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.c});
  final SessionController c;

  Future<void> _forget(BuildContext context) async {
    final ok = await confirmDestructive(
      context,
      title: 'Forget this Pulsetto?',
      body: 'Lull will look for a Pulsetto again the next time it opens.',
      action: 'Forget',
    );
    if (!ok || !context.mounted) return;
    await c.forget();
    if (context.mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final info = c.info;
    final inSession = c.phase != SessionPhase.idle;
    final status = switch (c.linkState) {
      LinkState.connected => 'Connected',
      LinkState.connecting => 'Connecting…',
      LinkState.disconnected => 'Not connected',
    };
    const dash = '—';
    final rows = <(String, String, bool)>[
      ('Battery', info.battery == null ? dash : '${info.battery}%', false),
      (
        'Charging',
        switch (info.charging) {
          true => 'Charging',
          false => 'Not charging',
          null => dash,
        },
        false,
      ),
      ('Address', c.deviceId!.toUpperCase(), true),
      ('Firmware', info.firmware ?? dash, false),
      ('Identity', info.identity ?? dash, true),
    ];
    final diag = [
      if (info.mode != null) 'mode ${info.mode}',
      if (info.br != null) 'BR ${info.br}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
            child: Row(
              children: [
                const Glyph(LullGlyph.device, size: 64),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pulsetto',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                      ),
                    ),
                    Row(
                      children: [
                        if (c.linkState == LinkState.connecting)
                          Spinner(size: 10, color: col.muted)
                        else
                          StatusDot(on: c.linkState == LinkState.connected),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(fontSize: 15, color: col.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: col.surface,
              border: Border.all(color: col.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final (i, (k, v, mono)) in rows.indexed)
                  Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: i == 0
                        ? null
                        : BoxDecoration(
                            border: Border(top: BorderSide(color: col.border)),
                          ),
                    child: Row(
                      children: [
                        Text(
                          k,
                          style: TextStyle(fontSize: 15, color: col.muted),
                        ),
                        const Spacer(),
                        Text(
                          v,
                          style: mono
                              ? monoStyle(15, col.fg)
                              : const TextStyle(
                                  fontSize: 15,
                                  fontFeatures: tabular,
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (diag.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Text(diag, style: monoStyle(13, col.muted)),
            ),
          const Spacer(),
          DangerButton(
            label: 'Forget device',
            onTap: inSession ? null : () => _forget(context),
          ),
          if (inSession)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Stop the session to forget this device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: col.muted),
              ),
            ),
        ],
      ),
    );
  }
}

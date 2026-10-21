import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../protocol/protocol_log.dart';
import 'app.dart';
import 'device_screen.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets/basics.dart';

/// What the app sent and received, newest at the bottom. Shared as text it
/// can be diffed against an HCI snoop of the official app.
class ProtocolLogScreen extends StatelessWidget {
  const ProtocolLogScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const ProtocolLogScreen());

  @override
  Widget build(BuildContext context) {
    final log = AppScope.of(context).log;
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageBar(
              title: 'Protocol log',
              trailing: TextAction(
                label: 'Share as text',
                icon: LullGlyph.share,
                onTap: () => SharePlus.instance.share(
                  ShareParams(text: log.asText(), subject: 'Lull protocol log'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  _legend(c, Colors.transparent, c.border, '→ Sent'),
                  const SizedBox(width: 20),
                  _legend(c, c.fgSoft2, Colors.transparent, '← Received'),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: ListenableBuilder(
                  listenable: log,
                  builder: (context, _) {
                    final entries = log.entries;
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      itemCount: entries.length,
                      itemBuilder: (context, i) =>
                          _Line(entries[entries.length - 1 - i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(LullColors c, Color fill, Color border, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(label, style: monoStyle(13, c.muted)),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line(this.e);
  final LogEntry e;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rx = e.direction == Direction.received;
    return Container(
      color: rx ? c.fgSoft2 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(e.timestamp, style: monoStyle(13, c.muted)),
          ),
          SizedBox(
            width: 22,
            child: Text(
              e.arrow,
              style: monoStyle(13, c.fg).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (e.note == null)
            Expanded(child: Text(e.text, style: monoStyle(13, c.fg)))
          else ...[
            SizedBox(
              width: 56,
              child: Text(e.text, style: monoStyle(13, c.fg)),
            ),
            Text(e.note!, style: monoStyle(13, c.muted)),
          ],
        ],
      ),
    );
  }
}

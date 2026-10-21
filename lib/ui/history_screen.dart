import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../session/programs.dart';
import '../session/session_controller.dart';
import '../storage/history_store.dart';
import '../protocol/pulsetto_protocol.dart';
import 'app.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'theme.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String dayHeading(DateTime day, DateTime now) {
  final today = dayOf(now);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}';
}

String _mss(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _clearAll(BuildContext context, HistoryStore h) async {
    final n = h.records.length;
    final ok = await confirmDestructive(
      context,
      title: 'Clear all sessions?',
      body: n == 1
          ? 'This deletes 1 session. It can’t be undone.'
          : 'This deletes all $n sessions. It can’t be undone.',
      action: 'Clear all',
    );
    if (ok) h.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final h = scope.history;
    final c = scope.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([h, c]),
      builder: (context, _) {
        final now = clock.now();
        final records = h.records;
        final groups = <DateTime, List<SessionRecord>>{};
        for (final r in records) {
          groups.putIfAbsent(dayOf(r.startedAt), () => []).add(r);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (records.isNotEmpty)
                    _OverflowMenu(onClearAll: () => _clearAll(context, h)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _WeekCard(
              done: h.week(now, c.settings.dailyGoal),
              today: now.weekday - 1,
              goal: c.settings.dailyGoal,
            ),
            if (records.isEmpty)
              const _Empty()
            else
              for (final MapEntry(key: day, value: rows) in groups.entries) ...[
                _GroupHeading(dayHeading(day, now)),
                for (final (i, r) in rows.indexed)
                  _SessionRow(
                    record: r,
                    divider: i > 0,
                    onDelete: () => h.delete(r),
                  ),
              ],
          ],
        );
      },
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onClearAll});
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopupMenuButton<void>(
      tooltip: 'More',
      icon: LullIcon(LullGlyph.more, color: c.fg),
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 196),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: onClearAll,
          height: 48,
          child: const Text('Clear all', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.done,
    required this.today,
    required this.goal,
  });
  final List<bool> done;
  final int today;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = done.where((d) => d).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      _Day(done: done[i], today: i == today),
                      const SizedBox(height: 8),
                      Text(
                        _weekdays[i],
                        style: TextStyle(
                          fontSize: 13,
                          color: i == today ? c.fg : c.muted,
                          fontWeight: i == today
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '$count of 7 days this week',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    goal == 1
                        ? 'Goal: 1 session a day'
                        : 'Goal: $goal sessions a day',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 14, color: c.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.done, required this.today});
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final circle = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.ok : null,
        border: Border.all(color: done ? c.ok : c.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: done
          ? LullIcon(LullGlyph.check, size: 18, color: c.bg, strokeWidth: 2)
          : null,
    );
    if (!today) return Padding(padding: const EdgeInsets.all(5), child: circle);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.fg, width: 2),
      ),
      child: circle,
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colors.muted,
      ),
    ),
  );
}

class _SessionRow extends StatefulWidget {
  const _SessionRow({
    required this.record,
    required this.divider,
    required this.onDelete,
  });
  final SessionRecord record;
  final bool divider;
  final VoidCallback onDelete;

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _menu = false;

  Future<void> _openMenu(Offset at) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final c = context.colors;
    setState(() => _menu = true);
    final delete = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        at & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(minWidth: 172),
      items: [
        PopupMenuItem(
          value: true,
          height: 48,
          child: Text(
            'Delete session',
            style: TextStyle(fontSize: 16, color: c.danger),
          ),
        ),
      ],
    );
    if (mounted) setState(() => _menu = false);
    if (delete == true) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = widget.record;
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(r.startedAt),
      alwaysUse24HourFormat: h24,
    );
    final meta = [
      '${r.actualSeconds ~/ 60} of ${r.plannedSeconds ~/ 60} min',
      'Intensity ${r.strength}',
      if (r.side != Side.both) sideLabel(r.side),
    ].join(' · ');
    final outcome = switch (r.outcome) {
      Outcome.completed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LullIcon(LullGlyph.check, size: 16, color: c.ok),
          const SizedBox(width: 4),
          Text('Completed', style: TextStyle(fontSize: 14, color: c.ok)),
        ],
      ),
      Outcome.stopped => Text(
        'Stopped at ${_mss(r.actualSeconds)}',
        style: TextStyle(fontSize: 14, color: c.muted, fontFeatures: tabular),
      ),
      Outcome.interrupted => Text(
        'Interrupted',
        style: TextStyle(fontSize: 14, color: c.warn),
      ),
    };
    return Container(
      decoration: widget.divider
          ? BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            )
          : null,
      child: GestureDetector(
        onLongPressStart: (d) => _openMenu(d.globalPosition),
        onSecondaryTapDown: (d) => _openMenu(d.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: _menu ? c.fgSoft2 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: h24 ? 52 : 76,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 15,
                      color: c.muted,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            programLabel(r.program),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        outcome,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.muted,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
    child: Column(
      children: [
        const Text(
          'No sessions yet.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Your sessions will show up here.',
          style: TextStyle(fontSize: 16, color: context.colors.muted),
        ),
      ],
    ),
  );
}

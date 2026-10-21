import 'package:flutter/material.dart';

import '../storage/settings_store.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets/basics.dart';

class _LullDialog extends StatelessWidget {
  const _LullDialog({
    required this.title,
    this.body,
    this.content,
    required this.actions,
  });
  final String title;
  final String? body;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (body != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
                child: Text(
                  body!,
                  style: TextStyle(fontSize: 15, height: 1.5, color: c.muted),
                ),
              ),
            ?content,
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }
}

/// A destructive confirmation: Cancel, then the red action.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final c = context.colors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => _LullDialog(
      title: title,
      body: body,
      actions: [
        TextAction(label: 'Cancel', onTap: () => Navigator.pop(context, false)),
        const SizedBox(width: 4),
        TextAction(
          label: action,
          color: c.danger,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<LedMode?> pickLedMode(BuildContext context, LedMode current) {
  return showDialog<LedMode>(
    context: context,
    builder: (context) => _LullDialog(
      title: 'LED brightness',
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            for (final m in LedMode.values)
              _RadioRow(
                label: m.label,
                sub: m == LedMode.auto
                    ? 'Dim for Sleep, medium otherwise'
                    : null,
                checked: m == current,
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
      actions: [
        TextAction(label: 'Cancel', onTap: () => Navigator.pop(context)),
      ],
    ),
  );
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    this.sub,
    required this.checked,
    required this.onTap,
  });
  final String label;
  final String? sub;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: checked,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        overlayColor: WidgetStatePropertyAll(c.fgSoft),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: checked ? c.fg : c.muted, width: 2),
                ),
                padding: const EdgeInsets.all(3),
                child: checked
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.fg,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 16, height: 1.3),
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: c.muted,
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

/// Asked once, on the first Start (Android 13+). Either answer starts the
/// session.
Future<bool> askNotifications(BuildContext context) async {
  final allow = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final c = context.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Glyph(LullGlyph.bell),
              const SizedBox(height: 20),
              const SizedBox(
                width: 280,
                child: Text(
                  'Allow notifications so you can see and stop sessions with the screen off.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AccentButton(
                label: 'Allow',
                height: 56,
                onTap: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 8),
              TextAction(
                label: 'Not now',
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return allow ?? false;
}

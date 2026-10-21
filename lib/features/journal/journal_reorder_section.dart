import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_service.dart';
import 'journal_strings.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Hold/release opens actions; hold/move uses Flutter's reorder gaps and autoscroll.
class JournalReorderSection extends StatefulWidget {
  const JournalReorderSection(
      {super.key,
      required this.entries,
      required this.notes,
      required this.tile,
      required this.travel,
      required this.onMenu,
      required this.onReorder,
      this.enabled = true});
  final List<JournalEntry> entries;
  final bool notes, enabled;
  final Widget Function(JournalEntry) tile;
  final double Function() travel;
  final ValueChanged<JournalEntry> onMenu;
  final Future<void> Function(List<String> order, Set<String>? pinned)
      onReorder;
  @override
  State<JournalReorderSection> createState() => _JournalReorderSectionState();
}

class _JournalReorderSectionState extends State<JournalReorderSection> {
  List<String>? _pending;
  String? _held;
  bool _busy = false;
  List<String> get _rows {
    if (_pending != null) return _pending!;
    if (!widget.notes) return widget.entries.map((e) => e.key).toList();
    return [
      for (final e in widget.entries.where((e) => e.note!.isPinned)) e.key,
      '@pin-boundary',
      for (final e in widget.entries.where((e) => !e.note!.isPinned)) e.key
    ];
  }

  void _end(int index) {
    final key = _held;
    _held = null;
    if (key == null || widget.travel() > 12) return;
    final entry = widget.entries.where((e) => e.key == key).firstOrNull;
    if (entry == null) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted && !_busy) widget.onMenu(entry);
    });
  }

  Future<void> _reorder(int old, int next) async {
    if (_busy || old == next) return;
    final rows = List<String>.of(_rows);
    final key = rows.removeAt(old);
    rows.insert(next, key);
    if (key == '@pin-boundary') return;
    final boundary = rows.indexOf('@pin-boundary');
    final pinned = widget.notes ? rows.take(boundary).toSet() : null;
    final order = rows.where((key) => key != '@pin-boundary').toList();
    setState(() {
      _pending = rows;
      _busy = true;
    });
    try {
      await widget.onReorder(order, pinned);
    } finally {
      if (mounted) {
        setState(() {
          _pending = null;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final rows = _rows;
    final byKey = {for (final e in widget.entries) e.key: e};
    return SliverReorderableList(
      itemCount: rows.length,
      onReorderItem: _reorder,
      onReorderStart: (index) {
        _held = rows[index];
        HapticFeedback.mediumImpact();
      },
      onReorderEnd: _end,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (_, child) => Transform.scale(
              scale: MediaQuery.disableAnimationsOf(context)
                  ? 1
                  : 1 + .025 * AppMotion.standard.transform(animation.value),
              child: Material(
                  type: MaterialType.transparency,
                  elevation: 5 * animation.value,
                  shadowColor: c.shadow.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  child: child))),
      itemBuilder: (context, index) {
        final key = rows[index];
        if (key == '@pin-boundary') {
          return Padding(
              key: const ValueKey('journal-pin-boundary'),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Icon(Icons.notes_outlined, size: 16, color: c.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        widget.entries.any((e) => e.note!.isPinned)
                            ? s.t('Остальные записи', 'Other notes')
                            : s.t('Перетащи выше, чтобы закрепить',
                                'Drag above to pin'),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: c.onSurfaceVariant))),
                const SizedBox(width: 10),
                const SizedBox(width: 32, child: Divider()),
              ]));
        }
        final entry = byKey[key];
        if (entry == null) return SizedBox.shrink(key: ValueKey(key));
        return ReorderableDelayedDragStartListener(
            key: ValueKey('journal-row-$key'),
            index: index,
            enabled: widget.enabled && !_busy,
            child: widget.tile(entry));
      },
    );
  }
}

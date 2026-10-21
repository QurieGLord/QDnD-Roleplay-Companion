import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/quest.dart';
import '../../core/models/journal_note.dart';
import 'journal_strings.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

Widget journalImage(BuildContext context, String path,
    {double height = 160, double? width}) {
  final s = JournalStrings(context);
  Widget error(BuildContext context, Object error, StackTrace? stack) =>
      Container(
          height: height,
          width: width,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 8),
            Text(s.t('Фото недоступно', 'Image unavailable'))
          ]));
  return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      child: path.startsWith('http')
          ? Image.network(path,
              height: height,
              width: width,
              fit: BoxFit.cover,
              errorBuilder: error)
          : Image.file(File(path),
              height: height,
              width: width,
              fit: BoxFit.cover,
              errorBuilder: error));
}

class JournalEntryTile extends StatefulWidget {
  const JournalEntryTile(
      {super.key,
      required this.entry,
      required this.onTap,
      this.onMenu,
      this.reorderManaged = false,
      this.connectionCount = 0,
      this.session});
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onMenu;
  final bool reorderManaged;
  final int connectionCount;
  final int? session;
  @override
  State<JournalEntryTile> createState() => _JournalEntryTileState();
}

class _JournalEntryTileState extends State<JournalEntryTile>
    with SingleTickerProviderStateMixin {
  late final _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 160));
  Timer? _holdDelay;
  Offset? _pressOrigin;
  @override
  void dispose() {
    _holdDelay?.cancel();
    _press.dispose();
    super.dispose();
  }

  void _release() {
    _holdDelay?.cancel();
    _pressOrigin = null;
    if (_press.value != 0 || _press.isAnimating) _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final entry = widget.entry, q = widget.entry.quest;
    final accent = q == null ? c.primary : c.tertiary;
    final completed = q?.status == QuestStatus.completed;
    final next = q?.objectives.where((o) => !o.isCompleted).firstOrNull;
    Widget badge(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: c.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.onSurfaceVariant)))
        ]));
    final card = Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: CompanionSurface(
          color: Color.lerp(c.surfaceContainerLow,
              q == null ? c.secondaryContainer : c.tertiaryContainer, .35),
          contour: q == null ? CompanionContour.fold : CompanionContour.facet,
          padding: EdgeInsets.zero,
          quiet: true,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.reorderManaged ? null : widget.onMenu,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: accent.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(11)),
                            child: Icon(
                                q != null
                                    ? completed
                                        ? Icons.task_alt
                                        : Icons.flag_outlined
                                    : entry.note!.category.icon,
                                size: 17,
                                color: accent)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                q == null
                                    ? s.ru
                                        ? entry.note!.category.displayNameRu
                                        : entry.note!.category.displayName
                                    : s.ru
                                        ? q.status.displayNameRu
                                        : q.status.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: accent))),
                        if (entry.note?.isPinned ?? false)
                          Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.push_pin_rounded,
                                  size: 16, color: accent)),
                        if (widget.onMenu != null)
                          SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  tooltip:
                                      s.t('Быстрые действия', 'Quick actions'),
                                  onPressed: widget.onMenu,
                                  padding: EdgeInsets.zero)),
                      ]),
                      const SizedBox(height: 14),
                      Text(entry.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: -.35)),
                      if (entry.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(entry.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: c.onSurfaceVariant, height: 1.6))
                      ],
                      if (entry.image != null) ...[
                        const SizedBox(height: 18),
                        journalImage(context, entry.image!,
                            height: 150, width: double.infinity)
                      ],
                      if (q != null && q.objectives.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: c.surfaceContainerHigh
                                    .withValues(alpha: .55),
                                borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(
                                        next == null
                                            ? Icons.check_circle_outline
                                            : Icons.subdirectory_arrow_right,
                                        size: 16,
                                        color: accent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(
                                            next == null
                                                ? s.t('Все шаги отмечены',
                                                    'All steps checked')
                                                : s.t('Следующий шаг',
                                                    'Next step'),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(color: accent))),
                                    Text(
                                        '${q.completedObjectivesCount}/${q.objectives.length}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium),
                                  ]),
                                  if (next != null) ...[
                                    const SizedBox(height: 9),
                                    Text(next.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.4))
                                  ],
                                  const SizedBox(height: 12),
                                  TweenAnimationBuilder<double>(
                                      tween: Tween(
                                          begin: q.progress, end: q.progress),
                                      duration: MediaQuery.disableAnimationsOf(
                                              context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 240),
                                      builder: (_, value, __) => ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(AppRadii.sm),
                                          child: LinearProgressIndicator(
                                              value: value,
                                              minHeight: 4,
                                              color: accent,
                                              backgroundColor:
                                                  c.surfaceContainerHighest))),
                                ])),
                      ],
                      if (widget.session != null ||
                          widget.connectionCount > 0 ||
                          (entry.note?.tags.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 18),
                        Divider(
                            height: 1,
                            color: c.outlineVariant.withValues(alpha: .55)),
                        const SizedBox(height: 13),
                        Wrap(spacing: 7, runSpacing: 7, children: [
                          if (widget.session != null)
                            badge(
                                Icons.history,
                                s.t('Сессия ${widget.session}',
                                    'Session ${widget.session}')),
                          if (widget.connectionCount > 0)
                            badge(Icons.link, '${widget.connectionCount}'),
                          ...?entry.note?.tags
                              .take(3)
                              .map((tag) => badge(Icons.tag, tag)),
                          if ((entry.note?.tags.length ?? 0) > 3)
                            badge(Icons.more_horiz,
                                '+${entry.note!.tags.length - 3}'),
                        ]),
                      ],
                    ])),
          ),
        ));
    return Semantics(
        onLongPress: widget.onMenu,
        child: Listener(
          onPointerDown: (event) {
            _pressOrigin = event.position;
            _holdDelay?.cancel();
            if (!MediaQuery.disableAnimationsOf(context)) {
              _holdDelay = Timer(const Duration(milliseconds: 370), () {
                if (mounted && _pressOrigin != null) _press.forward(from: 0);
              });
            }
          },
          onPointerMove: (event) {
            if (_pressOrigin != null &&
                (event.position - _pressOrigin!).distance > 8) {
              _release();
            }
          },
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: AnimatedBuilder(
              animation: _press,
              child: card,
              builder: (_, child) => Transform.scale(
                  key: ValueKey('journal-card-press-${widget.entry.key}'),
                  scale: 1 - .025 * Curves.easeInOut.transform(_press.value),
                  child: child)),
        ));
  }
}

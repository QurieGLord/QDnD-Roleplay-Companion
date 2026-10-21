import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/journal/journal_graph.dart';
import 'journal_strings.dart';

class JournalStoryCarousel extends StatefulWidget {
  const JournalStoryCarousel(
      {super.key,
      required this.entities,
      required this.selected,
      required this.count,
      required this.onSelected});
  final List<JournalEntity> entities;
  final String? selected;
  final int Function(String id) count;
  final ValueChanged<String> onSelected;
  @override
  State<JournalStoryCarousel> createState() => _JournalStoryCarouselState();
}

class _JournalStoryCarouselState extends State<JournalStoryCarousel> {
  late final _pages =
      PageController(viewportFraction: .62, initialPage: _index());
  int? _requested;
  String? _emitted;
  bool _settling = false;
  int _index() {
    final index = widget.entities.indexWhere((e) => e.id == widget.selected);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant JournalStoryCarousel old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected ||
        old.entities.map((e) => e.id).join('|') !=
            widget.entities.map((e) => e.id).join('|')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pages.hasClients || widget.entities.isEmpty) return;
        final index = _index();
        if (_requested == index ||
            widget.selected == _emitted ||
            (_pages.page ?? 0).round() == index) {
          return;
        }
        if (MediaQuery.disableAnimationsOf(context)) {
          _pages.jumpToPage(index);
        } else {
          _pages.animateToPage(index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic);
        }
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _choose(int index) {
    if (!_pages.hasClients) return;
    _requested = index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
      _requested = null;
    } else {
      _pages
          .animateToPage(index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic)
          .whenComplete(() {
        if (mounted && _requested == index) _requested = null;
      });
    }
    _emitted = widget.entities[index].id;
    widget.onSelected(_emitted!);
  }

  bool _settle(ScrollEndNotification event) {
    if (event.depth != 0 ||
        widget.entities.isEmpty ||
        _settling ||
        _requested != null ||
        !_pages.hasClients) {
      return false;
    }
    final page = _pages.page ?? 0;
    final nearest = page.round().clamp(0, widget.entities.length - 1);
    if ((page - nearest).abs() < .02) return false;
    _settling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pages.hasClients) return;
      _pages
          .animateToPage(nearest,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic)
          .whenComplete(() {
        if (mounted) _settling = false;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), t = Theme.of(context), c = t.colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SizedBox(
        height: 160 + ((scale - 1) * 160).clamp(0, 240),
        child: NotificationListener<ScrollEndNotification>(
            onNotification: _settle,
            child: PageView.builder(
                key: const ValueKey('journal-story-carousel'),
                controller: _pages,
                itemCount: widget.entities.length,
                pageSnapping: false,
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                onPageChanged: (index) {
                  if (index >= widget.entities.length) return;
                  _emitted = widget.entities[index].id;
                  widget.onSelected(_emitted!);
                },
                itemBuilder: (context, index) {
                  final e = widget.entities[index],
                      count = widget.count(widget.entities[index].id);
                  return AnimatedBuilder(
                      animation: _pages,
                      builder: (context, _) {
                        final page = _pages.hasClients &&
                                _pages.position.hasContentDimensions
                            ? _pages.page ?? 0
                            : _pages.initialPage.toDouble();
                        final distance = (page - index).abs().clamp(0.0, 1.0);
                        final magnification =
                            MediaQuery.disableAnimationsOf(context)
                                ? 1.0
                                : 1 - .14 * Curves.easeOut.transform(distance);
                        return Transform.scale(
                            key: ValueKey('story-scale-${e.id}'),
                            scale: magnification,
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(7, 8, 7, 10),
                                child: Semantics(
                                    selected: widget.selected == e.id,
                                    button: true,
                                    child: CompanionSurface(
                                        key: ValueKey('story-select-${e.id}'),
                                        contour: CompanionContour.focus,
                                        quiet: true,
                                        color: widget.selected == e.id
                                            ? c.primaryContainer
                                            : c.surfaceContainerLow,
                                        padding: const EdgeInsets.all(14),
                                        onTap: () => _choose(index),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: c.surface
                                                            .withValues(
                                                                alpha: .75),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16)),
                                                    child: Icon(s.icon(e.kind),
                                                        size: 22,
                                                        color: c.primary)),
                                                const SizedBox(width: 9),
                                                Expanded(
                                                    child: Text(s.kind(e.kind),
                                                        maxLines: 2,
                                                        style: t.textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                                color: c
                                                                    .onSurfaceVariant))),
                                              ]),
                                              Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 6),
                                                  child: Text(
                                                      e.name,
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: t
                                                          .textTheme.titleLarge
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 20,
                                                              letterSpacing:
                                                                  -.4,
                                                              height: 1.12))),
                                              Row(children: [
                                                Icon(Icons.link_rounded,
                                                    size: 16,
                                                    color: c.secondary),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                    child: Text(
                                                        s.t('Записей: $count',
                                                            'Entries: $count'),
                                                        style: t.textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                                color: c
                                                                    .onSurfaceVariant))),
                                                if (widget.selected == e.id)
                                                  Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 17,
                                                      color: c.secondary),
                                              ]),
                                            ])))));
                      });
                })));
  }
}

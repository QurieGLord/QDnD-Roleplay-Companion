import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

class ClassPanelEntry {
  const ClassPanelEntry(
      {required this.id,
      required this.name,
      required this.level,
      required this.child});
  final String id, name;
  final int level;
  final Widget child;
}

/// An inline class carousel. Each panel keeps its local state; the viewport
/// follows its natural height so the shared spell section remains directly below.
class ClassPanelDeck extends StatefulWidget {
  const ClassPanelDeck({super.key, required this.panels});
  final List<ClassPanelEntry> panels;
  @override
  State<ClassPanelDeck> createState() => _ClassPanelDeckState();
}

class _ClassPanelDeckState extends State<ClassPanelDeck> {
  late final PageController _pager = PageController()
    ..addListener(_positionChanged);
  final _heights = <String, double>{}, _tabs = <String, GlobalKey>{};
  String? _selected;
  double _page = 0;
  bool _paging = false, _reconciling = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.panels.firstOrNull?.id;
  }

  @override
  void dispose() {
    _pager.removeListener(_positionChanged);
    _pager.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ClassPanelDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.panels.map((p) => p.id).toList();
    _heights.removeWhere((id, _) => !ids.contains(id));
    _tabs.removeWhere((id, _) => !ids.contains(id));
    final changed =
        oldWidget.panels.map((p) => p.id).join('|') != ids.join('|');
    if (!changed) return;
    if (!ids.contains(_selected)) _selected = ids.firstOrNull;
    final index = ids.indexOf(_selected ?? '');
    _page = index < 0 ? 0 : index.toDouble();
    _reconciling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pager.hasClients && index >= 0) _pager.jumpToPage(index);
      _reconciling = false;
      _revealTab();
    });
  }

  void _positionChanged() {
    if (!_pager.hasClients || _reconciling) return;
    final page = _pager.page ?? 0;
    if ((_page - page).abs() > .0001) setState(() => _page = page);
  }

  void _measure(String id, Size size) {
    if (!mounted ||
        !size.height.isFinite ||
        !widget.panels.any((p) => p.id == id)) {
      return;
    }
    final height = size.height;
    if (((_heights[id] ?? -1) - height).abs() > .5) {
      setState(() => _heights[id] = height);
    }
  }

  void _revealTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tab = _tabs[_selected]?.currentContext;
      final scroll = tab == null ? null : Scrollable.maybeOf(tab);
      final target = tab?.findRenderObject();
      if (scroll != null && target != null) {
        scroll.position.ensureVisible(target,
            alignment: .5,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _select(int index) {
    if (!_pager.hasClients || widget.panels[index].id == _selected) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pager.jumpToPage(index);
    } else {
      final distance = (index - _page).abs();
      _pager.animateToPage(index,
          duration: Duration(
              milliseconds: (300 + distance * 35).clamp(300, 460).round()),
          curve: Curves.easeInOutCubic);
    }
  }

  bool _scrolling(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification && !_paging) {
      setState(() => _paging = true);
    }
    if (notification is ScrollEndNotification && _paging) {
      setState(() => _paging = false);
    }
    return false;
  }

  double get _height {
    final position = _page.clamp(0, widget.panels.length - 1).toDouble();
    final lower = position.floor(), upper = position.ceil();
    final fallback = _heights[_selected] ?? 320;
    return lerpDouble(_heights[widget.panels[lower].id] ?? fallback,
        _heights[widget.panels[upper].id] ?? fallback, position - lower)!;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.panels.isEmpty) return const SizedBox.shrink();
    if (widget.panels.length == 1) return widget.panels.single.child;
    final selected = widget.panels.indexWhere((p) => p.id == _selected);
    final current = selected < 0 ? 0 : selected;
    final theme = Theme.of(context), colors = theme.colorScheme;
    final l = AppLocalizations.of(context)!,
        ru = Localizations.localeOf(context).languageCode == 'ru';
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Expanded(
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (var i = 0; i < widget.panels.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: KeyedSubtree(
                                key: _tabs.putIfAbsent(
                                    widget.panels[i].id, GlobalKey.new),
                                child: ChoiceChip(
                                    key: ValueKey(
                                        'class-panel-tab-${widget.panels[i].id}'),
                                    selected: i == current,
                                    showCheckmark: false,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    label: Text(
                                        '${widget.panels[i].name} · ${l.levelShort} ${widget.panels[i].level}'),
                                    labelStyle: theme.textTheme.labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    selectedColor: colors.secondaryContainer,
                                    side: BorderSide.none,
                                    onSelected: (_) => _select(i)))),
                    ]))),
            const SizedBox(width: 8),
            Semantics(
                liveRegion: true,
                label: ru
                    ? 'Класс ${current + 1} из ${widget.panels.length}'
                    : 'Class ${current + 1} of ${widget.panels.length}',
                excludeSemantics: true,
                child: Text('${current + 1} / ${widget.panels.length}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.onSurfaceVariant))),
          ])),
      AnimatedContainer(
          height: _height,
          duration: reduced || _paging
              ? Duration.zero
              : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: NotificationListener<ScrollNotification>(
            onNotification: _scrolling,
            child: PageView(
                controller: _pager,
                key: const ValueKey('class-panel-carousel'),
                allowImplicitScrolling: true,
                onPageChanged: (index) {
                  if (_reconciling) return;
                  final id = widget.panels[index].id;
                  if (_selected == id) return;
                  HapticFeedback.selectionClick();
                  setState(() => _selected = id);
                  _revealTab();
                },
                children: [
                  for (var i = 0; i < widget.panels.length; i++)
                    _KeepPanel(
                        key: ValueKey(widget.panels[i].id),
                        child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: Offstage(
                                key: ValueKey(
                                    'class-panel-body-${widget.panels[i].id}'),
                                offstage: !_paging
                                    ? i != current
                                    : (i - _page).abs() > 1.01,
                                child: _SizeObserver(
                                    onSize: (size) =>
                                        _measure(widget.panels[i].id, size),
                                    child: ExcludeSemantics(
                                        excluding: i != current,
                                        child: IgnorePointer(
                                            ignoring: i != current,
                                            child: TickerMode(
                                                enabled: i == current,
                                                child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                            4, 0, 4, 6),
                                                    child: Transform.scale(
                                                        alignment:
                                                            Alignment.topCenter,
                                                        scale: reduced
                                                            ? 1
                                                            : 1 -
                                                                .015 *
                                                                    (i - _page).abs().clamp(0, 1),
                                                        child: widget.panels[i].child))))))))),
                ]),
          )),
    ]);
  }
}

class _KeepPanel extends StatefulWidget {
  const _KeepPanel({super.key, required this.child});
  final Widget child;
  @override
  State<_KeepPanel> createState() => _KeepPanelState();
}

class _KeepPanelState extends State<_KeepPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SizeObserver extends SingleChildRenderObjectWidget {
  const _SizeObserver({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReporter(onSize);
  @override
  void updateRenderObject(
      BuildContext context, covariant _SizeReporter renderObject) {
    renderObject.onSize = onSize;
  }
}

class _SizeReporter extends RenderProxyBox {
  _SizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? _previous;
  @override
  void performLayout() {
    super.performLayout();
    if (_previous == size) return;
    _previous = size;
    final measured = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(measured);
    });
  }
}

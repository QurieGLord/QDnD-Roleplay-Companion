import '../../core/ui/companion_motion.dart';
import 'package:flutter/material.dart';
import '../../core/ui/companion_surface.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../shared/widgets/dice_roller_modal.dart';
import 'widgets/expandable_character_card.dart';
import 'widgets/character_header_reveal.dart';
import 'widgets/overview_tab.dart';
import 'widgets/stats_tab.dart';
import 'widgets/abilities_tab.dart';
import 'tabs/inventory_tab.dart';
import 'tabs/journal_tab.dart';
import '../inventory/inventory_add_sheet.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class CharacterSheetScreen extends StatefulWidget {
  final Character character;

  const CharacterSheetScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterSheetScreen> createState() => _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends State<CharacterSheetScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  final _nestedScrollKey = GlobalKey<NestedScrollViewState>();
  int _scrollResetGeneration = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isCardExpanded = false;
  double? _dragStartY;
  int? _tapTarget;
  late final AnimationController _headerReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
      value: 1);
  late final CurvedAnimation _headerCurve = CurvedAnimation(
      parent: _headerReveal,
      curve: AppMotion.standard,
      reverseCurve: Curves.easeInOutCubic);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _headerCurve.dispose();
    _headerReveal.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    final inner =
        _nestedScrollKey.currentState?.innerController.positions.toList() ??
            <ScrollPosition>[];
    if (_scrollController.positions
            .every((p) => (p.pixels - p.minScrollExtent).abs() < 1) &&
        inner.every((p) => (p.pixels - p.minScrollExtent).abs() < 1)) {
      return;
    }
    // The NestedScrollView coordinator resets both the header and attached bodies.
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 260),
          curve: AppMotion.standard);
    }
  }

  void _scheduleTop(int index) {
    final generation = ++_scrollResetGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _currentIndex == index &&
          generation == _scrollResetGeneration) {
        _scrollToTop();
      }
    });
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _isCardExpanded = false;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _headerReveal.value = index == 0 ? 1 : 0;
    } else if (index == 0) {
      _headerReveal.forward();
    } else {
      _headerReveal.reverse();
    }
    _scheduleTop(index);
  }

  void _onTabChanged(int index) {
    if (_currentIndex == index) return;
    _tapTarget = index;
    _selectTab(index);
    final distance =
        ((_pageController.hasClients ? _pageController.page : null) ??
                    _currentIndex)
                .toDouble() -
            index;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
      return;
    }
    final milliseconds = 320 + 90 * (distance.abs() - 1).clamp(0, 3);
    _pageController
        .animateToPage(index,
            duration: Duration(milliseconds: milliseconds.round()),
            curve: Curves.easeInOutSine)
        .whenComplete(() {
      if (mounted &&
          _tapTarget == index &&
          (_pageController.page ?? -1).round() == index) {
        _tapTarget = null;
      }
    });
  }

  void _onPageChanged(int index) {
    if (_tapTarget != null) {
      if (_tapTarget == index) {
        _tapTarget = null;
        _scheduleTop(index);
      }
      return;
    }
    if (_currentIndex != index) _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: NestedScrollView(
          key: _nestedScrollKey,
          controller: _scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              // 1. Character Card
              SliverToBoxAdapter(
                child: CharacterHeaderReveal(
                  key: const ValueKey('character-header-reveal'),
                  sizeFactor: _headerCurve,
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) =>
                            _dragStartY = event.position.dy,
                        onPointerUp: (_) => _dragStartY = null,
                        onPointerMove: (event) {
                          if (_dragStartY == null) return;
                          final delta = event.position.dy - _dragStartY!;

                          // Swipe Down -> Expand
                          if (delta > 28 && !_isCardExpanded) {
                            setState(() {
                              _isCardExpanded = true;
                              _dragStartY = null;
                            });
                          }
                          // Swipe Up -> Collapse
                          else if (delta < -28 && _isCardExpanded) {
                            setState(() {
                              _isCardExpanded = false;
                              _dragStartY = null;
                            });
                          }
                        },
                        child: AnimatedBuilder(
                            animation: _scrollController,
                            builder: (context, _) => ExpandableCharacterCard(
                                  scrollProgress: _scrollController.hasClients
                                      ? (_scrollController
                                                  .positions.first.pixels /
                                              140)
                                          .clamp(0.0, 1.0)
                                      : 0,
                                  character: widget.character,
                                  onCharacterUpdated: () => setState(() {}),
                                  isExpanded: _isCardExpanded,
                                  onDicePressed: () {
                                    showDiceRoller(
                                      context,
                                      title: AppLocalizations.of(context)!
                                          .rollDie(20),
                                      modifier: 0,
                                    );
                                  },
                                  onDetailsToggled: (val) {
                                    setState(() => _isCardExpanded = val);
                                  },
                                )),
                      )),
                ),
              ),
              // 2. Sticky Navigation Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyNavBarDelegate(
                  child: _buildNavBar(),
                  height: 80,
                ),
              ),
            ];
          },
          body: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              CompanionEntrance(
                  active: _currentIndex == 0,
                  child: OverviewTab(
                      character: widget.character,
                      onCharacterUpdated: () => setState(() {}))),
              StatsTab(character: widget.character),
              CompanionEntrance(
                  active: _currentIndex == 2,
                  child: AbilitiesTab(
                      character: widget.character,
                      isActive: _currentIndex == 2)),
              CompanionEntrance(
                  active: _currentIndex == 3,
                  child: InventoryTab(
                      character: widget.character,
                      showAddButton: false,
                      onCharacterUpdated: () => setState(() {}))),
              CompanionEntrance(
                  active: _currentIndex == 4,
                  child: JournalTab(character: widget.character)),
            ],
          ),
        ),
      ),
      floatingActionButtonAnimator: MediaQuery.disableAnimationsOf(context)
          ? FloatingActionButtonAnimator.noAnimation
          : FloatingActionButtonAnimator.scaling,
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton(
              key: const ValueKey('sheet-add-item'),
              tooltip: AppLocalizations.of(context)!.addItem,
              onPressed: () => _showAddItemDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildNavBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            colorScheme.surface.withValues(alpha: 0),
            colorScheme.surface,
            colorScheme.surface
          ],
              stops: const [
            0,
            .30,
            1
          ])),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CompanionNavigationGlass(
        child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home),
                _buildNavItem(1, Icons.analytics_outlined, Icons.analytics),
                _buildNavItem(
                    2, Icons.auto_fix_high_outlined, Icons.auto_fix_high),
                _buildNavItem(3, Icons.backpack_outlined, Icons.backpack),
                _buildNavItem(4, Icons.book_outlined, Icons.book),
              ],
            )),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    final l = AppLocalizations.of(context)!;
    final labels = [
      l.sheetTabOverview,
      l.stats,
      l.magic,
      l.inventory,
      l.sheetTabJournal
    ];
    return Expanded(
      child: Semantics(
          label: labels[index],
          selected: isSelected,
          button: true,
          excludeSemantics: true,
          onTap: () => _onTabChanged(index),
          child: InkWell(
            key: ValueKey('sheet-tab-$index'),
            onTap: () => _onTabChanged(index),
            borderRadius: BorderRadius.circular(AppRadii.xlPlus),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                  size: 26,
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSecondaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          )),
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    if (await showInventoryAddSheet(context, widget.character) == true &&
        mounted) {
      setState(() {});
    }
  }
}

class _StickyNavBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyNavBarDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _StickyNavBarDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

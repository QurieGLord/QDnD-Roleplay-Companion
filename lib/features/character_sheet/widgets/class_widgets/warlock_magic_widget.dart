import '../../../../shared/widgets/subclass_details_sheet.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../spell_slots_widget.dart';
import 'shared/class_panel_presentation.dart';
import '../../../../core/progression/character_class_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class WarlockMagicWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? patron; // Can be null if using subclass string
  final CharacterFeature? pactBoon;
  final List<CharacterFeature> invocations;
  final VoidCallback? onChanged;

  const WarlockMagicWidget({
    super.key,
    required this.character,
    this.patron,
    this.pactBoon,
    this.invocations = const [],
    this.onChanged,
  });

  @override
  State<WarlockMagicWidget> createState() => _WarlockMagicWidgetState();
}

class _WarlockMagicWidgetState extends State<WarlockMagicWidget> {
  bool _isInvocationsExpanded = false;
  bool _usingInvocation = false;
  bool _changingBoon = false;
  Future<void> _changeBoon(CharacterFeature feature, int delta) async {
    if (_changingBoon) return;
    setState(() => _changingBoon = true);
    try {
      await GameplayActionsService.changeResource(
          widget.character, feature, delta);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _changingBoon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    // --- PALETTE MAPPING ---
    final warlockColor =
        colorScheme.secondary; // Deep purple/indigo for Warlock
    final blockBg = colorScheme.surfaceContainerLow;

    // 1. Determine Patron
    final patronName = _getPatronName(locale);

    // 2. Determine Pact Boon
    final boonFeature = _findPactBoon();

    final ownedInvocations = widget.invocations
        .where(CharacterClassContext(widget.character, 'warlock').canUseFeature)
        .toList();
    // 3. Filter Invocations
    // Remove passive/text types AND the base "Eldritch Invocations" feature itself
    final activeInvocations =
        ownedInvocations.where((i) => i.type != FeatureType.passive).toList();
    final passiveInvocations = ownedInvocations.where((i) {
      return i.type == FeatureType.passive &&
          !i.nameEn.toLowerCase().contains('eldritch invocations') &&
          !i.nameRu.toLowerCase().contains('таинственные воззвания');
    }).toList();

    return ClassPanelFrame(
        character: widget.character,
        classId: 'warlock',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            if (patronName.isNotEmpty)
              ListTile(
                  dense: true,
                  minTileHeight: 40,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(patronName,
                      style: TextStyle(color: colorScheme.secondary)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showPatronDetails),
            if (widget.character.classes
                        .where((entry) => entry.level > 0)
                        .length ==
                    1 &&
                (widget.character.maxSpellSlots.any((n) => n > 0) ||
                    widget.character.spellSlots.any((n) => n > 0) ||
                    widget.character.magicData.isNotEmpty))
              ClassPrimaryControl(
                  key: const ValueKey('warlock-pact-panel'),
                  classId: 'warlock',
                  title: locale == 'ru' ? 'Магия договора' : 'Pact Magic',
                  tone: colorScheme.tertiaryContainer,
                  footer: AppLocalizations.of(context)!.shortRest,
                  child: SpellSlotsWidget(
                      character: widget.character,
                      showArcanum: false,
                      prominent: true,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged?.call();
                      })),

            if (widget.character.classLevel('warlock') >= 11)
              ClassPrimaryControl(
                  key: const ValueKey('warlock-arcanum-panel'),
                  classId: 'warlock',
                  title: AppLocalizations.of(context)!.sheetArcanum,
                  tone: colorScheme.primaryContainer,
                  footer: AppLocalizations.of(context)!.longRest,
                  child: SpellSlotsWidget(
                      character: widget.character,
                      showSlots: false,
                      prominent: true,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged?.call();
                      })),

            // --- BLOCK 2: PACT BOON ---
            if (boonFeature != null &&
                widget.character.classLevel('warlock') >= 3)
              _buildBlockContainer(
                color: blockBg,
                onTap: () => _showDetails(boonFeature),
                padding: const EdgeInsets.all(12),
                child: _buildPactBoonContent(
                    context, colorScheme, warlockColor, boonFeature),
              ),

            // --- BLOCK 3: ELDRITCH INVOCATIONS ---
            if (widget.invocations.isNotEmpty ||
                widget.character.classLevel('warlock') >= 2)
              _buildInvocationsBlock(colorScheme, warlockColor,
                  activeInvocations, passiveInvocations, locale),
          ],
        ));
  }

  String _getPatronName(String locale) {
    // STRICTLY use subclass field. No feature parsing.
    final sub = CharacterClassContext(widget.character, 'warlock').subclass;

    if (sub == null || sub.isEmpty) {
      return locale == 'ru'
          ? 'Потусторонний Покровитель'
          : 'Otherworldly Patron';
    }

    // Localization Map
    final Map<String, String> ruMap = {
      'fiend': 'Бестия',
      'the fiend': 'Бестия',
      'archfey': 'Архифея',
      'the archfey': 'Архифея',
      'great old one': 'Великий Древний',
      'the great old one': 'Великий Древний',
      'hexblade': 'Ведьмовской Клинок',
      'the hexblade': 'Ведьмовской Клинок',
      'celestial': 'Небожитель',
      'the celestial': 'Небожитель',
      'genie': 'Джинн',
      'the genie': 'Джинн',
      'fathomless': 'Глубинный',
      'the fathomless': 'Глубинный',
      'undead': 'Нежить',
      'the undead': 'Нежить',
    };

    if (locale == 'ru') {
      return ruMap[sub.toLowerCase()] ?? sub;
    }

    return sub;
  }

  CharacterFeature? _findPactBoon() {
    // 1. Try to find a SPECIFIC pact boon in features (e.g. "Pact of the Blade")
    try {
      final specific = widget.character.features.firstWhere((f) {
        if (!CharacterClassContext(widget.character, 'warlock')
            .canUseFeature(f)) {
          return false;
        }
        final name = (f.nameEn).toLowerCase();
        return name.contains('pact of the') &&
            !name.contains('feature') &&
            !name.contains('boon');
      });
      return specific;
    } catch (_) {}

    // 2. Fallback to passed widget.pactBoon (likely generic)
    if (widget.pactBoon != null &&
        CharacterClassContext(widget.character, 'warlock')
            .canUseFeature(widget.pactBoon!)) {
      return widget.pactBoon;
    }

    // 3. Last ditch: any feature with "Pact"
    try {
      return widget.character.features.firstWhere((f) {
        if (!CharacterClassContext(widget.character, 'warlock')
            .canUseFeature(f)) {
          return false;
        }
        final name = (f.nameEn).toLowerCase();
        return name.contains('pact boon') || name.contains('предмет договора');
      });
    } catch (_) {
      return null;
    }
  }

  Widget _buildBlockContainer({
    required Color color,
    required Widget child,
    required EdgeInsetsGeometry padding,
    VoidCallback? onTap,
  }) {
    return CompanionSurface(
        quiet: true,
        color: color,
        padding: padding,
        onTap: onTap,
        child: child);
  }

  Future<void> _showPatronDetails() async {
    await showClassSubclassDetails(context, widget.character, 'warlock');
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildPactBoonContent(BuildContext context, ColorScheme colorScheme,
      Color warlockColor, CharacterFeature boon) {
    final locale = Localizations.localeOf(context).languageCode;
    final featureName = boon.getName(locale);
    final pool = boon.resourcePool;

    // Icon logic
    IconData icon = Icons.card_giftcard;
    final lower = featureName.toLowerCase();
    if (lower.contains('blade') || lower.contains('клинка')) {
      icon = Icons.shield;
    }
    if (lower.contains('chain') || lower.contains('цепи')) icon = Icons.link;
    if (lower.contains('tome') || lower.contains('гримуар')) {
      icon = Icons.menu_book;
    }
    if (lower.contains('talisman') || lower.contains('талисман')) {
      icon = Icons.workspace_premium;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: warlockColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locale == 'ru' ? "ПРЕДМЕТ ДОГОВОРА" : "PACT BOON",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    featureName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline,
                size: 18, color: colorScheme.outline.withValues(alpha: 0.5)),
          ],
        ),

        // Resource Pool if exists (rare for base boons, but good for robustness)
        if (pool != null) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${pool.currentUses} / ${pool.maxUses}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: !_changingBoon && pool.currentUses > 0
                        ? () => _changeBoon(boon, -1)
                        : null,
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: !_changingBoon && pool.currentUses < pool.maxUses
                        ? () => _changeBoon(boon, 1)
                        : null,
                    icon: const Icon(Icons.add, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 3. ELDRITCH INVOCATIONS BLOCK
  // ===========================================================================
  Widget _buildInvocationsBlock(
      ColorScheme colorScheme,
      Color warlockColor,
      List<CharacterFeature> active,
      List<CharacterFeature> passive,
      String locale) {
    return CompanionSurface(
        contour: CompanionContour.seal,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
            initiallyExpanded: _isInvocationsExpanded,
            onExpansionChanged: (value) =>
                setState(() => _isInvocationsExpanded = value),
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            title: Text(locale == 'ru' ? 'Воззвания' : 'Invocations',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            leading: IconButton(
                tooltip: AppLocalizations.of(context)!.advancementDetails,
                onPressed: () => _showInvocationsInfo(context, locale),
                icon: const Icon(Icons.info_outline_rounded)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${active.length + passive.length}'),
              const SizedBox(width: 8),
              Icon(_isInvocationsExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded)
            ]),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final inv in active)
                _buildActiveInvocationTile(
                    inv, colorScheme, warlockColor, locale),
              for (final inv in passive)
                _buildPassiveInvocationTile(
                    inv, colorScheme, warlockColor, locale),
            ]));
  }

  Widget _buildActiveInvocationTile(CharacterFeature inv,
      ColorScheme colorScheme, Color warlockColor, String locale) {
    // Check if it has a cooldown/usage
    final pool = inv.resourcePool;
    final canUse = pool == null || pool.currentUses > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(inv),
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warlockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(Icons.bolt, size: 20, color: warlockColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.getName(locale),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                      if (pool != null)
                        Text(
                          "${pool.currentUses}/${pool.maxUses}",
                          style: TextStyle(
                              fontSize: 14, color: colorScheme.secondary),
                        ),
                    ],
                  ),
                ),
                if (pool != null)
                  IconButton.filledTonal(
                      tooltip: AppLocalizations.of(context)!.useAction,
                      onPressed: canUse && !_usingInvocation
                          ? () => _useInvocation(inv)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded))
                else
                  const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPassiveInvocationTile(CharacterFeature inv,
      ColorScheme colorScheme, Color warlockColor, String locale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        visualDensity: VisualDensity.compact,
        leading: Icon(Icons.psychology, size: 18, color: colorScheme.secondary),
        title: Text(
          inv.getName(locale),
          style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
        ),
        onTap: () => _showDetails(inv),
      ),
    );
  }

  Future<void> _useInvocation(CharacterFeature inv) async {
    if (_usingInvocation ||
        !CharacterClassContext(widget.character, 'warlock').canUseFeature(inv)) {
      return;
    }
    if (inv.resourcePool == null) {
      _showDetails(inv);
      return;
    }
    setState(() => _usingInvocation = true);
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      final spent =
          await GameplayActionsService.spendResource(widget.character, inv);
      if (mounted && spent) {
        HapticFeedback.mediumImpact();
        widget.onChanged?.call();
        AppSnackBar.success(
            context, l.gameStateResourceUsed(inv.getName(locale)));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _usingInvocation = false);
    }
  }

  void _showInvocationsInfo(BuildContext context, String locale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            locale == 'ru' ? 'Таинственные воззвания' : 'Eldritch Invocations'),
        content: Text(locale == 'ru'
            ? 'В ходе изучения оккультных знаний вы обнаружили таинственные воззвания, фрагменты запретных знаний, которые наделяют вас постоянной магической способностью.'
            : 'In your study of occult lore, you have unearthed eldritch invocations, fragments of forbidden knowledge that imbue you with an abiding magical ability.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }
}

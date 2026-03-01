import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    // --- PALETTE MAPPING ---
    const warlockColor = Colors.deepPurple; // Deep purple/indigo for Warlock
    final blockBg = colorScheme.surfaceContainerHighest;

    // 1. Determine Patron
    final patronName = _getPatronName(locale);

    // 2. Determine Pact Boon
    final boonFeature = _findPactBoon();

    // 3. Filter Invocations
    // Remove passive/text types AND the base "Eldritch Invocations" feature itself
    final activeInvocations =
        widget.invocations.where((i) => i.type != FeatureType.passive).toList();
    final passiveInvocations = widget.invocations.where((i) {
      return i.type == FeatureType.passive &&
          !i.nameEn.toLowerCase().contains('eldritch invocations') &&
          !i.nameRu.toLowerCase().contains('таинственные воззвания');
    }).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- BLOCK 1: OTHERWORLDLY PATRON ---
            if (patronName.isNotEmpty)
              _buildPatronBlock(
                  context, colorScheme, warlockColor, patronName, locale),

            if (patronName.isNotEmpty) const SizedBox(height: 12),

            // --- BLOCK 2: PACT BOON ---
            if (boonFeature != null) ...[
              _buildBlockContainer(
                color: blockBg,
                onTap: () => _showDetails(boonFeature),
                padding: const EdgeInsets.all(12),
                child: _buildPactBoonContent(
                    context, colorScheme, warlockColor, boonFeature),
              ),
              const SizedBox(height: 12),
            ],

            // --- BLOCK 3: ELDRITCH INVOCATIONS ---
            if (widget.invocations.isNotEmpty ||
                widget.character.level >= 2) ...[
              Container(
                decoration: BoxDecoration(
                  color: blockBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildInvocationsBlock(colorScheme, warlockColor,
                    activeInvocations, passiveInvocations, locale),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  String _getPatronName(String locale) {
    // STRICTLY use subclass field. No feature parsing.
    final sub = widget.character.subclass;

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
        final name = (f.nameEn).toLowerCase();
        return name.contains('pact of the') &&
            !name.contains('feature') &&
            !name.contains('boon');
      });
      return specific;
    } catch (_) {}

    // 2. Fallback to passed widget.pactBoon (likely generic)
    if (widget.pactBoon != null) return widget.pactBoon;

    // 3. Last ditch: any feature with "Pact"
    try {
      return widget.character.features.firstWhere((f) {
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. OTHERWORLDLY PATRON BLOCK
  // ===========================================================================
  Widget _buildPatronBlock(BuildContext context, ColorScheme colorScheme,
      Color warlockColor, String patronName, String locale) {
    final title = locale == 'ru' ? "ПОКРОВИТЕЛЬ" : "OTHERWORLDLY PATRON";

    // Dynamic Icon based on Patron Name
    IconData icon = Icons.auto_fix_high;
    final lowerName = patronName.toLowerCase();
    if (lowerName.contains('fiend') || lowerName.contains('бестия')) {
      icon = Icons.local_fire_department;
    } else if (lowerName.contains('archfey') || lowerName.contains('архифея')) {
      icon = Icons.forest;
    } else if (lowerName.contains('great old') ||
        lowerName.contains('великий древний')) {
      icon = Icons.psychology;
    } else if (lowerName.contains('celestial') ||
        lowerName.contains('небожитель')) {
      icon = Icons.wb_sunny;
    } else if (lowerName.contains('hexblade') ||
        lowerName.contains('ведьмовской')) {
      icon = Icons.gavel;
    } else if (lowerName.contains('fathomless') ||
        lowerName.contains('глубинный')) {
      icon = Icons.water_drop;
    } else if (lowerName.contains('genie') || lowerName.contains('джинн')) {
      icon = Icons.oil_barrel;
    } else if (lowerName.contains('undead') || lowerName.contains('нежить')) {
      icon = Icons.sentiment_very_dissatisfied;
    }

    return Container(
      decoration: BoxDecoration(
        color: warlockColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warlockColor.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 1. Try to find Subclass Data using CharacterDataService
            try {
              final classData = CharacterDataService.getClassById(
                  widget.character.characterClass);
              if (classData != null) {
                final subId = widget.character.subclass?.toLowerCase() ?? '';
                final subName = patronName.toLowerCase();

                final subclass = classData.subclasses.firstWhere(
                  (s) =>
                      s.id == subId ||
                      s.getName(locale).toLowerCase() == subName,
                );

                // Show detailed bottom sheet with lore
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (ctx) => DraggableScrollableSheet(
                    initialChildSize: 0.6,
                    minChildSize: 0.4,
                    maxChildSize: 0.9,
                    expand: false,
                    builder: (context, scrollController) {
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.shield,
                                      color: colorScheme.onSecondaryContainer),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    subclass.getName(locale),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              subclass.getDescription(locale),
                              style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
                return;
              }
            } catch (e) {
              debugPrint('Subclass description not found: $e');
            }

            // 2. Fallback: Generic Patron Feature
            if (widget.patron != null) {
              _showDetails(widget.patron!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  top: -15,
                  bottom: -15,
                  child: Icon(icon,
                      size: 80, color: warlockColor.withValues(alpha: 0.2)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: warlockColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patronName,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. PACT BOON BLOCK
  // ===========================================================================
  Widget _buildPactBoonContent(BuildContext context, ColorScheme colorScheme,
      Color warlockColor, CharacterFeature boon) {
    final locale = Localizations.localeOf(context).languageCode;
    final featureName = boon.getName(locale);
    final pool = boon.resourcePool;

    // Icon logic
    IconData icon = Icons.card_giftcard;
    final lower = featureName.toLowerCase();
    if (lower.contains('blade') || lower.contains('клинка')) {
      icon = Icons.shield_outlined;
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
                        fontSize: 10,
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
                    onPressed: pool.currentUses > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              pool.use(1);
                              widget.character.save();
                              widget.onChanged?.call();
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: pool.currentUses < pool.maxUses
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              pool.restore(1);
                              widget.character.save();
                              widget.onChanged?.call();
                            });
                          }
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
    final title =
        locale == 'ru' ? "ТАИНСТВЕННЫЕ ВОЗЗВАНИЯ" : "ELDRITCH INVOCATIONS";
    final pillColor =
        _isInvocationsExpanded ? warlockColor : colorScheme.surfaceDim;
    final pillContentColor =
        _isInvocationsExpanded ? Colors.white : colorScheme.onSurfaceVariant;
    final iconColor = _isInvocationsExpanded ? Colors.white : warlockColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Switch
        Material(
          color: pillColor,
          borderRadius: BorderRadius.circular(12), // Static radius
          child: InkWell(
            onTap: () {
              // Show info about Invocations if collapsed, or just toggle?
              // Requirement: "Make header clickable for info"
              // But we also have the switch.
              // Let's make the whole header toggle, but add an info button.
              // Actually, user said "Tap on header opens dialog".
              _showInvocationsInfo(context, locale);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: pillContentColor,
                      ),
                    ),
                  ),
                  // Toggle Switch
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _isInvocationsExpanded,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() => _isInvocationsExpanded = val);
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.3),
                      inactiveThumbColor: colorScheme.onSurfaceVariant,
                      inactiveTrackColor: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded List
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isInvocationsExpanded
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Active Invocations
                      if (active.isNotEmpty) ...[
                        _buildSectionLabel(
                            locale == 'ru' ? "АКТИВНЫЕ" : "ACTIVE",
                            colorScheme),
                        ...active.map((inv) => _buildActiveInvocationTile(
                            inv, colorScheme, warlockColor, locale)),
                        const SizedBox(height: 12),
                      ],

                      // Passive Invocations
                      if (passive.isNotEmpty) ...[
                        _buildSectionLabel(
                            locale == 'ru' ? "ПАССИВНЫЕ" : "PASSIVE",
                            colorScheme),
                        ...passive.map((inv) => _buildPassiveInvocationTile(
                            inv, colorScheme, warlockColor, locale)),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: colorScheme.secondary,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warlockColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(inv),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: warlockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                      if (pool != null)
                        Text(
                          "${pool.currentUses}/${pool.maxUses}",
                          style: TextStyle(
                              fontSize: 10, color: colorScheme.secondary),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 32,
                  child: FilledButton(
                    onPressed: canUse ? () => _useInvocation(inv) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: warlockColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.auto_fix_high, size: 18),
                  ),
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        visualDensity: VisualDensity.compact,
        leading: Icon(Icons.psychology, size: 18, color: colorScheme.secondary),
        title: Text(
          inv.getName(locale),
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        onTap: () => _showDetails(inv),
      ),
    );
  }

  void _useInvocation(CharacterFeature inv) {
    HapticFeedback.mediumImpact();
    // If it has a resource pool, spend it
    if (inv.resourcePool != null) {
      setState(() {
        inv.resourcePool!.use(1);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
    // Logic to just show a snackbar if it's an "at will" active ability without tracking
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${inv.getName(Localizations.localeOf(context).languageCode)} ${Localizations.localeOf(context).languageCode == 'ru' ? "активировано!" : "activated!"}'),
      backgroundColor: Colors.deepPurple,
      duration: const Duration(seconds: 1),
    ));
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
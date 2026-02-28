import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

class BardInspirationWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature inspirationFeature;
  final VoidCallback? onChanged;

  const BardInspirationWidget({
    super.key,
    required this.character,
    required this.inspirationFeature,
    this.onChanged,
  });

  @override
  State<BardInspirationWidget> createState() => _BardInspirationWidgetState();
}

class _BardInspirationWidgetState extends State<BardInspirationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  String _getInspirationDie(int level, String locale) {
    String die;
    if (level >= 15) {
      die = '1d12';
    } else if (level >= 10) {
      die = '1d10';
    } else if (level >= 5) {
      die = '1d8';
    } else {
      die = '1d6';
    }

    if (locale == 'ru') {
      return die.replaceAll('d', 'к');
    }
    return die;
  }

  void _useCharge(int amount) {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null) return;

    if (pool.currentUses >= amount) {
      setState(() {
        pool.use(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
    } else {
      final isRu = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRu ? 'Нет зарядов Вдохновения!' : 'No charges left!'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  void _restoreCharge(int amount) {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null) return;

    if (!pool.isFull) {
      setState(() {
        pool.restore(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
      _showFeedback(false, 0);
    }
  }

  void _toggleUsage() {
    final pool = widget.inspirationFeature.resourcePool;
    if (pool == null || pool.isEmpty) {
      final isRu = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRu ? 'Нет зарядов Вдохновения!' : 'No charges left!'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 1),
      ));
      return;
    }

    // Visual Juice
    HapticFeedback.mediumImpact();
    _rotationController.forward(from: 0.0);

    // 1. Determine die sides
    int sides = 6;
    if (widget.character.level >= 15) {
      sides = 12;
    } else if (widget.character.level >= 10) {
      sides = 10;
    } else if (widget.character.level >= 5) {
      sides = 8;
    }

    // 2. Roll
    final result = Random().nextInt(sides) + 1;

    // 3. Use charge
    _useCharge(1);

    // 4. Show Result
    _showFeedback(true, result);
  }

  void _showFeedback(bool used, int rollResult) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    String msg;
    if (used) {
      msg = isRu
          ? 'Вдохновение: $rollResult!'
          : 'Inspiration Result: $rollResult!';
    } else {
      msg = isRu ? 'Вдохновение восстановлено!' : 'Inspiration recovered!';
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  void _showFeatureDetails(CharacterFeature feature, IconData icon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
      ),
    );
  }

  void _showSubclassLore(BuildContext context) async {
    final subclassId = widget.character.subclass ?? '';
    if (subclassId.isEmpty) return;

    try {
      final subclassData = await CharacterDataService.getSubclass(
        widget.character.characterClass,
        subclassId,
      );

      if (subclassData == null || !context.mounted) return;

      final locale = Localizations.localeOf(context).languageCode;
      final name = subclassData.getName(locale);
      final desc = subclassData.getDescription(locale);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 24),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.music_note,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              name,
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
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        desc,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Error loading subclass lore: $e');
    }
  }

  void _executeQuickAction(CharacterFeature feature, String locale,
      {bool usesInspiration = false}) {
    HapticFeedback.heavyImpact();

    final usedText = locale == 'ru' ? 'использовано!' : 'used!';

    if (usesInspiration) {
      final pool = widget.inspirationFeature.resourcePool;
      if (pool != null && pool.currentUses > 0) {
        setState(() {
          pool.use(1);
          widget.character.save();
          widget.onChanged?.call();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locale == 'ru'
                ? 'Нет зарядов Вдохновения!'
                : 'No Inspiration charges left!'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return; // Early return, action not performed
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${feature.getName(locale)} $usedText'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildActionTile(CharacterFeature? feature, IconData fallBackIcon,
      String locale, ThemeData theme,
      {bool usesInspiration = false}) {
    if (feature == null) return const SizedBox.shrink();
    final cleanName =
        feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '');

    IconData icon = fallBackIcon;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFeatureDetails(feature, icon),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cleanName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (usesInspiration)
                  SizedBox(
                    width: 48,
                    height: 36,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: theme.colorScheme.tertiary,
                        foregroundColor: theme.colorScheme.onTertiary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _executeQuickAction(feature, locale,
                          usesInspiration: true),
                      child: const Icon(Icons.music_note, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.inspirationFeature.resourcePool;
    // Safety check
    if (pool == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final dieType = _getInspirationDie(widget.character.level, locale);

    final maxCharges = pool.maxUses > 0 ? pool.maxUses : 1;
    final currentCharges = pool.currentUses;

    // Subclass Info
    String subclassDisplayName = widget.character.subclass ?? '';
    final classData =
        CharacterDataService.getClassById(widget.character.characterClass);
    if (classData != null && subclassDisplayName.isNotEmpty) {
      final nid = subclassDisplayName.toLowerCase().trim();
      final targetSubclass = classData.subclasses
          .where((s) =>
              s.id == nid || s.name.values.any((v) => v.toLowerCase() == nid))
          .firstOrNull;
      if (targetSubclass != null) {
        subclassDisplayName = targetSubclass.getName(locale);
      }
    }

    // Quick Actions
    final cuttingWords = widget.character.features
        .where((f) =>
            f.id.toLowerCase().contains('cutting_word') ||
            f.id.toLowerCase().contains('cutting-word'))
        .firstOrNull;
    final combatInspiration = widget.character.features
        .where((f) =>
            f.id.toLowerCase().contains('combat_inspiration') ||
            f.id.toLowerCase().contains('combat-inspiration'))
        .firstOrNull;
    final countercharm = widget.character.features
        .where((f) => f.id.toLowerCase().contains('countercharm'))
        .firstOrNull;
    final songOfRest = widget.character.features
        .where((f) =>
            f.id.toLowerCase().contains('song_of_rest') ||
            f.id.toLowerCase().contains('song-of-rest'))
        .firstOrNull;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 24),
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subclass Block
            if ((widget.character.subclass ?? '').isNotEmpty) ...[
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showSubclassLore(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.music_note,
                                size: 18, color: colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locale == 'ru'
                                      ? 'Коллегия бардов'
                                      : 'Bard College',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  subclassDisplayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant
                                  .withOpacity(0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Inspiration Dashboard
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // Header: Icon, Title, and Badge
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        CharacterFeature? baseInspiration = FeatureService
                                .getFeatureById('bardic_inspiration') ??
                            FeatureService.getFeatureById('bardic-inspiration');

                        baseInspiration ??= CharacterFeature(
                          id: 'bardic_inspiration_base',
                          nameEn: 'Bardic Inspiration',
                          nameRu: 'Бардовское вдохновение',
                          descriptionEn:
                              'You can inspire others through stirring words or music. To do so, you use a bonus action on your turn to choose one creature other than yourself within 60 feet of you who can hear you. That creature gains one Bardic Inspiration die...',
                          descriptionRu:
                              'Бонусным действием вы можете выбрать одно существо, отличное от вас, в пределах 60 футов, которое вас слышит. Оно получает кость бардовского вдохновения. В течение следующих 10 минут это существо может бросить эту кость и добавить результат к одной проверке характеристики, броску атаки или спасброску...',
                          type: widget.inspirationFeature.type,
                          minLevel: 1,
                        );

                        _showFeatureDetails(baseInspiration, Icons.queue_music);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.queue_music,
                                color: colorScheme.onTertiary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.bardicInspiration,
                                    softWrap: true,
                                    maxLines: 2,
                                    overflow: TextOverflow.fade,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                          fontSize: 16,
                                          height: 1.15,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentCharges / $maxCharges',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Inspiration Die Badge
                            GestureDetector(
                              onTap: pool.isEmpty ? null : _toggleUsage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RotationTransition(
                                      turns: CurvedAnimation(
                                          parent: _rotationController,
                                          curve: Curves.easeOutBack),
                                      child: Icon(Icons.casino_outlined,
                                          size: 16,
                                          color:
                                              colorScheme.onSecondaryContainer),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dieType,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 16),

                  // The Notes (Resource Tracker)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 16.0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(maxCharges, (index) {
                        final isActive = index < currentCharges;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (isActive) {
                              _useCharge(1);
                              _showFeedback(true, 0);
                            } else {
                              _restoreCharge(1);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            transform: Matrix4.identity()
                              ..scale(isActive ? 1.0 : 0.8), // Pulse effect
                            child: Icon(
                              Icons.music_note,
                              size: 32,
                              color: isActive
                                  ? colorScheme.tertiary
                                  : colorScheme.onSurfaceVariant
                                      .withOpacity(0.3),
                              shadows: isActive
                                  ? [
                                      Shadow(
                                          color: colorScheme.tertiary
                                              .withOpacity(0.4),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Quick Actions Block
            if (cuttingWords != null ||
                combatInspiration != null ||
                countercharm != null ||
                songOfRest != null) ...[
              Padding(
                padding:
                    const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      locale == 'ru'
                          ? 'Виртуозное исполнение'
                          : 'Virtuoso Performance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              ...[
                if (cuttingWords != null)
                  _buildActionTile(cuttingWords, Icons.record_voice_over,
                      locale, Theme.of(context),
                      usesInspiration: true),
                if (combatInspiration != null)
                  _buildActionTile(combatInspiration, Icons.shield, locale,
                      Theme.of(context),
                      usesInspiration: true),
                if (countercharm != null)
                  _buildActionTile(countercharm, Icons.queue_music, locale,
                      Theme.of(context)),
                if (songOfRest != null)
                  _buildActionTile(
                      songOfRest, Icons.bedtime, locale, Theme.of(context)),
              ].expand((w) => [w, const SizedBox(height: 8)]).toList()
                ..removeLast(),
            ],
          ],
        ),
      ),
    );
  }
}

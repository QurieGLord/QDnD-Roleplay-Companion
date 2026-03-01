import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/services/character_data_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/dice_utils.dart';

class KiTrackerWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature kiFeature;
  final VoidCallback? onChanged;

  const KiTrackerWidget({
    super.key,
    required this.character,
    required this.kiFeature,
    this.onChanged,
  });

  @override
  State<KiTrackerWidget> createState() => _KiTrackerWidgetState();
}

class _KiTrackerWidgetState extends State<KiTrackerWidget> {
  int _calculateMaxKi() {
    int monkLevel = 0;
    if (widget.character.classes.isNotEmpty) {
      for (var cls in widget.character.classes) {
        if (cls.id.toLowerCase().contains('monk') ||
            cls.name.toLowerCase().contains('monk')) {
          monkLevel = cls.level;
          break;
        }
      }
    }
    if (monkLevel == 0) {
      if (widget.character.characterClass.toLowerCase().contains('monk')) {
        monkLevel = widget.character.level;
      } else if (widget.character.classes.length == 1) {
        monkLevel = widget.character.level;
      }
    }
    if (monkLevel <= 1 && widget.character.level > 1) {
      monkLevel = widget.character.level;
    }
    if (monkLevel == 0) monkLevel = 1;
    return monkLevel;
  }

  int _getMartialArtsDie(int level) {
    if (level >= 17) return 10;
    if (level >= 11) return 8;
    if (level >= 5) return 6;
    return 4;
  }

  CharacterFeature? _findFeature(List<String> keywords) {
    for (final k in keywords) {
      final match = widget.character.features.where((f) {
        final id = f.id.toLowerCase();
        final name = f.nameEn.toLowerCase();
        return id.contains(k) || name.contains(k);
      }).firstOrNull;
      if (match != null) return match;
    }
    return null;
  }

  void _showFeatureDetails(CharacterFeature feature, [IconData? overrideIcon]) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(
        feature: feature,
        overrideIcon: overrideIcon,
      ),
    );
  }

  void _restoreKi(int maxKi, [int amount = 1]) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return;
    if (pool.maxUses != maxKi) pool.maxUses = maxKi;
    if (!pool.isFull) {
      HapticFeedback.selectionClick();
      setState(() {
        pool.restore(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
  }

  void _spendKi(int maxKi, [int amount = 1]) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return;
    if (pool.maxUses != maxKi) pool.maxUses = maxKi;
    if (pool.currentUses >= amount) {
      HapticFeedback.lightImpact();
      setState(() {
        pool.use(amount);
        widget.character.save();
        widget.onChanged?.call();
      });
    }
  }

  void _showKiInputDialog(int maxKi, int currentKi) {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(text: currentKi.toString());
    final locale = Localizations.localeOf(context).languageCode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale == 'ru' ? 'Изменить Ци' : 'Edit Ki'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Current Ki (Max: $maxKi)',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final newVal = int.tryParse(val);
            if (newVal != null) {
              setState(() {
                widget.kiFeature.resourcePool?.currentUses =
                    newVal.clamp(0, maxKi);
                widget.character.save();
                widget.onChanged?.call();
              });
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale == 'ru' ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newVal = int.tryParse(controller.text);
              if (newVal != null) {
                setState(() {
                  widget.kiFeature.resourcePool?.currentUses =
                      newVal.clamp(0, maxKi);
                  widget.character.save();
                  widget.onChanged?.call();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _executeQuickAction(
      CharacterFeature actionFeature, int maxKi, String locale) {
    final pool = widget.kiFeature.resourcePool;
    if (pool == null || pool.currentUses < 1) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(locale == 'ru' ? 'Недостаточно Ци!' : 'Not enough Ki!'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 1),
      ));
      return;
    }

    HapticFeedback.heavyImpact();
    _spendKi(maxKi, 1);

    final cleanName =
        actionFeature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$cleanName ${locale == 'ru' ? 'использовано! (-1 Ци)' : 'used! (-1 Ki)'}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final pool = widget.kiFeature.resourcePool;
    if (pool == null) return const SizedBox.shrink();

    final maxKi = _calculateMaxKi();
    final dieSize = _getMartialArtsDie(maxKi);

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.character.subclass != null &&
                widget.character.subclass!.isNotEmpty) ...[
              _buildArchetypeBlock(context, colorScheme, locale, l10n),
              const SizedBox(height: 12),
            ],
            _buildBasicStatsPanel(context, colorScheme, locale, l10n, dieSize),
            const SizedBox(height: 12),
            _buildKiDashboard(
                context, colorScheme, locale, pool.currentUses, maxKi),
            const SizedBox(height: 12),
            _buildQuickActions(context, colorScheme, locale, maxKi),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuart);
  }

  Widget _buildArchetypeBlock(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n) {
    final classData =
        CharacterDataService.getClassById(widget.character.characterClass);
    SubclassData? subclassData;

    if (classData != null && widget.character.subclass != null) {
      try {
        subclassData = classData.subclasses.firstWhere((s) {
          return s.name.values.any((val) => val == widget.character.subclass) ||
              s.id ==
                  widget.character.subclass!.toLowerCase().replaceAll(' ', '_');
        });
      } catch (_) {}
    }

    final fallbackName = widget.character.subclass ?? '';
    final subclassName = subclassData?.getName(locale) ?? fallbackName;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            final description =
                subclassData?.getDescription(locale) ?? l10n.noFeaturesAtLevel1;
            showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      minChildSize: 0.4,
                      maxChildSize: 0.9,
                      expand: false,
                      builder: (context, scrollController) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                        child: ListView(
                          controller: scrollController,
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: colorScheme.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Row(children: [
                              Icon(Icons.temple_buddhist,
                                  color: colorScheme.primary, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subclassName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.temple_buddhist,
                    color: colorScheme.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale == 'ru'
                            ? 'МОНАСТЫРСКАЯ ТРАДИЦИЯ'
                            : 'MONASTIC TRADITION',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        subclassName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onSurface,
                                ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicStatsPanel(BuildContext context, ColorScheme colorScheme,
      String locale, AppLocalizations l10n, int dieSize) {
    final martialArtsFeature =
        _findFeature(['martial_arts', 'martial-arts', 'боевые искусства']);
    final unarmoredFeature = _findFeature(
        ['unarmored_movement', 'unarmored-movement', 'движение без доспехов']);

    return Row(
      children: [
        // Martial Arts
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (martialArtsFeature != null) {
                    _showFeatureDetails(
                        martialArtsFeature, Icons.sports_martial_arts);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.casino_outlined,
                              size: 18, color: colorScheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              locale == 'ru'
                                  ? 'Боевые искусства'
                                  : 'Martial Arts',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DiceUtils.formatDice('1d$dieSize', context),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Unarmored Movement
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (unarmoredFeature != null) {
                    _showFeatureDetails(unarmoredFeature, Icons.directions_run);
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_run,
                              size: 18, color: colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              unarmoredFeature?.getName(locale) ??
                                  (locale == 'ru' ? 'Движение' : 'Movement'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '+10 ft.', // Ideally we'd calculate this based on monk level, but placeholder is fine or we can extract from feature if possible.
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKiDashboard(BuildContext context, ColorScheme colorScheme,
      String locale, int currentKi, int maxKi) {
    final progress = maxKi > 0 ? currentKi / maxKi : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            locale == 'ru' ? 'ЭНЕРГИЯ ЦИ' : 'KI POINTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: currentKi <= 0 ? null : () => _spendKi(maxKi, 1),
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size(48, 48),
                ),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => _showKiInputDialog(maxKi, currentKi),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutQuart,
                          builder: (context, value, _) {
                            return CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12,
                              backgroundColor: colorScheme.surfaceContainerHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary),
                              strokeCap: StrokeCap.round,
                            );
                          },
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$currentKi',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onSurface,
                                  height: 1.0,
                                ),
                          ),
                          Text(
                            '/ $maxKi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                onPressed:
                    currentKi >= maxKi ? null : () => _restoreKi(maxKi, 1),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  foregroundColor: colorScheme.primary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, ColorScheme colorScheme, String locale, int maxKi) {
    final flurry =
        _findFeature(['flurry_of_blows', 'flurry-of-blows', 'шквал ударов']);
    final patientDefense = _findFeature(
        ['patient_defense', 'patient-defense', 'терпеливая оборона']);
    final stepWind =
        _findFeature(['step_of_the_wind', 'step-of-the-wind', 'поступь ветра']);
    final stunningStrike =
        _findFeature(['stunning_strike', 'stunning-strike', 'оглушающий удар']);

    final List<Widget> actionChips = [];

    IconData getFeatureIcon(String? id, String? name) {
      final nid = (id ?? '').toLowerCase();
      final nname = (name ?? '').toLowerCase();
      if (nid.contains('flurry') || nname.contains('шквал')) {
        return Icons.sports_martial_arts;
      }
      if (nid.contains('defense') || nname.contains('оборона')) {
        return Icons.shield;
      }
      if (nid.contains('step') ||
          nname.contains('поступь') ||
          nid.contains('wind') ||
          nname.contains('ветер')) {
        return Icons.air;
      }
      if (nid.contains('stunning') || nname.contains('оглушающий')) {
        return Icons.flash_on;
      }
      if (nid.contains('patient') || nname.contains('терпеливая')) {
        return Icons.health_and_safety;
      }
      return Icons.bolt;
    }

    Widget buildActionTile(CharacterFeature? feature) {
      if (feature == null) return const SizedBox.shrink();
      final cleanName =
          feature.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), '');
      final icon = getFeatureIcon(feature.id, feature.nameEn);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showFeatureDetails(feature, icon),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cleanName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () =>
                            _executeQuickAction(feature, maxKi, locale),
                        child: const Icon(Icons.back_hand, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (flurry != null) actionChips.add(buildActionTile(flurry));
    if (patientDefense != null) {
      actionChips.add(buildActionTile(patientDefense));
    }
    if (stepWind != null) actionChips.add(buildActionTile(stepWind));
    if (stunningStrike != null) {
      actionChips.add(buildActionTile(stunningStrike));
    }

    if (actionChips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                locale == 'ru'
                    ? 'Быстрые действия (1 Ци)'
                    : 'Quick Actions (1 Ki)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: actionChips,
          ),
        ],
      ),
    );
  }
}

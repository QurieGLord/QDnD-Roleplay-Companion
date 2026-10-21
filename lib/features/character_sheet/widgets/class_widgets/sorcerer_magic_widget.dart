import '../../../../core/magic/magic_slots.dart';
import '../../../../core/ui/companion_surface.dart';
import 'shared/class_panel_presentation.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/services/sorcery_actions_service.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';
import 'shared/class_tools_layout_builder.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SorcererMagicWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? sorceryPoints;
  final List<CharacterFeature> metamagic;
  final List<CharacterFeature> ancestryFeatures;
  final VoidCallback? onChanged;

  const SorcererMagicWidget({
    super.key,
    required this.character,
    this.sorceryPoints,
    required this.metamagic,
    required this.ancestryFeatures,
    this.onChanged,
  });

  @override
  State<SorcererMagicWidget> createState() => _SorcererMagicWidgetState();
}

class _SorcererMagicWidgetState extends State<SorcererMagicWidget> {
  // Локальные состояния
  bool _isCreateSlotMode = true; // Режим: true = Создать, false = Поглотить
  bool _isMetamagicExpanded = false;
  bool _resourceBusy = false; // Раскрыт ли список метамагии

  // Стоимость создания ячеек (1-5 уровень)
  final Map<int, int> _creationCosts = {1: 2, 2: 3, 3: 5, 4: 6, 5: 7};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;

    // --- PALETTE MAPPING (Как у Паладина) ---
    final orangeAccent = colorScheme.primary;
    final beigeAccent = colorScheme.secondary;
    final onBeige = colorScheme.onSecondary;
    final blockBg = colorScheme.surfaceContainerLow;

    // 1. Извлекаем данные Дракона
    final dragonInfo = _getDragonInfo(locale);

    // 2. Извлекаем Метамагию (Базовая инфо-абилка + сами опции)
    final baseMetamagic = widget.metamagic.firstWhere(
      (f) =>
          f.nameEn.toLowerCase() == 'metamagic' ||
          f.nameRu.toLowerCase() == 'метамагия',
      orElse: () => CharacterFeature(
        id: 'base_meta',
        nameEn: 'Metamagic',
        nameRu: 'Метамагия',
        descriptionEn: 'You can twist your spells to suit your needs.',
        descriptionRu: 'Вы можете изменять свои заклинания.',
        type: FeatureType.passive,
        minLevel: 3,
      ),
    );
    final metamagicOptions =
        widget.metamagic.where((f) => f.id != baseMetamagic.id).toList();

    return ClassPanelFrame(
        character: widget.character,
        classId: 'sorcerer',
        child: ClassToolsLayoutBuilder(
          padding: EdgeInsets.zero,
          children: [
            ClassSubclassLink(character: widget.character, classId: 'sorcerer'),
            // --- BLOCK 1: DRACONIC ANCESTRY ---
            if (widget.ancestryFeatures.isNotEmpty)
              _buildAncestryBlock(dragonInfo, blockBg),

            if (widget.character.classLevel('sorcerer') >= 2)
              _buildFontOfMagicBlock(
                  colorScheme, orangeAccent, beigeAccent, onBeige, locale),

            // --- BLOCK 3: METAMAGIC ---
            if (widget.character.classLevel('sorcerer') >= 3)
              CompanionSurface(
                  color: blockBg,
                  quiet: true,
                  padding: EdgeInsets.zero,
                  child: _buildMetamagicBlock(baseMetamagic, metamagicOptions,
                      colorScheme, beigeAccent, onBeige, orangeAccent, locale)),
          ],
        ));
  }

  Widget _buildAncestryBlock(_DragonData info, Color blockBg) {
    final c = Theme.of(context).colorScheme;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return CompanionSurface(
        contour: CompanionContour.focus,
        color: c.tertiaryContainer,
        padding: const EdgeInsets.all(16),
        onTap: () =>
            _showDetails(info.matchedFeature ?? widget.ancestryFeatures.first),
        child: Row(children: [
          Icon(info.icon, color: c.tertiary, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(ru ? 'Драконье наследие' : 'Draconic Ancestry',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(info.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ])),
          const Icon(Icons.chevron_right_rounded),
        ]));
  }

  /// Вспомогательный метод для получения актуального пула из состояния персонажа.
  /// Это критично для реактивности UI. ГАРАНТИРУЕТ возврат объекта и его персистентность.
  ResourcePool _getActualPool() => SorceryActionsService.view(widget.character,
      definition: widget.sorceryPoints);

  Future<bool> _applyResource(Future<bool> Function() action) async {
    if (_resourceBusy) return false;
    _resourceBusy = true;
    try {
      final applied = await action();
      if (mounted) {
        setState(() {});
        widget.onChanged?.call();
      }
      return applied;
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            Localizations.localeOf(context).languageCode == 'ru'
                ? 'Не удалось сохранить действие. Значения не изменены.'
                : 'Could not save the action. Values are unchanged.');
      }
      return false;
    } finally {
      _resourceBusy = false;
    }
  }

  Widget _buildFontOfMagicBlock(ColorScheme colorScheme, Color barColor,
      Color btnColor, Color onBtnColor, String locale) {
    // Реактивное получение пула. Метод теперь гарантирует связь с базой.
    final pool = _getActualPool();

    final max = pool.maxUses;
    final current = pool.currentUses;
    return ClassPrimaryControl(
        classId: 'sorcerer',
        title: locale == 'ru' ? 'Очки чародейства' : 'Sorcery points',
        current: current,
        maximum: max,
        marks: true,
        onEdit: () => _showCustomSPDialog(pool, locale),
        tone: colorScheme.primaryContainer,
        footer: locale == 'ru'
            ? 'Стоимость указана под кругом'
            : 'The cost is shown below each spell level',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Переключатель режимов (Создать / Сжечь)
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true,
                    label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child:
                            Text(locale == 'ru' ? "В ячейку" : "Create Slot")),
                    icon: const Icon(Icons.add_circle_outline)),
                ButtonSegment(
                    value: false,
                    label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(locale == 'ru' ? "В очки" : "To Points")),
                    icon: const Icon(Icons.local_fire_department_outlined)),
              ],
              selected: {_isCreateSlotMode},
              onSelectionChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _isCreateSlotMode = val.first);
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                selectedForegroundColor: onBtnColor,
                selectedBackgroundColor: btnColor,
                visualDensity: VisualDensity.compact,
              ),
            ),

            const SizedBox(height: 12),

            // Сетка кнопок (Ячейки)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: List.generate(5, (i) {
                final lvl = i + 1;
                final cost = _creationCosts[lvl]!;

                // Логика доступности
                final canCreate = current >= cost && lvl <= _getMaxSlotLevel();
                final canBurn =
                    _getAvailableSlots(lvl) > 0; // Есть ли ячейки для сжигания
                final isEnabled =
                    !_resourceBusy && (_isCreateSlotMode ? canCreate : canBurn);

                return _ExchangeButton(
                  level: lvl,
                  value: _isCreateSlotMode ? "-$cost" : "+$lvl",
                  isEnabled: isEnabled,
                  isCreateMode: _isCreateSlotMode,
                  activeColor: _isCreateSlotMode
                      ? barColor
                      : btnColor, // Оранжевый для траты, Бежевый для получения
                  onTap: () => _isCreateSlotMode
                      ? _createSlot(lvl, cost, pool)
                      : _burnSlot(lvl, pool),
                );
              }),
            ),
            if (!_isCreateSlotMode &&
                (MagicSlots.read(widget.character).pact?.current ?? 0) > 0) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                  onPressed: _resourceBusy
                      ? null
                      : () async {
                          final pact = MagicSlots.read(widget.character).pact!;
                          final applied = await _applyResource(() =>
                              SorceryActionsService.convert(
                                  widget.character, pact.circle,
                                  creating: false,
                                  definition: widget.sorceryPoints,
                                  payment: MagicPool.pact));
                          if (mounted && applied) {
                            AppSnackBar.success(
                                context,
                                locale == 'ru'
                                    ? 'Ячейка Магии договора обменена на ${pact.circle} ОЧ.'
                                    : 'Pact slot converted to ${pact.circle} SP.');
                          }
                        },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(locale == 'ru'
                      ? 'Магия договора → ОЧ'
                      : 'Pact Magic → SP')),
            ],
          ],
        ));
  }

  // ===========================================================================
  // 3. METAMAGIC LOGIC (Идеальная Таблетка)
  // ===========================================================================
  Widget _buildMetamagicBlock(
      CharacterFeature base,
      List<CharacterFeature> options,
      ColorScheme colorScheme,
      Color activeBg,
      Color activeContent,
      Color iconColor,
      String locale) {
    return ExpansionTile(
        initiallyExpanded: _isMetamagicExpanded,
        onExpansionChanged: (value) =>
            setState(() => _isMetamagicExpanded = value),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        leading: IconButton(
            tooltip: AppLocalizations.of(context)!.advancementDetails,
            onPressed: () => _showDetails(base),
            icon: const Icon(Icons.info_outline_rounded)),
        title: Text(locale == 'ru' ? 'Метамагия' : 'Metamagic',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${options.length}'),
          const SizedBox(width: 8),
          Icon(_isMetamagicExpanded
              ? Icons.expand_less_rounded
              : Icons.expand_more_rounded)
        ]),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (options.isEmpty)
            Text(locale == 'ru'
                ? 'Приёмы пока не выбраны'
                : 'No techniques selected yet'),
          for (final option in options)
            _buildMetamagicTile(
                option, colorScheme, activeBg, activeContent, locale),
        ]);
  }

  Widget _buildMetamagicTile(CharacterFeature opt, ColorScheme colorScheme,
      Color btnBg, Color btnContent, String locale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(opt),
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(Icons.flash_on,
                      size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt
                            .getName(locale)
                            .replaceAll("Метамагия: ", "")
                            .replaceAll(
                                "Metamagic: ", ""), // Убираем дубляж слова
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                // Компактная кнопка применения
                SizedBox(
                  width: 48,
                  height: 36,
                  child: FilledButton(
                    onPressed: () => _useMetamagic(opt),
                    style: FilledButton.styleFrom(
                      backgroundColor: btnBg,
                      foregroundColor: btnContent,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.auto_fix_high, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ЛОГИКА И ХЕЛПЕРЫ
  // ===========================================================================

  void _showDetails(CharacterFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => FeatureDetailsSheet(feature: feature),
    );
  }

  // Определение дракона по ключевым словам
  _DragonData _getDragonInfo(String locale) {
    final dragonMap = {
      'red': _DragonData(
          'Красный дракон', Colors.redAccent, Icons.local_fire_department),
      'красный': _DragonData(
          'Красный дракон', Colors.redAccent, Icons.local_fire_department),
      'gold': _DragonData(
          'Золотой дракон', Colors.orange, Icons.local_fire_department),
      'золотой': _DragonData(
          'Золотой дракон', Colors.orange, Icons.local_fire_department),
      'brass': _DragonData(
          'Латунный дракон', Colors.amber, Icons.local_fire_department),
      'латунный': _DragonData(
          'Латунный дракон', Colors.amber, Icons.local_fire_department),
      'white': _DragonData('Белый дракон', Colors.lightBlue, Icons.ac_unit),
      'белый': _DragonData('Белый дракон', Colors.lightBlue, Icons.ac_unit),
      'silver': _DragonData('Серебряный дракон', Colors.cyan, Icons.ac_unit),
      'серебряный':
          _DragonData('Серебряный дракон', Colors.cyan, Icons.ac_unit),
      'blue': _DragonData('Синий дракон', Colors.blueAccent, Icons.bolt),
      'синий': _DragonData('Синий дракон', Colors.blueAccent, Icons.bolt),
      'bronze': _DragonData('Бронзовый дракон', Colors.indigo, Icons.bolt),
      'бронзовый': _DragonData('Бронзовый дракон', Colors.indigo, Icons.bolt),
      'black':
          _DragonData('Черный дракон', Colors.green.shade800, Icons.science),
      'черный':
          _DragonData('Черный дракон', Colors.green.shade800, Icons.science),
      'copper':
          _DragonData('Медный дракон', Colors.lime.shade700, Icons.science),
      'медный':
          _DragonData('Медный дракон', Colors.lime.shade700, Icons.science),
      'green': _DragonData('Зеленый дракон', Colors.teal, Icons.pest_control),
      'зеленый': _DragonData('Зеленый дракон', Colors.teal, Icons.pest_control),
    };

    for (var f in widget.ancestryFeatures) {
      final name = f.getName(locale).toLowerCase();
      for (var entry in dragonMap.entries) {
        if (name.contains(entry.key)) {
          return entry.value..matchedFeature = f;
        }
      }
    }
    return _DragonData(locale == 'ru' ? 'Драконий предок' : 'Draconic Ancestry',
        Colors.deepPurple, Icons.shield);
  }

  int _getMaxSlotLevel() => 5;

  // Безопасное получение количества ячеек определенного уровня
  int _getAvailableSlots(int level) {
    try {
      if (widget.character.spellSlots.length >= level) {
        return widget.character.spellSlots[level - 1];
      }
    } catch (e) {
      debugPrint("Sorcerer: Error reading spell slots: $e");
    }
    return 0;
  }

  Future<void> _createSlot(int lvl, int cost, ResourcePool pool) async {
    final applied = await _applyResource(() => SorceryActionsService.convert(
        widget.character, lvl,
        creating: true, definition: widget.sorceryPoints));
    if (!mounted || !applied) return;
    HapticFeedback.mediumImpact();
    AppSnackBar.success(
        context,
        Localizations.localeOf(context).languageCode == 'ru'
            ? 'Создана ячейка $lvl-го круга (−$cost ОЧ).'
            : 'Level $lvl slot created (−$cost SP).');
  }

  Future<void> _burnSlot(int lvl, ResourcePool pool) async {
    final applied = await _applyResource(() => SorceryActionsService.convert(
        widget.character, lvl,
        creating: false, definition: widget.sorceryPoints));
    if (!mounted || !applied) return;
    HapticFeedback.mediumImpact();
    AppSnackBar.info(
        context,
        Localizations.localeOf(context).languageCode == 'ru'
            ? 'Ячейка $lvl-го круга поглощена (+$lvl ОЧ).'
            : 'Level $lvl slot converted (+$lvl SP).');
  }

  void _useMetamagic(CharacterFeature opt) {
    final pool = _getActualPool();
    final locale = Localizations.localeOf(context).languageCode;
    final cost = opt.consumption?.amount ??
        switch (opt.id) {
          'metamagic-quickened-spell' => 2,
          'metamagic-heightened-spell' => 3,
          _ => 1,
        };

    showDialog(
      context: context,
      builder: (context) {
        int tempCost = cost;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasEnough = pool.currentUses >= tempCost;

            return AlertDialog(
              title: Text(locale == 'ru'
                  ? "Применить: ${opt.nameRu}"
                  : "Apply: ${opt.nameEn}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locale == 'ru'
                        ? "Выберите стоимость Очков Чародейства:"
                        : "Select Sorcery Points Cost:",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: tempCost > 1
                            ? () => setDialogState(() => tempCost--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          "$tempCost",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer, // Гарантированный контраст
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        onPressed: tempCost < pool.currentUses
                            ? () => setDialogState(() => tempCost++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    locale == 'ru'
                        ? "Доступно: ${pool.currentUses}"
                        : "Available: ${pool.currentUses}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasEnough
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(locale == 'ru' ? "Отмена" : "Cancel"),
                ),
                FilledButton(
                  onPressed: hasEnough
                      ? () async {
                          final applied = await _applyResource(() =>
                              SorceryActionsService.spend(
                                  widget.character, tempCost,
                                  definition: widget.sorceryPoints));
                          if (!context.mounted || !applied) return;
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context);
                          AppSnackBar.success(
                            context,
                            locale == 'ru'
                                ? "Применено! (-$tempCost ОЧ)"
                                : "Applied! (-$tempCost SP)",
                            duration: const Duration(seconds: 2),
                          );
                        }
                      : null,
                  child: Text(locale == 'ru' ? "Применить" : "Apply"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCustomSPDialog(ResourcePool pool, String locale) async {
    final TextEditingController controller =
        TextEditingController(text: "${pool.currentUses}");
    final maxSp = pool.maxUses;

    await showDialog<void>(
      context: context,
      requestFocus: false,
      builder: (context) => AlertDialog(
        title: Text(locale == 'ru' ? "Единицы чародейства" : "Sorcery Points"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              locale == 'ru'
                  ? "Укажите текущий остаток (обычный максимум: $maxSp):"
                  : "Set the current remainder (normal maximum: $maxSp):",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "0",
                suffixText: "/ $maxSp",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(locale == 'ru' ? "Отмена" : "Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null) {
                HapticFeedback.mediumImpact();
                final applied = await _applyResource(() =>
                    SorceryActionsService.setCurrent(widget.character, val,
                        definition: widget.sorceryPoints));
                if (!context.mounted || !applied) return;
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(locale == 'ru' ? "ОК" : "OK"),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

// Данные для маппинга драконов
class _DragonData {
  final String name;
  final Color color;
  final IconData icon;
  CharacterFeature? matchedFeature;
  _DragonData(this.name, this.color, this.icon);
}

// Кнопка биржи
class _ExchangeButton extends StatelessWidget {
  final int level;
  final String value;
  final bool isEnabled;
  final bool isCreateMode;
  final Color activeColor;
  final VoidCallback onTap;

  const _ExchangeButton({
    required this.level,
    required this.value,
    required this.isEnabled,
    required this.isCreateMode,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final color = isEnabled ? activeColor : theme.outlineVariant;
    final textColor = isEnabled ? theme.onSurface : theme.onSurfaceVariant;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        width: MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 76 : 56,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(8),
        decoration: companionDecoration(context,
            quiet: true,
            color: isEnabled ? theme.surface : theme.surfaceContainerLow,
            accent: color,
            shape: const StadiumBorder()),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
                '$level ${Localizations.localeOf(context).languageCode == 'ru' ? 'круг' : 'level'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor)),
          ],
        ),
      ),
    );
  }
}

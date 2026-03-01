import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../shared/widgets/feature_details_sheet.dart';

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
  bool _isMetamagicExpanded = false; // Раскрыт ли список метамагии

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
    final blockBg = colorScheme.surfaceContainerHighest;

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
            // --- BLOCK 1: DRACONIC ANCESTRY ---
            if (widget.ancestryFeatures.isNotEmpty) ...[
              _buildAncestryBlock(dragonInfo, blockBg),
              const SizedBox(height: 12),
            ],

            // --- BLOCK 2: FONT OF MAGIC (ОБМЕННИК) ---
            if (widget.character.level >= 2) ...[
              _buildBlockContainer(
                color: blockBg,
                child: _buildFontOfMagicBlock(
                    colorScheme, orangeAccent, beigeAccent, onBeige, locale),
              ),
              const SizedBox(height: 12),
            ],

            // --- BLOCK 3: METAMAGIC ---
            if (metamagicOptions.isNotEmpty || widget.character.level >= 3) ...[
              Container(
                decoration: BoxDecoration(
                  color: blockBg,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildMetamagicBlock(baseMetamagic, metamagicOptions,
                    colorScheme, beigeAccent, onBeige, orangeAccent, locale),
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

  /// Стандартный контейнер-плитка
  Widget _buildBlockContainer({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: child,
      ),
    );
  }

  // ===========================================================================
  // 1. DRACONIC ANCESTRY LOGIC
  // ===========================================================================
  Widget _buildAncestryBlock(_DragonData info, Color blockBg) {
    return Container(
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.15), // Легкий стихийный оттенок
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(
              info.matchedFeature ?? widget.ancestryFeatures.first),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                // Фоновая огромная иконка стихии
                Positioned(
                  right: -10,
                  top: -15,
                  bottom: -15,
                  child: Icon(info.icon,
                      size: 80, color: info.color.withValues(alpha: 0.2)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ДРАКОНЬЕ НАСЛЕДИЕ",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: info.color),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.name,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface),
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
  // 2. FONT OF MAGIC (EXCHANGE) LOGIC
  // ===========================================================================

  /// Вспомогательный метод для получения актуального пула из состояния персонажа.
  /// Это критично для реактивности UI. ГАРАНТИРУЕТ возврат объекта и его персистентность.
  ResourcePool _getActualPool() {
    final poolId = widget.sorceryPoints?.id ?? 'sorcerer_points';

    // 1. Ищем фичу в списке персонажа
    int featureIndex =
        widget.character.features.indexWhere((f) => f.id == poolId);
    CharacterFeature feature;

    if (featureIndex != -1) {
      feature = widget.character.features[featureIndex];
    } else {
      // Если фичи нет в списке, добавляем её (или используем переданную)
      feature = widget.sorceryPoints ??
          CharacterFeature(
            id: poolId,
            nameEn: 'Sorcery Points',
            nameRu: 'Единицы чародейства',
            descriptionEn: 'Points used to fuel magic.',
            descriptionRu: 'Очки для усиления магии.',
            type: FeatureType.resourcePool,
            minLevel: 2,
          );
      widget.character.features.add(feature);
      widget.character.save();
    }

    // 2. Гарантируем наличие пула внутри фичи
    if (feature.resourcePool == null) {
      feature.resourcePool = ResourcePool(
          currentUses: widget.character.level,
          maxUses: widget.character.level,
          recoveryType: RecoveryType.longRest);
      widget.character.save();
    }

    return feature.resourcePool!;
  }

  Widget _buildFontOfMagicBlock(ColorScheme colorScheme, Color barColor,
      Color btnColor, Color onBtnColor, String locale) {
    // Реактивное получение пула. Метод теперь гарантирует связь с базой.
    final pool = _getActualPool();

    final max = pool.maxUses > 0 ? pool.maxUses : widget.character.level;
    final current = pool.currentUses;
    final progress = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        // Заголовок и прогресс-бар в InkWell для ручного ввода
        InkWell(
          onTap: () => _showCustomSPDialog(pool, locale),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: barColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locale == 'ru' ? "ЕДИНИЦЫ ЧАРОДЕЙСТВА" : "SORCERY POINTS",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Icon(Icons.edit_note,
                      size: 18, color: colorScheme.outline.withValues(alpha: 0.5)),
                ],
              ),

              // Счетчик
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$current / $max',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface),
                ),
              ),

              const SizedBox(height: 6),

              // Полоска прогресса
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 14,
                      backgroundColor: colorScheme.surfaceDim,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Переключатель режимов (Создать / Сжечь)
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
                value: true,
                label: Text(locale == 'ru' ? "Создать" : "Create"),
                icon: const Icon(Icons.add_circle_outline)),
            ButtonSegment(
                value: false,
                label: Text(locale == 'ru' ? "Сжечь" : "Burn"),
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
            final isEnabled = _isCreateSlotMode ? canCreate : canBurn;

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
      ],
    );
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
    final pillColor = _isMetamagicExpanded ? activeBg : colorScheme.surfaceDim;
    final pillContentColor =
        _isMetamagicExpanded ? activeContent : colorScheme.onSurfaceVariant;
    final leadingIconColor = _isMetamagicExpanded ? activeContent : iconColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HEADER: Шапка, растянутая на всю ширину (как у Паладина)
        Material(
          color: pillColor,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _showDetails(
                base), // Клик по шапке показывает описание самой Метамагии
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high, color: leadingIconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locale == 'ru' ? "МЕТАМАГИЯ" : "METAMAGIC",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: pillContentColor,
                      ),
                    ),
                  ),
                  Icon(Icons.info_outline,
                      size: 16, color: pillContentColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  // Switch раскрытия
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: _isMetamagicExpanded,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() => _isMetamagicExpanded = val);
                      },
                      activeThumbColor: colorScheme.primary,
                      activeTrackColor: colorScheme.primaryContainer,
                      inactiveThumbColor: colorScheme.onSurfaceVariant,
                      inactiveTrackColor: Colors.transparent,
                      // Чтобы свитч было видно на темном фоне
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.transparent;
                        }
                        return colorScheme.outline;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // THE LIST: Список заклинаний
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isMetamagicExpanded
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: options
                        .map((opt) => _buildMetamagicTile(
                            opt, colorScheme, activeBg, activeContent, locale))
                        .toList(),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _buildMetamagicTile(CharacterFeature opt, ColorScheme colorScheme,
      Color btnBg, Color btnContent, String locale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDetails(opt),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
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
                            fontSize: 13,
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
                          borderRadius: BorderRadius.circular(12)),
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

  int _getMaxSlotLevel() {
    final lvl = widget.character.level;
    if (lvl >= 17) return 5;
    if (lvl >= 9) return 5;
    if (lvl >= 7) return 4;
    if (lvl >= 5) return 3;
    if (lvl >= 3) return 2;
    return 1;
  }

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

  // Безопасное изменение ячеек
  void _changeSpellSlot(int level, int amount) {
    try {
      // Ensure the list is long enough
      while (widget.character.spellSlots.length < level) {
        widget.character.spellSlots.add(0);
      }
      widget.character.spellSlots[level - 1] += amount;
      if (widget.character.spellSlots[level - 1] < 0) {
        widget.character.spellSlots[level - 1] = 0;
      }
    } catch (e) {
      debugPrint("Sorcerer: Error modifying spell slots: $e");
    }
  }

  void _createSlot(int lvl, int cost, ResourcePool pool) {
    HapticFeedback.heavyImpact();
    setState(() {
      pool.use(cost);
      _changeSpellSlot(lvl, 1);
      widget.character.save();
      widget.onChanged?.call();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Localizations.localeOf(context).languageCode == 'ru'
          ? "Ячейка $lvl-го уровня создана! (-$cost ОЧ)"
          : "Level $lvl slot created! (-$cost SP)"),
      duration: const Duration(seconds: 1),
    ));
  }

  void _burnSlot(int lvl, ResourcePool pool) {
    if (_getAvailableSlots(lvl) <= 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _changeSpellSlot(lvl, -1);
      pool.restore(lvl); // Восстанавливает SP равное уровню ячейки
      widget.character.save();
      widget.onChanged?.call();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Localizations.localeOf(context).languageCode == 'ru'
          ? "Ячейка $lvl-го уровня поглощена! (+$lvl ОЧ)"
          : "Level $lvl slot burned! (+$lvl SP)"),
      duration: const Duration(seconds: 1),
    ));
  }

  void _useMetamagic(CharacterFeature opt) {
    final pool = _getActualPool();
    final locale = Localizations.localeOf(context).languageCode;
    int cost = 1;

    // Smart cost detection
    final desc = opt.getDescription(locale).toLowerCase();
    if (desc.contains('2 points') || desc.contains('2 единицы')) {
      cost = 2;
    } else if (desc.contains('3 points') || desc.contains('3 единицы')) {
      cost = 3;
    }

    // Ограничиваем стоимость текущим балансом, если он меньше дефолтной стоимости
    if (cost > pool.currentUses) cost = pool.currentUses;
    if (cost < 1) cost = 1;

    showDialog(
      context: context,
      builder: (context) {
        int tempCost = cost;
        return StatefulBuilder(builder: (context, setDialogState) {
          final hasEnough =
              pool.currentUses >= tempCost && pool.currentUses > 0;

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
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 2),
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
                    fontSize: 12,
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
                    ? () {
                        HapticFeedback.heavyImpact();
                        setState(() {
                          pool.use(tempCost);
                          widget.character.save();
                          widget.onChanged?.call();
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(locale == 'ru'
                              ? "Применено! (-$tempCost ОЧ)"
                              : "Applied! (-$tempCost SP)"),
                          duration: const Duration(seconds: 1),
                        ));
                      }
                    : null,
                child: Text(locale == 'ru' ? "Применить" : "Apply"),
              ),
            ],
          );
        });
      },
    );
  }

  void _showCustomSPDialog(ResourcePool pool, String locale) {
    final TextEditingController controller =
        TextEditingController(text: "${pool.currentUses}");
    final maxSp = pool.maxUses > 0 ? pool.maxUses : widget.character.level;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(locale == 'ru' ? "Единицы чародейства" : "Sorcery Points"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              locale == 'ru'
                  ? "Укажите текущее количество очков (0 - $maxSp):"
                  : "Set current points amount (0 - $maxSp):",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "0",
                suffixText: "/ $maxSp",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                HapticFeedback.mediumImpact();
                setState(() {
                  pool.currentUses = val.clamp(0, maxSp);
                  widget.character.save();
                  widget.onChanged?.call();
                });
              }
              Navigator.pop(context);
            },
            child: Text(locale == 'ru' ? "ОК" : "OK"),
          ),
        ],
      ),
    );
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
    final textColor = isEnabled
        ? (isCreateMode ? theme.onSurface : theme.onSecondary)
        : theme.onSurfaceVariant;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isEnabled ? color : color.withValues(alpha: 0.5),
              width: isEnabled ? 2 : 1),
          // Если режим поглощения (бежевый), заливаем полностью. Если трата (оранжевый) - прозрачный с бордером.
          color: isEnabled
              ? (isCreateMode ? color.withValues(alpha: 0.1) : color)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Lvl $level",
                style: TextStyle(
                    fontSize: 10,
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
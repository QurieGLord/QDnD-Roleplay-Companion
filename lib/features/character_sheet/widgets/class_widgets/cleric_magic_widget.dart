import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/magic/class_action_state.dart';
import '../../../../core/magic/class_spell_grants.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import '../../../../shared/widgets/spell_cast_sheet.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Cleric · Channel Divinity (prototype `CLASS.cleric`). A sun between the
/// ways of the channel: the beam swings to the chosen one and touching the
/// sun channels it. Preserve Life then hands its drops of light to
/// numbered targets; Turn Undead burns its minute down.
class ClericMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const ClericMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<ClericMagicWidget> createState() => _ClericMagicWidgetState();
}

enum _Phase { none, life, turn }

class _ClericMagicWidgetState extends State<ClericMagicWidget>
    with TickerProviderStateMixin {
  bool _usingChannel = false;
  bool _usingIntervention = false;
  int _pick = 1, _rounds = 1, _targets = 2, _burst = 0;
  _Phase _phase = _Phase.none;
  List<int?> _drops = const [];
  late final _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 46));

  Character get _hero => widget.character;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  List<CharacterFeature> get _options => _hero.features
      .where((f) =>
          CharacterClassContext(_hero, 'cleric').acceptsFeature(f) &&
          f.usageCostId == 'channel-divinity' &&
          f.isAction &&
          !f.id.toLowerCase().replaceAll('_', '-').contains('turn-undead'))
      .toList();

  int get _heal => 5 * _hero.classLevel('cleric');
  int get _unit => (_heal / 10).ceil();
  int get _dropCount => (_heal / _unit).ceil();
  int _dropValue(int k) =>
      k < _dropCount - 1 ? _unit : _heal - _unit * (_dropCount - 1);

  Future<void> _channel() async {
    final options = _options;
    final option = _pick == 0 || options.isEmpty ? null : options[(_pick - 1).clamp(0, options.length - 1)];
    final cost = option?.consumption?.amount ?? 1;
    if (_usingChannel) return;
    final ru = instrumentRu(context);
    if (_hero.channelDivinityCharges < cost) {
      AppSnackBar.info(context, ru ? 'Канал вернёт короткий отдых' : 'A short rest restores the channel');
      return;
    }
    setState(() => _usingChannel = true);
    try {
      final changed = await GameplayActionsService.spendChannelDivinity(_hero, amount: cost);
      if (!mounted || !changed) return;
      HapticFeedback.mediumImpact();
      final preserve = option != null && option.id.toLowerCase().replaceAll('_', '-').contains('preserve-life');
      setState(() {
        _burst++;
        if (option == null) {
          _phase = _Phase.turn;
          _rounds = 1;
        } else if (preserve) {
          _phase = _Phase.life;
          _drops = List.filled(_dropCount, null);
          _targets = 2;
        } else {
          _phase = _Phase.none;
        }
      });
      widget.onStateChanged();
      if (option != null && !preserve && mounted) {
        AppSnackBar.success(context, option.getName(ru ? 'ru' : 'en'));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _usingChannel = false);
    }
  }

  Future<void> _edit() async {
    final feature = _hero.channelDivinityResource;
    if (feature == null) return;
    final changed = await showResourceValueEditor(context, _hero, feature);
    if (mounted && changed) setState(widget.onStateChanged);
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a2 = accentOf(context, 2);
    final level = _hero.classLevel('cleric');
    final maxCharges = _hero.channelDivinityResource?.resourcePool?.maxUses ??
        _hero.getMaxChannelDivinityCharges();
    final children = <Widget>[];
    if (level < 2) {
      children.add(LockedInstrument(
          title: ru ? 'Божественный канал' : 'Channel Divinity',
          level: 2,
          what: ru ? 'Изгнание нежити и умения домена' : 'Turn Undead and your domain’s channel',
          accent: a2));
    } else if (maxCharges > 0 || _hero.channelDivinityCharges > 0) {
      children.add(_channelInstrument(context, ru, locale, a2, level, maxCharges));
    }
    final domain = _domain(context, ru, locale, a2);
    if (domain != null) children.add(domain);
    if (level >= 10 &&
        _hero.features.any((f) =>
            f.id.replaceAll('_', '-') == 'divine-intervention' &&
            CharacterClassContext(_hero, 'cleric').acceptsFeature(f))) {
      children.add(_intervention(context, ru, a2, level));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }

  Widget _channelInstrument(BuildContext context, bool ru, String locale, Color a2, int level, int maxCharges) {
    final left = _hero.channelDivinityCharges;
    final dc = 8 + _hero.proficiencyBonus + _hero.abilityScores.wisdomModifier;
    final options = _options;
    final undead = level >= 5 ? (ru ? 'Уничтожение' : 'Destroy') : (ru ? 'Изгнание' : 'Turn');
    final cr = level >= 17 ? '4' : level >= 14 ? '3' : level >= 11 ? '2' : level >= 8 ? '1' : '½';
    if (_pick > options.length) _pick = options.isEmpty ? 0 : 1;
    final spent = left == 0;
    if (!spent && !_spin.isAnimating && !MediaQuery.disableAnimationsOf(context)) _spin.repeat(count: 1);
    if (spent && _spin.isAnimating) _spin.stop();
    String optionName(CharacterFeature f) => f
        .getName(locale)
        .replaceFirst(RegExp(r'^Божественный канал:\s*'), '')
        .replaceFirst(RegExp(r'^Channel Divinity:\s*'), '');
    Widget way(int i) {
      final isUndead = i == 0;
      final f = isUndead ? null : options[i - 1];
      final preserve = f != null && f.id.toLowerCase().replaceAll('_', '-').contains('preserve-life');
      final name = isUndead ? undead : optionName(f!).split(' ').first;
      final value = isUndead ? (ru ? 'Сл $dc' : 'DC $dc') : preserve ? (ru ? '$_heal ОЗ' : '$_heal HP') : '${f!.consumption?.amount ?? 1}';
      return _Way(
        key: ValueKey('cleric-way-$i'),
        glyph: isUndead ? 'skull' : (preserve ? 'heart' : 'spark'),
        label: name,
        value: value,
        accent: a2,
        selected: _pick == i,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _pick = i);
        },
        peek: isUndead
            ? (
                level >= 5 ? (ru ? 'Уничтожение нежити' : 'Destroy Undead') : (ru ? 'Изгнание нежити' : 'Turn Undead'),
                ru
                    ? 'Нежить в 30 фт.: спасбросок Мудрости Сл $dc, иначе бежит 1 минуту${level >= 5 ? '. Нежить ПО $cr и ниже уничтожается' : ''}'
                    : 'Undead within 30 ft.: Wisdom save DC $dc or flee for a minute${level >= 5 ? '. Undead of CR $cr or lower are destroyed' : ''}'
              )
            : (optionName(f!), f.getDescription(locale).split('\n').first),
      );
    }

    Widget? phase;
    if (_phase == _Phase.life && _drops.isNotEmpty) phase = _distribution(context, ru, a2);
    if (_phase == _Phase.turn) {
      phase = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Fuse(length: 10, at: _rounds, accent: a2),
        const SizedBox(height: 12),
        RoundControl(
          round: _rounds,
          of: 10,
          accent: a2,
          label: ru ? 'нежить бежит' : 'undead flee',
          endLabel: ru ? 'Снять' : 'End',
          onEnd: () => setState(() => _phase = _Phase.none),
          onNext: () {
            HapticFeedback.selectionClick();
            setState(() {
              _rounds = math.min(10, _rounds + 1);
              if (_rounds == 10) _phase = _Phase.none;
            });
          },
        ),
      ]);
    }

    return Instrument(
      key: const ValueKey('cleric-channel'),
      accent: a2,
      title: ru ? 'Божественный канал' : 'Channel Divinity',
      about: InstrumentAbout(
          title: ru ? 'Божественный канал' : 'Channel Divinity',
          kicker: ru ? 'Действие · короткий отдых' : 'Action · short rest',
          paragraphs: AppLocalizations.of(context)!.channelDivinityRules.split(RegExp(r'\n\s*\n')),
          how: ru ? 'Выберите путь слева или справа, затем коснитесь солнца.' : 'Pick a way on either side, then touch the sun.'),
      trailing: RestChip(
          short: true,
          onEdit: _edit,
          onRestore: _hero.channelDivinityResource == null
              ? null
              : () => restoreFeature(context, _hero, _hero.channelDivinityResource!, done: () => setState(widget.onStateChanged))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: way(0)),
          _Sun(
            key: const ValueKey('cleric-sun'),
            spin: _spin,
            aimRight: _pick != 0,
            spent: spent,
            burst: _burst,
            accent: a2,
            left: left,
            max: maxCharges,
            onTap: _usingChannel ? null : _channel,
          ),
          Expanded(child: options.isEmpty ? const SizedBox() : way(1)),
        ]),
        if (options.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
            for (var i = 2; i <= options.length; i++)
              OutlineChip(
                  label: optionName(options[i - 1]),
                  strong: _pick == i,
                  onTap: () => setState(() => _pick = i)),
          ]),
        ],
        const SizedBox(height: 10),
        InstrumentHint(
            spent
                ? (ru ? 'Канал вернёт короткий отдых' : 'A short rest restores the channel')
                : (ru ? 'Коснитесь солнца — направить' : 'Touch the sun to channel'),
            center: true),
        if (phase != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(22)),
            child: phase,
          ),
        ],
      ]),
    );
  }

  Widget _distribution(BuildContext context, bool ru, Color a2) {
    final c = Theme.of(context).colorScheme;
    int given(int target) {
      var sum = 0;
      for (var k = 0; k < _drops.length; k++) {
        if (_drops[k] == target) sum += _dropValue(k);
      }
      return sum;
    }

    Widget drop(int k, {double scale = 1}) => _Drop(key: ValueKey('drop-$k'), small: _dropValue(k) < _unit, accent: a2, scale: scale);
    final free = [for (var k = 0; k < _drops.length; k++) if (_drops[k] == null) k];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
        if (free.isEmpty)
          InstrumentHint(ru ? 'всё распределено' : 'all handed out')
        else
          for (final k in free) drop(k),
      ]),
      const SizedBox(height: 8),
      InstrumentHint(ru ? 'Коснитесь цели — отдать каплю' : 'Tap a target to give a drop', center: true),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < _targets; i++)
          SizedBox(
            width: 92,
            child: Pressable(
              scale: .94,
              onTap: () {
                final k = _drops.indexOf(null);
                if (k < 0) return;
                HapticFeedback.selectionClick();
                setState(() => _drops = [..._drops]..[k] = i);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(ru ? 'Цель ${i + 1}' : 'Target ${i + 1}', style: labelStyle(context, size: 13)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 18,
                    child: Wrap(spacing: 3, children: [
                      for (var k = 0; k < _drops.length; k++)
                        if (_drops[k] == i) drop(k, scale: .62),
                    ]),
                  ),
                  RollingNumber(given(i), style: bigStyle(context).copyWith(fontSize: 22)),
                ]),
              ),
            ),
          ),
        if (_targets < 6)
          SizedBox(
            width: 92,
            child: Pressable(
              scale: .94,
              semanticLabel: ru ? 'Ещё цель' : 'Another target',
              onTap: () => setState(() => _targets++),
              child: Container(
                height: 84,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.outline, width: 1.5)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  LineIcon('plus', size: 20, color: c.onSurfaceVariant),
                  Text(ru ? 'цель' : 'target', style: hintStyle(context)),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      TileRow(children: [
        GhostButton(
            label: ru ? 'Вернуть' : 'Undo',
            onTap: () {
              final k = _drops.lastIndexWhere((d) => d != null);
              if (k < 0) return;
              setState(() => _drops = [..._drops]..[k] = null);
            }),
        GoButton(
            label: ru ? 'Готово' : 'Done',
            accent: a2,
            onTap: () {
              var sum = 0;
              for (var k = 0; k < _drops.length; k++) {
                if (_drops[k] != null) sum += _dropValue(k);
              }
              HapticFeedback.lightImpact();
              setState(() => _phase = _Phase.none);
              AppSnackBar.success(context, ru ? 'Сохранение жизни: $sum ОЗ' : 'Preserve Life: $sum HP');
            }),
      ]),
    ]);
  }

  Widget? _domain(BuildContext context, bool ru, String locale, Color a2) {
    final owner = CharacterClassContext(_hero, 'cleric');
    if (owner.subclass == null) return null;
    final name = subclassDisplayName(_hero, 'cleric', locale) ?? owner.subclass!;
    final adept = _hero.features
        .where((f) => owner.acceptsFeature(f) && f.id.toLowerCase().replaceAll('_', '-').contains('disciple-of-life'))
        .firstOrNull;
    final spells = [
      for (final id in ClassSpellGrants.ids(_hero, 'cleric'))
        if (ClassSpellGrants.spell(id) case final s?) s
    ].take(2).toList();
    if (adept == null && spells.isEmpty) return null;
    return LiteBlock(
      accent: a2,
      title: name,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (adept != null)
            Expanded(
              flex: 6,
              child: Peek(
                title: adept.getName(locale),
                text: adept.getDescription(locale),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: a2.withValues(alpha: .14), borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    InstrumentGlyph('heart', size: 20, color: a2),
                    const SizedBox(height: 4),
                    Text(ru ? '+2 + круг' : '+2 + level', style: bigStyle(context).copyWith(fontSize: 17)),
                    Text(ru ? 'к лечению' : 'to healing', style: hintStyle(context).copyWith(fontSize: 11.5)),
                  ]),
                ),
              ),
            ),
          for (final spell in spells) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Peek(
                title: spell.getName(locale),
                text: ru ? 'Всегда подготовлено доменом. Коснитесь — наложить' : 'Always prepared by your domain. Tap to cast',
                child: Pressable(
                  scale: .93,
                  semanticLabel: spell.getName(locale),
                  onTap: () async {
                    await showSpellCastSheet(context, _hero, spell);
                    if (mounted) setState(widget.onStateChanged);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(18)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                                center: const Alignment(-.3, -.4),
                                colors: [mixColor(a2, .7, Theme.of(context).colorScheme.surfaceContainer), mixColor(a2, .25, Theme.of(context).colorScheme.surfaceContainer)]),
                            boxShadow: [BoxShadow(color: a2.withValues(alpha: .2), spreadRadius: 3)]),
                        child: LineIcon('star', size: 18, color: onAccent(context)),
                      ),
                      const SizedBox(height: 6),
                      spell.getName(locale).contains(' ')
                          ? Text(spell.getName(locale),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle(context, size: 11.5))
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(spell.getName(locale),
                                  maxLines: 1, style: labelStyle(context, size: 11.5))),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _intervention(BuildContext context, bool ru, Color a2, int level) {
    final used = _hero.divineInterventionUsed;
    bool attempted = false, supported = true;
    try {
      attempted = ClassActionState.interventionAttempted(_hero);
    } catch (_) {
      supported = false;
    }
    final ready = supported && !used && !attempted;
    final l10n = AppLocalizations.of(context)!;
    return Instrument(
      key: const ValueKey('cleric-intervention'),
      accent: a2,
      title: l10n.divineIntervention,
      about: InstrumentAbout(
          title: l10n.divineIntervention,
          paragraphs: l10n.divineInterventionRules.split(RegExp(r'\n\s*\n')),
          how: ru
              ? 'Опишите мастеру, о какой помощи просите, и коснитесь «Воззвать».'
              : 'Describe the aid you seek to your GM, then tap “Call”.'),
      trailing: InstrumentChip(!supported
          ? (ru ? 'нужно обновление' : 'update needed')
          : used
              ? (ru ? 'через 7 дней' : 'in 7 days')
              : attempted
                  ? (ru ? 'после отдыха' : 'after a rest')
                  : (ru ? 'готово' : 'ready')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(level >= 20 ? (ru ? 'Без броска' : 'No roll') : '$level%', style: level >= 20 ? bigStyle(context) : hugeStyle(context)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: InstrumentHint(level >= 20
                  ? (ru ? 'божество отвечает всегда' : 'your deity always answers')
                  : (ru ? 'шанс, что божество ответит' : 'chance your deity answers'))),
        ]),
        const SizedBox(height: 14),
        if (ready)
          GoButton(
              label: l10n.callUponDeity,
              glyph: 'sun',
              accent: a2,
              onTap: _usingIntervention ? null : _handleInterventionRoll)
        else if (supported)
          GhostButton(
              label: ru ? 'Отметить готовность' : 'Mark as ready',
              onTap: _usingIntervention ? null : _resetIntervention),
      ]),
    );
  }

  Future<void> _resetIntervention() async {
    if (_usingIntervention) return;
    setState(() => _usingIntervention = true);
    try {
      await ClassSessionActionsService.resetDivineIntervention(
          widget.character);
      if (mounted) {
        HapticFeedback.selectionClick();
        widget.onStateChanged();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _usingIntervention = false);
    }
  }

  Future<void> _handleInterventionRoll() async {
    if (_usingIntervention) return;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    setState(() => _usingIntervention = true);
    try {
      final result = await ClassSessionActionsService.divineIntervention(
          widget.character,
          locale: ru ? 'ru' : 'en');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      widget.onStateChanged();
      await showResponsiveSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) {
            final t = Theme.of(context), c = t.colorScheme;
            return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          ru
                              ? 'Божественное вмешательство'
                              : 'Divine Intervention',
                          style: t.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 20),
                      CompanionSurface(
                          contour: CompanionContour.focus,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    result.success
                                        ? (ru
                                            ? 'Мольба услышана'
                                            : 'Your prayer is heard')
                                        : (ru
                                            ? 'Пока без ответа'
                                            : 'No answer this time'),
                                    style: t.textTheme.titleLarge),
                                const SizedBox(height: 12),
                                Text(
                                    result.roll == null
                                        ? (ru ? 'Без броска' : 'No roll')
                                        : '${result.roll}',
                                    style: t.textTheme.displayMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: c.secondary)),
                                if (result.roll != null)
                                  Text('d100', style: t.textTheme.labelLarge),
                                const SizedBox(height: 16),
                                Text(
                                    result.success
                                        ? (ru
                                            ? 'Мастер определяет помощь. Повторное обращение — через 7 дней.'
                                            : 'Your GM determines the aid. You can call again in 7 days.')
                                        : (ru
                                            ? 'Повтори попытку после продолжительного отдыха.'
                                            : 'Try again after a long rest.'),
                                    style: t.textTheme.bodyLarge),
                              ])),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(ru ? 'Продолжить' : 'Continue')),
                    ]));
          });
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _usingIntervention = false);
    }
  }
}

/// A way of the channel beside the sun.
class _Way extends StatelessWidget {
  const _Way(
      {super.key,
      required this.glyph,
      required this.label,
      required this.value,
      required this.accent,
      required this.selected,
      required this.onTap,
      this.peek});
  final String glyph, label, value;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;
  final (String, String)? peek;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget w = Pressable(
      onTap: onTap,
      scale: .95,
      selected: selected,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : c.onSurface.withValues(alpha: .07),
              boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: .18), spreadRadius: 6)] : null,
            ),
            child: InstrumentGlyph(glyph, size: 24, color: selected ? onAccent(context) : c.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle(context, size: 12.5).copyWith(color: selected ? c.onSurface : c.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text.rich(unitSpan(value, bigStyle(context).copyWith(fontSize: 15))),
        ]),
      ),
    );
    if (peek != null) w = Peek(title: peek!.$1, text: peek!.$2, child: w);
    return w;
  }
}

/// The sun: rays turn slowly while a charge remains; the beam swings to the
/// chosen way; channelling bursts the rays outwards.
class _Sun extends StatelessWidget {
  const _Sun(
      {super.key,
      required this.spin,
      required this.aimRight,
      required this.spent,
      required this.burst,
      required this.accent,
      required this.left,
      required this.max,
      required this.onTap});
  final Animation<double> spin;
  final bool aimRight, spent;
  final int burst, left, max;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    return Pressable(
      onTap: onTap,
      scale: .94,
      semanticLabel: ru ? 'Направить канал' : 'Channel',
      child: SizedBox.square(
        dimension: 128,
        child: Stack(alignment: Alignment.center, children: [
          Pulse(
            trigger: burst,
            scale: 1.4,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: aimRight ? 0 : math.pi),
              duration: AppMotion.of(context, const Duration(milliseconds: 900)),
              curve: AppMotion.snappyCurve,
              builder: (context, aim, _) => AnimatedBuilder(
                animation: spin,
                builder: (context, _) => CustomPaint(
                  size: const Size.square(136),
                  painter: _SunPainter(accent, spin.value * 2 * math.pi, aim, spent),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: spent
                  ? null
                  : RadialGradient(
                      center: const Alignment(-.2, -.3),
                      colors: [mixColor(accent, .65, c.surfaceContainer), mixColor(accent, .2, c.surfaceContainer)]),
              color: spent ? mixColor(c.onSurface, .07, c.surfaceContainer) : null,
              boxShadow: spent
                  ? null
                  : [
                      BoxShadow(color: accent.withValues(alpha: .14), spreadRadius: 7),
                      BoxShadow(color: accent.withValues(alpha: .5), blurRadius: 34, spreadRadius: -12, offset: const Offset(0, 14)),
                    ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                RollingNumber(left, style: bigStyle(context)),
                if (max > 1)
                  Text(ru ? 'из $max' : 'of $max',
                      style: TextStyle(fontFamily: AppType.body, fontSize: 11, color: c.onSurface.withValues(alpha: .8))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  _SunPainter(this.accent, this.turn, this.aim, this.spent);
  final Color accent;
  final double turn, aim;
  final bool spent;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 160, center = size.center(Offset.zero);
    if (!spent) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(aim);
      final beam = Path()
        ..moveTo(0, 0)
        ..lineTo(80 * s, -40 * s)
        ..arcToPoint(Offset(80 * s, 40 * s), radius: Radius.circular(90 * s))
        ..close();
      canvas.drawPath(
          beam,
          Paint()
            ..shader = RadialGradient(colors: [accent.withValues(alpha: .7), accent.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: Offset.zero, radius: 90 * s)));
      canvas.restore();
    }
    final ray = Paint()
      ..color = accent.withValues(alpha: spent ? .14 : 1)
      ..strokeWidth = 3.4 * s
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final a = i / 18 * 2 * math.pi + turn, r2 = (i.isOdd ? 66 : 76) * s;
      canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * 50 * s,
          center + Offset(math.cos(a), math.sin(a)) * r2, ray);
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) =>
      old.turn != turn || old.aim != aim || old.spent != spent || old.accent != accent;
}

/// A drop of healing light.
class _Drop extends StatelessWidget {
  const _Drop({super.key, required this.small, required this.accent, this.scale = 1});
  final bool small;
  final Color accent;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final k = (small ? .7 : 1) * scale;
    return Container(
      width: 16 * k,
      height: 22 * k,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10 * k), bottom: Radius.circular(8 * k)),
        gradient: RadialGradient(center: const Alignment(-.2, -.3), colors: [Colors.white, accent], stops: const [0, .55]),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .7), blurRadius: 10 * k)],
      ),
    );
  }
}

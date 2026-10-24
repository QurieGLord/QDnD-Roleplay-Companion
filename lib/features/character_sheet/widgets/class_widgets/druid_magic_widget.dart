import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/magic/casting_constraints.dart';
import '../../../../core/magic/class_action_state.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import 'instrument/instrument_kit.dart';
import 'instrument/slot_recovery_instrument.dart';

/// Druid · Wild Shape (prototype `CLASS.druid`). Pick a beast from a short
/// list or shape your own — name, hit points, armour, speed and attacks.
/// In form the instrument becomes the beast's card; the hero's hit points
/// wait underneath and Overview shows the beast's.
class DruidMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const DruidMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<DruidMagicWidget> createState() => _DruidMagicWidgetState();
}

/// A beast the druid can become.
class _Beast {
  const _Beast(this.ru, this.en, this.cr, this.hp, this.ac, this.speedRu, this.speedEn, this.atkRu, this.atkEn,
      {this.swim = false});
  final String ru, en;
  final double cr;
  final int hp, ac;
  final String speedRu, speedEn, atkRu, atkEn;
  final bool swim;
}

const _beasts = [
  _Beast('Анкилозавр', 'Ankylosaurus', 3, 68, 15, '30 фт.', '30 ft.', 'Хвост +7 · 4к6+4, сбивает с ног', 'Tail +7 · 4d6+4, knocks prone'),
  _Beast('Белый медведь', 'Polar bear', 2, 42, 12, '40 фт., плавание 30', '40 ft., swim 30', 'Укус +7 · 1к8+5; когти +7 · 2к6+5', 'Bite +7 · 1d8+5; claws +7 · 2d6+5', swim: true),
  _Beast('Гигантский лось', 'Giant elk', 2, 42, 14, '60 фт.', '60 ft.', 'Таран +6 · 2к6+4; копыта +6 · 4к8+4', 'Ram +6 · 2d6+4; hooves +6 · 4d8+4'),
  _Beast('Бурый медведь', 'Brown bear', 1, 34, 11, '40 фт., лазание 30', '40 ft., climb 30', 'Укус +6 · 1к8+4; когти +6 · 2к6+4', 'Bite +6 · 1d8+4; claws +6 · 2d6+4'),
  _Beast('Лютый волк', 'Dire wolf', 1, 37, 14, '50 фт.', '50 ft.', 'Укус +5 · 2к6+3, сбивает с ног', 'Bite +5 · 2d6+3, knocks prone'),
  _Beast('Гигантский паук', 'Giant spider', 1, 26, 14, '30 фт., лазание 30', '30 ft., climb 30', 'Укус +5 · 1к8+3 и яд 2к8', 'Bite +5 · 1d8+3 and 2d8 poison'),
  _Beast('Гигантская жаба', 'Giant toad', 1, 39, 11, '20 фт., плавание 40', '20 ft., swim 40', 'Укус +4 · 1к10+2, хватает', 'Bite +4 · 1d10+2, grapples', swim: true),
  _Beast('Чёрный медведь', 'Black bear', .5, 19, 11, '40 фт., лазание 30', '40 ft., climb 30', 'Укус +3 · 1к6+2; когти +3 · 2к4+2', 'Bite +3 · 1d6+2; claws +3 · 2d4+2'),
  _Beast('Пантера', 'Panther', .25, 13, 12, '50 фт., лазание 40', '50 ft., climb 40', 'Укус +4 · 1к6+2; когти +4 · 1к4+2', 'Bite +4 · 1d6+2; claws +4 · 1d4+2'),
  _Beast('Волк', 'Wolf', .25, 11, 13, '40 фт.', '40 ft.', 'Укус +4 · 2к4+2, сбивает с ног', 'Bite +4 · 2d4+2, knocks prone'),
  _Beast('Кабан', 'Boar', .25, 11, 11, '40 фт.', '40 ft.', 'Клыки +3 · 1к6+1, натиск', 'Tusk +3 · 1d6+1, charge'),
];

String _cr(double n) => n == .25 ? '¼' : n == .5 ? '½' : '${n.round()}';

class _DruidMagicWidgetState extends State<DruidMagicWidget> {
  bool _busy = false;
  Character get _hero => widget.character;

  bool get _moon {
    final circle = CharacterClassContext(_hero, 'druid').subclass?.toLowerCase();
    return circle == 'moon' || circle == 'circle-of-the-moon' || (circle?.contains('moon') ?? false);
  }

  double get _limit {
    final level = _hero.classLevel('druid');
    if (_moon) return level < 6 ? 1 : (level ~/ 3).toDouble();
    return level < 4 ? .25 : level < 8 ? .5 : 1;
  }

  bool get _hasNaturalRecovery {
    final owner = CharacterClassContext(_hero, 'druid');
    return owner.level >= 2 &&
        _hero.features.any((f) => owner.canUseFeature(f) && f.id.replaceAll('_', '-') == 'natural-recovery');
  }

  Future<void> _become(String name, int hp, Map<String, dynamic> details, {bool remember = false}) async {
    if (_busy) return;
    final ru = instrumentRu(context);
    if (!CastingConstraints.coreDruid(_hero, 20) && _hero.wildShapeCharges < 1) {
      HapticFeedback.heavyImpact();
      AppSnackBar.warning(context, AppLocalizations.of(context)!.noWildShapeCharges);
      return;
    }
    setState(() => _busy = true);
    try {
      final changed = await ClassSessionActionsService.wildShape(_hero, true,
          hp: hp, name: name, details: details, remember: remember);
      if (mounted && changed) {
        HapticFeedback.heavyImpact();
        widget.onStateChanged();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context,
            ru ? 'Не удалось принять облик. Проверь состояние и остаток использований.' : 'Could not transform. Check your conditions and remaining uses.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revert() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ClassSessionActionsService.wildShape(_hero, false);
      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onStateChanged();
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, instrumentRu(context) ? 'Не удалось завершить облик.' : 'Could not end Wild Shape.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _health(bool healing) async {
    final ru = instrumentRu(context);
    final n = await showNumberKeypad(context,
        kicker: _hero.beastName,
        title: healing ? (ru ? 'Лечение облика' : 'Heal the form') : (ru ? 'Урон облику' : 'Damage to the form'));
    if (n == null || !mounted) return;
    final hero = _hero.currentHp;
    try {
      await GameplayActionsService.changeHealth(_hero, n, healing: healing);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      widget.onStateChanged();
      if (!healing && !_hero.isWildShaped) {
        final over = hero - _hero.currentHp;
        AppSnackBar.info(context,
            ru ? (over > 0 ? 'Облик спал · $over урона герою' : 'Облик спал') : (over > 0 ? 'The form drops · $over to the hero' : 'The form drops'));
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a3 = accentOf(context, 3);
    final level = _hero.classLevel('druid');
    final children = <Widget>[
      if (level < 2)
        LockedInstrument(
            title: ru ? 'Дикий облик' : 'Wild Shape',
            level: 2,
            what: ru ? 'Превращение в зверя' : 'Turning into a beast',
            accent: a3)
      else
        // The hero becomes the beast and back as one morphing block.
        MorphSwitcher(
          child: KeyedSubtree(
            key: ValueKey(_hero.isWildShaped ? 'beast' : 'human'),
            child: _hero.isWildShaped
                ? _beastCard(context, ru, locale, a3, level)
                : _humanForm(context, ru, a3, level),
          ),
        ),
      if (_hasNaturalRecovery)
        SlotRecoveryInstrument(
          hero: _hero,
          classId: 'druid',
          title: ru ? 'Природное восстановление' : 'Natural Recovery',
          accent: a3,
          used: _hero.naturalRecoveryUsed,
          about: InstrumentAbout(
              title: AppLocalizations.of(context)!.naturalRecovery,
              kicker: ru ? 'Раз в день · короткий отдых' : 'Once a day · short rest',
              paragraphs: [
                ru
                    ? 'Во время короткого отдыха вы возвращаете потраченные ячейки, сумма кругов которых не больше половины уровня друида (с округлением вверх). Ячейки 6 круга и выше так не вернуть.'
                    : 'During a short rest you recover spent slots whose circles add up to half your druid level (rounded up). No slot of 6th level or higher.'
              ],
              how: ru
                  ? 'Коснитесь тусклых кристаллов — потраченных ячеек. «Вернуть» зажжёт их снова.'
                  : 'Tap the dim crystals — the spent slots. “Recover” lights them again.'),
          onChanged: () => setState(widget.onStateChanged),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }

  InstrumentAbout _about(bool ru) => InstrumentAbout(
      title: ru ? 'Дикий облик' : 'Wild Shape',
      kicker: ru ? '${_moon ? 'Бонусное действие' : 'Действие'} · короткий отдых' : '${_moon ? 'Bonus action' : 'Action'} · short rest',
      paragraphs: [
        ru
            ? 'Вы превращаетесь в зверя, которого видели. У облика свои ОЗ, КД и атаки; Интеллект, Мудрость и Харизма остаются вашими.'
            : 'You turn into a beast you have seen. The form has its own hit points, AC and attacks; your Intelligence, Wisdom and Charisma remain.',
        ru
            ? 'Когда ОЗ облика падают до 0, вы возвращаетесь в свой облик, а лишний урон переходит на ваши ОЗ.'
            : 'When the form drops to 0 hit points you revert, and excess damage carries over to you.'
      ],
      how: ru
          ? '«Принять облик» — выбрать зверя из списка или описать свой. Урон и лечение облика вводятся цифрами.'
          : '“Take a form” — pick a beast or describe your own. Damage and healing are typed as numbers.');

  Widget _humanForm(BuildContext context, bool ru, Color a3, int level) {
    final unlimited = CastingConstraints.coreDruid(_hero, 20);
    final left = _hero.wildShapeCharges;
    final mine = ClassActionState.forms(_hero);
    return Instrument(
      key: const ValueKey('druid-wild-shape'),
      accent: a3,
      title: ru ? 'Дикий облик' : 'Wild Shape',
      about: _about(ru),
      background: _Blob(accent: a3, beast: false),
      trailing: RestChip(
          short: true,
          onRestore: unlimited
              ? null
              : () => restoreValue(context,
                  current: left,
                  max: 2,
                  write: (v) => GameplayActionsService.serializeCharacter(_hero, () async {
                    final before = _hero.wildShapeCharges;
                    _hero.wildShapeCharges = v;
                    try {
                      await StorageService.saveCharacter(_hero);
                    } catch (_) {
                      _hero.wildShapeCharges = before;
                      rethrow;
                    }
                  }),
                  done: () => setState(widget.onStateChanged))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          unlimited ? Text('∞', style: hugeStyle(context)) : Flexible(flex: 3, child: BigCount(left, of: 2)),
          const Spacer(),
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _Leaf(on: unlimited || i < left, accent: a3),
          ],
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          InstrumentChip('${ru ? 'ПО' : 'CR'} ≤ ${_cr(_limit)}',
              peek: (
                ru ? 'Предел облика' : 'Form limit',
                ru
                    ? 'ПО до ${_cr(_limit)}${level < 4 ? ', без плавания' : ''}${level < 8 ? ' и полёта' : ''}'
                    : 'CR up to ${_cr(_limit)}${level < 4 ? ', no swimming' : ''}${level < 8 ? ' or flying' : ''}'
              )),
          InstrumentChip(ru ? '${level ~/ 2} ч' : '${level ~/ 2} h',
              peek: (ru ? 'Длительность' : 'Duration', ru ? 'До ${level ~/ 2} ч, или пока ОЗ облика не упадут до 0' : 'Up to ${level ~/ 2} h, or until the form drops to 0 HP')),
          InstrumentChip(_moon ? (ru ? 'бонусное' : 'bonus') : (ru ? 'действие' : 'action')),
        ]),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in mine)
              Pressable(
                onTap: _busy ? null : () => _become('${f['name']}', (f['hp'] as num?)?.toInt() ?? 1, f),
                scale: .95,
                semanticLabel: '${f['name']}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: ShapeDecoration(shape: const StadiumBorder(), color: a3.withValues(alpha: .16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    InstrumentGlyph('paw', size: 15, color: a3),
                    const SizedBox(width: 6),
                    Text('${f['name']}', style: labelStyle(context, size: 13)),
                  ]),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        GoButton(
          key: const ValueKey('druid-transform'),
          label: ru ? 'Принять облик' : 'Take a form',
          glyph: 'paw',
          accent: a3,
          onTap: !_busy && (unlimited || left > 0) ? () => _showForms(context) : null,
        ),
      ]),
    );
  }

  Widget _beastCard(BuildContext context, bool ru, String locale, Color a3, int level) {
    final c = Theme.of(context).colorScheme;
    final details = (() {
      try {
        return ClassActionState.beast(_hero) ?? const <String, dynamic>{};
      } catch (_) {
        return const <String, dynamic>{};
      }
    })();
    final current = _hero.beastCurrentHp ?? 0, maximum = math.max(1, _hero.beastMaxHp ?? 1);
    final ac = details['ac'], speed = '${details['speed'] ?? ''}', atk = '${details['atk'] ?? ''}', cr = details['cr'];
    final heal = AppPaletteRoles.heal(context);
    return Instrument(
      key: const ValueKey('druid-beast'),
      accent: a3,
      title: ru ? 'Дикий облик' : 'Wild Shape',
      about: _about(ru),
      background: _Blob(accent: a3, beast: true),
      trailing: InstrumentChip(ru ? 'до ${level ~/ 2} ч' : 'up to ${level ~/ 2} h'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: mixColor(a3, .22, c.surfaceContainer), borderRadius: BorderRadius.circular(18)),
            child: InstrumentGlyph('paw', size: 30, color: a3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hero.beastName?.isNotEmpty == true ? _hero.beastName! : (ru ? 'Зверь' : 'Beast'),
                  style: const TextStyle(fontFamily: AppType.display, fontSize: 22, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -.2)),
              const SizedBox(height: 4),
              Wrap(spacing: 10, children: [
                if (ac != null) _stat(context, ru ? 'КД' : 'AC', '$ac'),
                if (speed.isNotEmpty) Text(speed.split(',').first, style: hintStyle(context).copyWith(fontSize: 12)),
                if (cr != null && '$cr'.isNotEmpty) _stat(context, ru ? 'ПО' : 'CR', '$cr'),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(flex: 3, child: BigCount(current, of: maximum)),
          const Spacer(),
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Peek(
            title: ru ? 'Герой под обликом' : 'The hero underneath',
            text: ru ? 'Урон сверх ОЗ облика переходит герою, облик спадает' : 'Damage beyond the form’s HP carries over and the form drops',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: ShapeDecoration(shape: const StadiumBorder(), color: c.onSurface.withValues(alpha: .07)),
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
                InstrumentGlyph('heart', size: 15, color: accentOf(context, 0)),
                const SizedBox(width: 6),
                RollingNumber(_hero.currentHp, style: bigStyle(context).copyWith(fontSize: 15)),
                Text(' / ${_hero.maxHp}', style: hintStyle(context).copyWith(fontSize: 12)),
              ]),
            ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TrailBar(value: (current / maximum).clamp(0, 1), color: a3, background: c.onSurface.withValues(alpha: .09), height: 12),
        if (atk.isNotEmpty) ...[
          const SizedBox(height: 12),
          Peek(
            title: ru ? 'Атаки' : 'Attacks',
            text: atk,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .05), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                InstrumentGlyph('paw', size: 16, color: a3),
                const SizedBox(width: 8),
                Expanded(child: Text(atk.split(';').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle(context, size: 13))),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TileRow(children: [
          GoButton(label: ru ? 'Урон' : 'Damage', glyph: 'minus', accent: a3, soft: true, onTap: () => _health(false)),
          GoButton(label: ru ? 'Лечение' : 'Heal', glyph: 'plus', accent: heal, soft: true, onTap: () => _health(true)),
        ]),
        const SizedBox(height: 10),
        GhostButton(label: ru ? 'Вернуться в облик героя' : 'Back to the hero', onTap: _busy ? null : _revert),
      ]),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: hintStyle(context).copyWith(fontSize: 12)),
        TextSpan(text: value, style: bigStyle(context).copyWith(fontSize: 13)),
      ]));

  Future<void> _showForms(BuildContext context) async {
    final ru = instrumentRu(context);
    final level = _hero.classLevel('druid');
    final ok = _beasts.where((b) => b.cr <= _limit && (!b.swim || level >= 4)).toList();
    final mine = ClassActionState.forms(_hero);
    final picked = await showCompanionSheet<Object>(context, builder: (sheet) {
      Widget row(String name, int hp, int? ac, String? cr, Object value) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Pressable(
              onTap: () => Navigator.pop(sheet, value),
              scale: .98,
              semanticLabel: name,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Theme.of(sheet).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: accentOf(sheet, 3).withValues(alpha: .22), borderRadius: BorderRadius.circular(14)),
                    child: InstrumentGlyph('paw', size: 22, color: accentOf(sheet, 3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: labelStyle(sheet, size: 15)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 10, children: [
                        _stat(sheet, ru ? 'ОЗ' : 'HP', '$hp'),
                        if (ac != null) _stat(sheet, ru ? 'КД' : 'AC', '$ac'),
                        if (cr != null) _stat(sheet, ru ? 'ПО' : 'CR', cr),
                      ]),
                    ]),
                  ),
                  LineIcon('forward', size: 18, color: Theme.of(sheet).colorScheme.onSurfaceVariant),
                ]),
              ),
            ),
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${ru ? 'Друид' : 'Druid'} · ${ru ? 'Дикий облик' : 'Wild Shape'}',
            style: TextStyle(fontFamily: AppType.body, fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(sheet).colorScheme.secondary)),
        const SizedBox(height: 8),
        SheetHeading(ru ? 'Кем стать?' : 'What to become?'),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 14),
          _miniHead(sheet, ru ? 'Мои облики' : 'My forms'),
          for (final f in mine) row('${f['name']}', (f['hp'] as num?)?.toInt() ?? 1, (f['ac'] as num?)?.toInt(), f['cr'] == null ? null : '${f['cr']}', f),
        ],
        const SizedBox(height: 14),
        _miniHead(sheet, '${ru ? 'Звери · ПО до' : 'Beasts · CR up to'} ${_cr(_limit)}'),
        for (final b in ok) row(ru ? b.ru : b.en, b.hp, b.ac, _cr(b.cr), b),
        const SizedBox(height: 8),
        ToneButton(
            label: ru ? 'Свой облик' : 'My own form',
            icon: const LineIcon('plus', size: 20),
            kind: ToneKind.tonal,
            height: 52,
            expand: true,
            onPressed: () => Navigator.pop(sheet, 'own')),
      ]);
    });
    if (!mounted || picked == null) return;
    if (picked is _Beast) {
      await _become(ru ? picked.ru : picked.en, picked.hp,
          {'ac': picked.ac, 'speed': ru ? picked.speedRu : picked.speedEn, 'atk': ru ? picked.atkRu : picked.atkEn, 'cr': _cr(picked.cr)});
    } else if (picked is Map<String, dynamic>) {
      await _become('${picked['name']}', (picked['hp'] as num?)?.toInt() ?? 1, picked);
    } else if (picked == 'own' && context.mounted) {
      final own = await showCompanionSheet<Map<String, dynamic>>(context, builder: (_) => const _OwnForm());
      if (own != null && mounted) await _become('${own['name']}', own['hp'] as int, own, remember: true);
    }
  }

  Widget _miniHead(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .9)),
      );
}

/// Shape your own beast: the card at the top answers as you type.
class _OwnForm extends StatefulWidget {
  const _OwnForm();
  @override
  State<_OwnForm> createState() => _OwnFormState();
}

class _OwnFormState extends State<_OwnForm> {
  final _name = TextEditingController(), _speed = TextEditingController(text: '30'), _atk = TextEditingController();
  int _hp = 20, _ac = 12;
  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _speed.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _speed.dispose();
    _atk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final a3 = accentOf(context, 3);
    final speed = _speed.text.trim().isEmpty ? '' : '${_speed.text.trim()}${RegExp(r'^\d+$').hasMatch(_speed.text.trim()) ? (ru ? ' фт.' : ' ft.') : ''}';
    InputDecoration deco(String label, [String? hint]) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeading(ru ? 'Свой облик' : 'Your own form'),
      const SizedBox(height: 14),
      Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [mixColor(a3, .18, c.surfaceContainerLow), c.surfaceContainerLow])),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -80, top: -70, width: 200, height: 180, child: _Blob(accent: a3, beast: true, plain: true)),
          Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: a3.withValues(alpha: .22), borderRadius: BorderRadius.circular(14)),
              child: InstrumentGlyph('paw', size: 22, color: a3),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name.text.trim().isEmpty ? (ru ? 'Безымянный зверь' : 'A nameless beast') : _name.text.trim(),
                    style: const TextStyle(fontFamily: AppType.display, fontSize: 22, fontWeight: FontWeight.w600, height: 1.15)),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${ru ? 'ОЗ' : 'HP'} ', style: hintStyle(context)),
                  RollingNumber(_hp, style: bigStyle(context).copyWith(fontSize: 14)),
                  const SizedBox(width: 10),
                  Text('${ru ? 'КД' : 'AC'} ', style: hintStyle(context)),
                  RollingNumber(_ac, style: bigStyle(context).copyWith(fontSize: 14)),
                ]),
                if (speed.isNotEmpty) Text(speed, style: hintStyle(context).copyWith(fontSize: 12)),
              ]),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: deco(ru ? 'Название' : 'Name', ru ? 'Например, лютый барсук' : 'e.g. a dire badger')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Stepper(label: ru ? 'ОЗ' : 'HP', value: _hp, max: 400, onChanged: (v) => setState(() => _hp = v))),
        const SizedBox(width: 10),
        Expanded(child: _Stepper(label: ru ? 'КД' : 'AC', value: _ac, max: 30, onChanged: (v) => setState(() => _ac = v))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: _speed, decoration: deco(ru ? 'Скорость' : 'Speed', ru ? '30, лазание 30' : '30, climb 30')),
      const SizedBox(height: 10),
      TextField(controller: _atk, decoration: deco(ru ? 'Атаки' : 'Attacks', ru ? 'Укус +4 · 1к6+2' : 'Bite +4 · 1d6+2')),
      const SizedBox(height: 14),
      ToneButton(
        kind: ToneKind.primary,
        height: 54,
        expand: true,
        icon: const InstrumentGlyph('paw', size: 20),
        label: ru ? 'Принять облик' : 'Take this form',
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, {
                  'name': _name.text.trim(),
                  'hp': _hp,
                  'ac': _ac,
                  'speed': speed,
                  'atk': _atk.text.trim(),
                }),
      ),
    ]);
  }
}

/// A stepper that repeats while held, faster the longer it is held.
class _Stepper extends StatefulWidget {
  const _Stepper({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final int value, max;
  final ValueChanged<int> onChanged;
  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  Timer? _t;
  int _n = 0;
  void _go(int d) {
    final next = (widget.value + d).clamp(1, widget.max);
    if (next == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _start(int d) {
    _n = 0;
    _go(d);
    void again() {
      _t = Timer(Duration(milliseconds: _n++ < 4 ? 260 : 70), () {
        _go(d);
        again();
      });
    }

    again();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget button(int d) => Listener(
          onPointerDown: (_) => _start(d),
          onPointerUp: (_) => _t?.cancel(),
          onPointerCancel: (_) => _t?.cancel(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
            child: Text(d < 0 ? '−' : '+', style: bigStyle(context).copyWith(fontSize: 20)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Padding(padding: const EdgeInsets.only(left: 6, right: 6), child: Text(widget.label, style: hintStyle(context).copyWith(fontSize: 12, fontWeight: FontWeight.w600))),
        button(-1),
        Expanded(child: Center(child: RollingNumber(widget.value, style: bigStyle(context).copyWith(fontSize: 26)))),
        button(1),
      ]),
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.on, required this.accent});
  final bool on;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: -.21,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 28,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(topRight: Radius.circular(28), bottomLeft: Radius.circular(28)),
          gradient: on ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, mixColor(accent, .5, accentOf(context, 4))]) : null,
          border: on ? null : Border.all(color: c.outline, width: 2),
        ),
      ),
    );
  }
}

/// The organic shape behind the instrument; it morphs and grows into the
/// beast and keeps breathing slowly.
class _Blob extends StatefulWidget {
  const _Blob({required this.accent, required this.beast, this.plain = false});
  final Color accent;
  final bool beast, plain;
  @override
  State<_Blob> createState() => _BlobState();
}

class _BlobState extends State<_Blob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_c.isAnimating) _c.repeat(reverse: true, count: 2);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blob = AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        double l(double a, double b) => a + (b - a) * t;
        return Transform.rotate(
          angle: t * .3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.elliptical(l(42, 40) * 2.6, l(48, 42) * 2.4),
                topRight: Radius.elliptical(l(58, 60) * 2.6, l(42, 55) * 2.4),
                bottomRight: Radius.elliptical(l(55, 62) * 2.6, l(58, 45) * 2.4),
                bottomLeft: Radius.elliptical(l(45, 38) * 2.6, l(52, 58) * 2.4),
              ),
              gradient: RadialGradient(
                  center: const Alignment(-.2, -.2),
                  colors: [widget.accent.withValues(alpha: .6), widget.accent.withValues(alpha: .1)],
                  stops: const [0, .7]),
            ),
          ),
        );
      },
    );
    if (widget.plain) return Opacity(opacity: .55, child: blob);
    return Stack(children: [
      AnimatedPositioned(
        duration: AppMotion.of(context, const Duration(milliseconds: 900)),
        curve: AppMotion.gentleCurve,
        right: widget.beast ? -30 : -70,
        top: widget.beast ? -40 : -80,
        width: widget.beast ? 320 : 260,
        height: widget.beast ? 300 : 240,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          opacity: widget.beast ? .75 : .55,
          child: blob,
        ),
      ),
    ]);
  }
}

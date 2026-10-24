import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/constants/ranger_options.dart';
import '../../../../core/magic/class_spell_grants.dart';
import '../../../../core/magic/companion_state.dart';
import '../../../../core/magic/spell_use.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/class_session_actions_service.dart';
import '../../../../core/services/feature_service.dart';
import '../../../../core/services/feature_slot_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/companion_editor.dart';
import '../../../../shared/widgets/feature_slot_sheet.dart';
import '../../../../shared/widgets/spell_cast_sheet.dart';
import 'instrument/instrument_kit.dart';

/// Ranger (prototype `CLASS.ranger`). A scope that locks onto the marked
/// quarry, its extra d6 rolling beside the name; Colossus Slayer and
/// Primeval Awareness act in place; the ranger's lore turns over to tell.
class RangerSurvivalWidget extends StatefulWidget {
  final Character character;
  final CharacterFeature? primevalAwareness;
  final VoidCallback? onChanged;

  const RangerSurvivalWidget({
    super.key,
    required this.character,
    this.primevalAwareness,
    this.onChanged,
  });

  @override
  State<RangerSurvivalWidget> createState() => _RangerSurvivalWidgetState();
}

class _RangerSurvivalWidgetState extends State<RangerSurvivalWidget> {
  bool _busy = false;
  int? _markRoll, _slayerRoll;
  int _markKey = 0, _slayerKey = 0, _lock = 0;
  bool _slayerUsed = false;
  final _flipped = <String>{};

  Character get _hero => widget.character;
  CharacterClassContext get _owner => CharacterClassContext(_hero, 'ranger');

  Future<void> _session(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        HapticFeedback.selectionClick();
        widget.onChanged?.call();
      }
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nameTarget({required bool moving}) async {
    final ru = instrumentRu(context);
    final controller = TextEditingController(text: moving ? '' : (_hero.huntersMarkTarget ?? ''));
    final name = await showCompanionSheet<String>(context, builder: (sheet) {
      final c = Theme.of(sheet).colorScheme;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeading(moving ? (ru ? 'Новая цель' : 'New quarry') : (ru ? 'Цель метки' : 'Marked quarry'),
            subtitle: moving ? (ru ? 'Бонусным действием, без новой ячейки' : 'A bonus action, no new slot') : null),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: ru ? 'Кого вы отметили' : 'Who you marked',
              filled: true,
              fillColor: c.surfaceContainerLow,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
          onSubmitted: (v) => Navigator.pop(sheet, v),
        ),
        const SizedBox(height: 14),
        ToneButton(
            kind: ToneKind.primary,
            height: 54,
            expand: true,
            label: moving ? (ru ? 'Перенести метку' : 'Move the mark') : (ru ? 'Готово' : 'Done'),
            onPressed: () => Navigator.pop(sheet, controller.text)),
      ]);
    });
    controller.dispose();
    if (name == null || !mounted) return;
    await _session(() => ClassSessionActionsService.huntersMark(_hero, target: name.trim()));
    if (mounted) setState(() => _lock++);
  }

  /// Favored enemies or terrains, as many as the ranger has chosen so far.
  Future<void> _editLore({required bool enemies}) async {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final options = enemies ? RangerOptions.favoredEnemies : RangerOptions.naturalExplorers;
    final current = enemies ? _hero.favoredEnemies : _hero.naturalExplorers;
    final limit = current.isEmpty ? 1 : current.length;
    final picked = <String>[...current];
    final accent = enemies ? accentOf(context, 0) : accentOf(context, 3);
    final saved = await showCompanionSheet<List<String>>(context, builder: (sheet) {
      return StatefulBuilder(builder: (sheet, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeading(enemies ? (ru ? 'Избранный враг' : 'Favored enemy') : (ru ? 'Исследуемая местность' : 'Favored terrain'),
              subtitle: ru ? 'Выберите $limit · ${picked.length} из $limit' : 'Choose $limit · ${picked.length} of $limit'),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in options.entries)
              Pressable(
                key: ValueKey('ranger-lore-${e.key}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setSheet(() {
                    if (picked.contains(e.key)) {
                      picked.remove(e.key);
                    } else {
                      if (picked.length >= limit) picked.removeAt(0);
                      picked.add(e.key);
                    }
                  });
                },
                selected: picked.contains(e.key),
                scale: .94,
                semanticLabel: e.value[locale] ?? e.key,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    color: picked.contains(e.key) ? accent : Theme.of(sheet).colorScheme.onSurface.withValues(alpha: .07),
                  ),
                  child: Text(e.value[locale] ?? e.key,
                      style: labelStyle(sheet, size: 14).copyWith(
                          color: picked.contains(e.key) ? Theme.of(sheet).colorScheme.surface : null)),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          ToneButton(
              kind: ToneKind.primary,
              height: 54,
              expand: true,
              label: ru ? 'Сохранить' : 'Save',
              onPressed: picked.length == limit ? () => Navigator.pop(sheet, picked) : null),
        ]);
      });
    });
    if (saved == null || !mounted) return;
    await _session(() => GameplayActionsService.serializeCharacter(_hero, () async {
          final before = (List<String>.of(_hero.favoredEnemies), List<String>.of(_hero.naturalExplorers));
          if (enemies) {
            _hero.favoredEnemies = saved;
          } else {
            _hero.naturalExplorers = saved;
          }
          try {
            await StorageService.saveCharacter(_hero);
          } catch (_) {
            _hero.favoredEnemies = before.$1;
            _hero.naturalExplorers = before.$2;
            rethrow;
          }
        }));
  }

  Future<void> _cast() async {
    final spell = ClassSpellGrants.spell('hunters-mark');
    if (spell == null) return;
    final cast = await showSpellCastSheet(context, _hero, spell);
    if (!mounted || !cast) return;
    widget.onChanged?.call();
    setState(() => _lock++);
    if (_hero.isHuntersMarkActive && (_hero.huntersMarkTarget ?? '').isEmpty) await _nameTarget(moving: false);
  }

  CharacterFeature? _feature(List<String> tokens) => _hero.features
      .where((f) => _owner.canUseFeature(f) && tokens.any((t) => f.id.toLowerCase().replaceAll('_', '-').contains(t)))
      .firstOrNull;

  InstrumentAbout _about(CharacterFeature f, String locale, [String? how]) =>
      InstrumentAbout(title: f.getName(locale), paragraphs: f.getDescription(locale).split(RegExp(r'\n\s*\n')), how: how);

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a3 = accentOf(context, 3), a1 = accentOf(context, 1), a4 = accentOf(context, 4), a0 = accentOf(context, 0);
    final level = _owner.level;
    final blocks = <Widget>[];

    final mark = ClassSpellGrants.spell('hunters-mark');
    var knowsMark = _hero.isHuntersMarkActive;
    try {
      knowsMark = knowsMark || mark != null && SpellUse.visible(_hero).any((s) => s.id == mark.id);
    } on FormatException {
      // A future personal spellbook must not break unrelated class controls.
    }
    // Hunter's Mark is a spell the ranger learns, not a feature that
    // arrives by itself: the instrument appears only once it is known.
    if (knowsMark) blocks.add(_markInstrument(context, ru, a3));

    final slayer = _feature(['colossus']);
    final primeval = widget.primevalAwareness;
    final cells = <Widget>[
      if (slayer != null)
        CellTile(
          key: const ValueKey('ranger-colossus'),
          accent: a1,
          onTap: () {
            if (_slayerUsed) {
              HapticFeedback.selectionClick();
              setState(() {
                _slayerUsed = false;
                _slayerRoll = null;
              });
              return;
            }
            setState(() {
              _slayerRoll = math.Random().nextInt(8) + 1;
              _slayerKey++;
              _slayerUsed = true;
            });
          },
          peek: (slayer.getName(locale), ru ? 'Раз в ход: +1к8 урона по цели, которая уже ранена' : 'Once a turn: +1d8 damage against a wounded target'),
          children: [
            Row(children: [
              Opacity(opacity: _slayerUsed ? .4 : 1, child: InstrumentGlyph('peaks', size: 26, color: a1)),
              const Spacer(),
              TumbleDie(shape: DieShape.d8, label: _slayerRoll?.toString() ?? (ru ? 'к8' : 'd8'), accent: a1, rollKey: _slayerKey, sides: 8, natural: _slayerRoll, size: 42),
            ]),
            InstrumentCap(ru ? 'Колоссы' : 'Colossus', accent: a1, about: _about(slayer, locale)),
            InstrumentHint(_slayerUsed ? (ru ? 'новый ход ↺' : 'new turn ↺') : (ru ? 'раз в ход' : 'once a turn')),
          ],
        )
      else if (level < 3)
        LockedCell(title: ru ? 'Колоссы' : 'Colossus', level: 3, accent: a1),
      if (primeval != null)
        CellTile(
          key: const ValueKey('ranger-primeval'),
          accent: a4,
          onTap: () async {
            if (!FeatureSlotActionsService.supportsPrimeval(_hero, primeval)) {
              showInstrumentAbout(context, _about(primeval, locale), a4);
              return;
            }
            final changed = await showPrimevalAwarenessSheet(context, _hero, primeval);
            if (mounted && changed == true) setState(() => widget.onChanged?.call());
          },
          peek: (primeval.getName(locale), primeval.getDescription(locale).split('\n').first),
          children: [
            _Radar(accent: a4),
            InstrumentCap(ru ? 'Чутьё' : 'Awareness', accent: a4, about: _about(primeval, locale)),
            InstrumentHint(ru ? 'ячейка заклинания' : 'a spell slot'),
          ],
        )
      else if (level < 3)
        LockedCell(title: ru ? 'Чутьё' : 'Awareness', level: 3, accent: a4),
    ];
    if (cells.isNotEmpty) blocks.add(TileRow(children: cells));

    final tactics = _hero.features.where((f) {
      if (!_owner.canUseFeature(f)) return false;
      final id = f.id.toLowerCase().replaceAll('_', '-');
      if (id.contains('colossus') || {'hunters-prey', 'hunter-s-prey', 'defensive-tactics', 'superior-hunters-defense', 'multiattack'}.contains(id)) return false;
      return ['horde', 'giant-killer', 'escape', 'multiattack-defense', 'steel-will', 'volley', 'whirlwind', 'evasion', 'stand-against', 'uncanny-dodge'].any(id.contains);
    }).toList();
    if (tactics.isNotEmpty) {
      blocks.add(Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in tactics) InstrumentChip(t.getName(locale), glyph: 'target', onTap: () => showInstrumentAbout(context, _about(t, locale), a3)),
      ]));
    }

    final lore = <Widget>[
      if (_hero.favoredEnemies.isNotEmpty)
        _FlipCard(
          key: const ValueKey('ranger-favored-enemy'),
          flipped: _flipped.contains('foe'),
          accent: a0,
          glyph: 'skull',
          cap: ru ? 'Избранный враг' : 'Favored enemy',
          names: [for (final e in _hero.favoredEnemies) RangerOptions.favoredEnemies[e]?[locale] ?? e],
          back: [
            ('track', ru ? 'Выслеживание с преимуществом' : 'Tracking with advantage'),
            ('book', ru ? 'Знания о нём с преимуществом' : 'Lore with advantage'),
          ],
          onTap: () => setState(() => _flipped.contains('foe') ? _flipped.remove('foe') : _flipped.add('foe')),
          onEdit: () => _editLore(enemies: true),
        ),
      if (_hero.naturalExplorers.isNotEmpty)
        _FlipCard(
          key: const ValueKey('ranger-natural-explorer'),
          flipped: _flipped.contains('land'),
          accent: a3,
          glyph: 'tree',
          cap: ru ? 'Местность' : 'Terrain',
          names: [for (final e in _hero.naturalExplorers) RangerOptions.naturalExplorers[e]?[locale] ?? e],
          back: [
            ('tree', ru ? 'Группа не сбивается' : 'Your group never gets lost'),
            ('track', ru ? 'Двойная добыча' : 'Twice the forage'),
            ('eye', ru ? 'Начеку в пути' : 'Alert on the road'),
          ],
          onTap: () => setState(() => _flipped.contains('land') ? _flipped.remove('land') : _flipped.add('land')),
          onEdit: () => _editLore(enemies: false),
        ),
    ];
    if (lore.isNotEmpty) blocks.add(TileRow(children: lore));

    final hide = _feature(['hide-in-plain-sight']);
    if (level >= 10 && hide != null) {
      blocks.add(SwitchRow(
        label: hide.getName(locale),
        glyph: 'hood',
        value: _hero.isHiddenInPlainSight,
        accent: a3,
        onChanged: _busy
            ? null
            : (v) => _session(() async {
                  await ClassSessionActionsService.hidden(_hero, v, rangerCamouflage: true);
                  if (!mounted || !v) return;
                  AppSnackBar.info(this.context, AppLocalizations.of(this.context)!.hideSpentMinute);
                }),
        peek: (hide.getName(locale), hide.getDescription(locale).split('\n').first),
      ));
    }

    bool companion = false;
    CompanionState? state;
    try {
      state = CompanionState.read(_hero);
      companion = state != null;
    } catch (_) {
      companion = true;
    }
    if (companion || FeatureService.matchesSubclass('beast master', _owner.subclass)) {
      blocks.add(_companion(context, ru, a3, state));
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < blocks.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        blocks[i],
      ]
    ]);
  }

  Widget _markInstrument(BuildContext context, bool ru, Color a3) {
    final on = _hero.isHuntersMarkActive;
    final target = (_hero.huntersMarkTarget ?? '').trim();
    final c = Theme.of(context).colorScheme;
    final spell = ClassSpellGrants.spell('hunters-mark');
    return Instrument(
      key: const ValueKey('ranger-hunters-mark'),
      accent: a3,
      title: ru ? 'Метка охотника' : 'Hunter’s Mark',
      about: InstrumentAbout(
          title: spell?.getName(ru ? 'ru' : 'en') ?? (ru ? 'Метка охотника' : 'Hunter’s Mark'),
          kicker: ru ? 'Заклинание 1 круга · бонусное действие · концентрация' : 'Level 1 spell · bonus action · concentration',
          paragraphs: (spell?.getDescription(ru ? 'ru' : 'en') ?? '').split(RegExp(r'\n\s*\n')),
          how: ru
              ? '«Отметить цель» — наложить заклинание. Кость метки бросается касанием, «Цель пала» переносит метку.'
              : '“Mark a target” casts the spell. Tap the die to roll it; “Quarry fell” moves the mark.'),
      trailing: InstrumentChip(on ? (ru ? 'концентрация' : 'concentration') : (ru ? 'без цели' : 'no target')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        Row(children: [
          Pulse(trigger: _lock, scale: 1.15, child: _Scope(locked: on, accent: a3, danger: accentOf(context, 0))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (on)
                Pressable(
                  onTap: _busy ? null : () => _nameTarget(moving: false),
                  scale: .97,
                  semanticLabel: target,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: target.isEmpty ? (ru ? 'Назовите цель' : 'Name the quarry') : target),
                      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: const EdgeInsets.only(left: 4), child: LineIcon('forward', size: 18, color: c.onSurfaceVariant))),
                    ]),
                    style: TextStyle(fontFamily: AppType.display, fontSize: 22, height: 1.15, fontWeight: FontWeight.w600, color: target.isEmpty ? c.onSurfaceVariant : c.onSurface),
                  ),
                )
              else
                Text(ru ? 'Нет цели' : 'No quarry',
                    style: TextStyle(fontFamily: AppType.display, fontSize: 22, height: 1.15, fontWeight: FontWeight.w600, color: c.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (on)
                Row(children: [
                  Pressable(
                    onTap: () => setState(() {
                      _markRoll = math.Random().nextInt(6) + 1;
                      _markKey++;
                    }),
                    scale: .9,
                    semanticLabel: ru ? 'Урон метки' : 'Mark damage',
                    child: TumbleDie(shape: DieShape.d6, label: _markRoll?.toString() ?? (ru ? 'к6' : 'd6'), accent: a3, rollKey: _markKey, sides: 6, natural: _markRoll, size: 42),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: InstrumentHint(ru ? '+1к6 к урону по цели' : '+1d6 damage to the quarry')),
                ])
              else
                InstrumentHint(ru ? 'заклинание 1 круга · бонусное' : 'a level 1 spell · bonus action'),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (on)
          TileRow(children: [
            GoButton(label: ru ? 'Цель пала' : 'Quarry fell', glyph: 'target', accent: a3, soft: true, onTap: _busy ? null : () => _nameTarget(moving: true)),
            GhostButton(label: ru ? 'Снять' : 'Drop', onTap: _busy ? null : () => _session(() => ClassSessionActionsService.huntersMark(_hero, drop: true))),
          ])
        else
          GoButton(key: const ValueKey('ranger-mark-cast'), label: ru ? 'Отметить цель' : 'Mark a target', glyph: 'wand', accent: a3, onTap: spell == null ? null : _cast),
      ]),
    );
  }

  Widget _companion(BuildContext context, bool ru, Color a3, CompanionState? state) {
    final c = Theme.of(context).colorScheme;
    Future<void> edit() async {
      final changed = await showCompanionEditor(context, _hero);
      if (mounted && changed == true) setState(() => widget.onChanged?.call());
    }

    Future<void> health(bool healing) async {
      final n = await showNumberKeypad(context,
          kicker: state?.name, title: healing ? (ru ? 'Лечение спутника' : 'Heal the companion') : (ru ? 'Урон спутнику' : 'Damage to the companion'));
      if (n == null || !mounted) return;
      await _session(() => ClassSessionActionsService.changeCompanionHealth(_hero, n, healing: healing));
    }

    return Instrument(
      key: const ValueKey('ranger-companion'),
      accent: a3,
      title: state?.name ?? (ru ? 'Зверь-спутник' : 'Beast companion'),
      trailing: InstrumentChip(ru ? 'данные' : 'details', glyph: 'settings', onTap: edit),
      child: state == null
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InstrumentHint(ru ? 'Запишите имя и ОЗ спутника — они ведутся отдельно.' : 'Record your companion’s name and HP; they are tracked on their own.'),
                const SizedBox(height: 12),
                GoButton(label: ru ? 'Записать спутника' : 'Record a companion', glyph: 'paw', accent: a3, onTap: edit),
              ]),
            )
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 12),
              BigCount(state.current, of: state.maximum),
              const SizedBox(height: 12),
              TrailBar(value: state.maximum == 0 ? 0 : (state.current / state.maximum).clamp(0, 1), color: a3, background: c.onSurface.withValues(alpha: .09), height: 12),
              const SizedBox(height: 12),
              TileRow(children: [
                GoButton(label: ru ? 'Урон' : 'Damage', glyph: 'minus', accent: a3, soft: true, onTap: state.current > 0 ? () => health(false) : null),
                GoButton(label: ru ? 'Лечение' : 'Heal', glyph: 'plus', accent: AppPaletteRoles.heal(context), soft: true, onTap: state.current < state.maximum ? () => health(true) : null),
              ]),
            ]),
    );
  }
}

/// The scope: rings tighten and the cross turns when the mark locks on.
class _Scope extends StatelessWidget {
  const _Scope({required this.locked, required this.accent, required this.danger});
  final bool locked;
  final Color accent, danger;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: locked ? 1 : 0),
        duration: AppMotion.of(context, const Duration(milliseconds: 800)),
        curve: AppMotion.snappyCurve,
        builder: (context, t, _) => CustomPaint(size: const Size.square(112), painter: _ScopePainter(t, accent, danger)),
      );
}

class _ScopePainter extends CustomPainter {
  _ScopePainter(this.t, this.accent, this.danger);
  final double t;
  final Color accent, danger;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 118, center = size.center(Offset.zero);
    double l(double a, double b) => a + (b - a) * t;
    void ring(double r, double width, double alpha) => canvas.drawCircle(center, r * s, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * s
      ..color = accent.withValues(alpha: alpha));
    ring(l(54, 40), 2, l(.35, .15));
    ring(l(40, 27), 2, .55);
    ring(l(24, 13), 3, 1);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * math.pi / 4);
    final cross = Paint()
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: l(.35, 1));
    for (final a in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(d * 29 * s, d * 57 * s, cross);
    }
    canvas.restore();
    if (t > .5) canvas.drawCircle(center, 5 * s, Paint()..color = danger.withValues(alpha: (t - .5) * 2));
  }

  @override
  bool shouldRepaint(_ScopePainter old) => old.t != t;
}

class _Radar extends StatefulWidget {
  const _Radar({required this.accent});
  final Color accent;
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) && !_c.isAnimating) _c.repeat(count: 4);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(size: const Size.square(48), painter: _RadarPainter(widget.accent, _c.value)),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.accent, this.t);
  final Color accent;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2 - 1;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: .5);
    for (final f in [1.0, .63, .26]) {
      canvas.drawCircle(c, r * f, ring);
    }
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), t * 2 * math.pi - math.pi / 2, math.pi / 3, true, Paint()..color = accent.withValues(alpha: .35));
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

/// A lore card that turns over to show what it gives.
class _FlipCard extends StatelessWidget {
  const _FlipCard(
      {super.key,
      required this.flipped,
      required this.accent,
      required this.glyph,
      required this.cap,
      required this.names,
      required this.back,
      required this.onTap,
      this.onEdit});
  final bool flipped;
  final Color accent;
  final String glyph, cap;
  final VoidCallback? onEdit;
  final List<String> names;
  final List<(String, String)> back;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final low = c.surfaceContainerLow;
    BoxDecoration deco() => BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [mixColor(accent, .16, low), low], stops: const [0, .85]));
    final front = Container(
      padding: const EdgeInsets.all(14),
      decoration: deco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InstrumentGlyph(glyph, size: 28, color: accent),
        const SizedBox(height: 6),
        Text(cap.toUpperCase(), style: capStyle(context, accent)),
        const Spacer(),
        Text(names.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: AppType.display, fontSize: 19, height: 1.1, fontWeight: FontWeight.w600)),
      ]),
    );
    final rear = Container(
      padding: const EdgeInsets.all(14),
      decoration: deco(),
      child: Stack(children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (g, text) in back)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                InstrumentGlyph(g, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text(text, style: labelStyle(context, size: 12.5))),
              ]),
            ),
        ]),
        // The choice made at creation or level-up can be changed here.
        if (onEdit != null)
          Positioned(
            top: -6,
            right: -6,
            child: Pressable(
              onTap: onEdit,
              scale: .9,
              semanticLabel: instrumentRu(context) ? 'Изменить' : 'Change',
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .18)),
                child: InstrumentGlyph('quill', size: 16, color: accent),
              ),
            ),
          ),
      ]),
    );
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      scale: .97,
      selected: flipped,
      semanticLabel: cap,
      child: SizedBox(
        height: 118 + 100 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0.0, 1.0),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: flipped ? math.pi : 0),
          duration: AppMotion.of(context, const Duration(milliseconds: 700)),
          curve: AppMotion.snappyCurve,
          builder: (context, a, _) {
            final showBack = a > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0016)
                ..rotateY(a),
              child: showBack ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: rear) : front,
            );
          },
        ),
      ),
    );
  }
}

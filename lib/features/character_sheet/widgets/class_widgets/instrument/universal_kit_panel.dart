import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';

import '../../../../../core/models/character.dart';
import '../../../../../core/models/character_feature.dart';
import '../../../../../core/services/gameplay_actions_service.dart';
import '../../../../../l10n/app_localizations.dart';
import 'instrument_kit.dart';

/// The universal kit of the prototype (`KIT`): a class that arrives as data
/// — third-party, homebrew, an import — is drawn from what its features
/// declare. Limited uses become tokens of the class motif, a large reserve a
/// pool with a bar, dice an object that rolls in place, a toggle a mode with
/// its rounds, a passive a badge. Nothing here knows the class by name.
class UniversalKitPanel extends StatefulWidget {
  const UniversalKitPanel({
    super.key,
    required this.hero,
    required this.classId,
    required this.features,
    this.locked = const [],
    this.accent,
    this.onChanged,
  });
  final Character hero;
  final String classId;
  final List<CharacterFeature> features;

  /// Features of the class that open at a later level.
  final List<CharacterFeature> locked;
  final Color? accent;
  final VoidCallback? onChanged;

  /// Pools larger than this read as a reserve (HP, points) rather than uses.
  static const tokenLimit = 12;
  static final dice = RegExp(r'(\d+)\s*[кd]\s*(\d+)', caseSensitive: false);

  @override
  State<UniversalKitPanel> createState() => _UniversalKitPanelState();
}

enum _Kind { uses, pool, dice, toggle, action, passive }

class _UniversalKitPanelState extends State<UniversalKitPanel> {
  bool _busy = false;
  int _crack = -1;
  String? _crackOf;
  final _rolls = <String, int>{};
  final _rollKeys = <String, int>{};
  final _rounds = <String, int>{};

  Character get _hero => widget.hero;

  _Kind _kind(CharacterFeature f, String locale) {
    final pool = f.resourcePool;
    if (pool != null && f.consumption == null) {
      final formula = pool.calculationFormula ?? '';
      return pool.maxUses > UniversalKitPanel.tokenLimit || formula.contains('*') ? _Kind.pool : _Kind.uses;
    }
    if (f.type == FeatureType.toggle) return _Kind.toggle;
    if (f.type == FeatureType.passive && _cost(f) == null) return _Kind.passive;
    if (UniversalKitPanel.dice.hasMatch(f.getDescription(locale))) return _Kind.dice;
    return _Kind.action;
  }

  /// The resource a feature pays with, if it names one.
  (CharacterFeature, int)? _cost(CharacterFeature f) {
    final id = f.consumption?.resourceId ?? f.usageCostId;
    if (id == null) return null;
    final norm = id.toLowerCase().replaceAll('_', '-');
    final source = _hero.features
        .where((r) => r.resourcePool != null && r.id.toLowerCase().replaceAll('_', '-') == norm)
        .firstOrNull;
    return source == null ? null : (source, math.max(1, f.consumption?.amount ?? 1));
  }

  String _die(CharacterFeature f, String locale) {
    final m = UniversalKitPanel.dice.firstMatch(f.getDescription(locale));
    return m == null ? '' : '${m.group(1)}${locale == 'ru' ? 'к' : 'd'}${m.group(2)}';
  }

  Future<bool> _pay(CharacterFeature f, bool ru) async {
    final cost = _cost(f);
    if (cost == null) return true;
    final (source, amount) = cost;
    if (GameplayActionsService.resourceCurrent(_hero, source) < amount) {
      HapticFeedback.heavyImpact();
      AppSnackBar.info(context, ru ? 'Нет: ${source.getName('ru').toLowerCase()}' : 'Out of ${source.getName('en').toLowerCase()}');
      return false;
    }
    final spent = await _guard(() => GameplayActionsService.spendResource(_hero, source, amount: amount));
    return spent == true;
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final result = await action();
      if (mounted) widget.onChanged?.call();
      return result;
    } catch (_) {
      if (mounted) AppSnackBar.error(context, AppLocalizations.of(context)!.sheetSaveFailed);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InstrumentAbout _about(CharacterFeature f, String locale, bool ru) {
    final kind = _kind(f, locale);
    final rest = switch (f.resourcePool?.recoveryType) {
      RecoveryType.shortRest => ru ? ' · короткий отдых' : ' · short rest',
      RecoveryType.longRest => ru ? ' · длительный отдых' : ' · long rest',
      RecoveryType.dawn => ru ? ' · на рассвете' : ' · at dawn',
      _ => '',
    };
    final label = switch (kind) {
      _Kind.uses => ru ? 'Заряды' : 'Uses',
      _Kind.pool => ru ? 'Запас' : 'Reserve',
      _Kind.dice => ru ? 'Кости' : 'Dice',
      _Kind.toggle => ru ? 'Режим' : 'Mode',
      _Kind.action => ru ? 'Действие' : 'Action',
      _Kind.passive => ru ? 'Пассивное' : 'Passive',
    };
    return InstrumentAbout(
        title: f.getName(locale), kicker: '$label$rest', paragraphs: f.getDescription(locale).split(RegExp(r'\n\s*\n')));
  }

  String _peekText(CharacterFeature f, String locale) {
    final text = f.getDescription(locale).trim().split('\n').first;
    return text.length > 140 ? '${text.substring(0, 137)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final accent = widget.accent ?? accentOf(context, 5);
    final byKind = <_Kind, List<CharacterFeature>>{};
    for (final f in widget.features) {
      byKind.putIfAbsent(_kind(f, locale), () => []).add(f);
    }
    final blocks = <Widget>[
      for (final f in [...?byKind[_Kind.uses], ...?byKind[_Kind.pool]])
        if (_kind(f, locale) == _Kind.uses) _uses(context, f, accent, ru, locale) else _pool(context, f, accent, ru, locale),
    ];
    final objects = [...?byKind[_Kind.dice], ...?byKind[_Kind.toggle], ...?byKind[_Kind.action]];
    if (objects.isNotEmpty) {
      blocks.add(LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 300 ? 2 : 1;
        final w = (box.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in objects) SizedBox(width: w, child: _object(context, f, accent, ru, locale)),
        ]);
      }));
    }
    final passives = byKind[_Kind.passive] ?? const [];
    if (passives.isNotEmpty || widget.locked.isNotEmpty) {
      blocks.add(LayoutBuilder(builder: (context, box) {
        final columns = math.max(1, math.min(3, passives.length + widget.locked.length));
        final w = (box.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in passives)
            SizedBox(width: w, child: _Badge(name: f.getName(locale), glyph: _glyph(f), accent: accent, peek: _peekText(f, locale), onTap: () => showInstrumentAbout(context, _about(f, locale, ru), accent))),
          for (final f in widget.locked)
            SizedBox(
                width: w,
                child: _Badge(
                    name: f.getName(locale),
                    glyph: 'lock',
                    accent: accent,
                    locked: true,
                    peek: ru ? 'Откроется на ${f.minLevel} уровне' : 'Opens at level ${f.minLevel}',
                    onTap: () => showInstrumentAbout(context, _about(f, locale, ru), accent))),
        ]);
      }));
    }
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < blocks.length; i++) ...[if (i > 0) const SizedBox(height: 12), blocks[i]],
    ]);
  }

  String _glyph(CharacterFeature f) {
    final text = '${f.id} ${f.iconName ?? ''} ${f.nameEn}'.toLowerCase();
    const map = {
      'shield': 'shield',
      'ward': 'shield',
      'armor': 'shield',
      'fire': 'flame',
      'flame': 'flame',
      'heal': 'heart',
      'life': 'heart',
      'eye': 'eye',
      'sight': 'eye',
      'see': 'eye',
      'read': 'book',
      'book': 'book',
      'lore': 'book',
      'stone': 'peaks',
      'mountain': 'peaks',
      'storm': 'bolt',
      'lightning': 'bolt',
      'strike': 'strikes',
      'step': 'dash',
      'speed': 'dash',
      'beast': 'paw',
      'water': 'drop',
      'time': 'timer',
      'mask': 'mask',
    };
    for (final e in map.entries) {
      if (text.contains(e.key)) return e.value;
    }
    return switch (f.actionEconomy) {
      'reaction' => 'stepback',
      'bonus_action' => 'bolt',
      _ => 'spark',
    };
  }

  Widget _uses(BuildContext context, CharacterFeature f, Color accent, bool ru, String locale) {
    final pool = f.resourcePool!;
    final current = GameplayActionsService.resourceCurrent(_hero, f);
    final short = pool.recoveryType == RecoveryType.shortRest;
    return Instrument(
      key: ValueKey('kit-uses-${f.id}'),
      accent: accent,
      title: f.getName(locale),
      about: _about(f, locale, ru),
      trailing: pool.recoveryType == RecoveryType.shortRest || pool.recoveryType == RecoveryType.longRest ? RestChip(short: short, onRestore: () => restoreFeature(context, _hero, f, done: () => setState(() => widget.onChanged?.call()))) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Align(alignment: AlignmentDirectional.centerStart, child: BigCount(current, of: pool.maxUses)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < pool.maxUses; i++)
            Peek(
              title: f.getName(locale),
              text: _peekText(f, locale),
              child: Pressable(
                onTap: _busy
                    ? null
                    : () async {
                        if (GameplayActionsService.resourceCurrent(_hero, f) <= 0) {
                          AppSnackBar.info(context, ru ? '${f.getName(locale)}: вернёт отдых' : '${f.getName(locale)}: a rest restores it');
                          return;
                        }
                        HapticFeedback.lightImpact();
                        setState(() {
                          _crack = GameplayActionsService.resourceCurrent(_hero, f) - 1;
                          _crackOf = f.id;
                        });
                        await _guard(() => GameplayActionsService.spendResource(_hero, f));
                      },
                scale: .9,
                semanticLabel: f.getName(locale),
                child: _Token(lit: i < current, accent: accent, crack: _crackOf == f.id && _crack == i),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        InstrumentHint(
            current > 0
                ? (ru ? 'Коснитесь знака — потратить' : 'Tap a token to spend')
                : (ru ? 'Знаки вернёт отдых' : 'A rest restores the tokens'),
            center: true),
      ]),
    );
  }

  Widget _pool(BuildContext context, CharacterFeature f, Color accent, bool ru, String locale) {
    final pool = f.resourcePool!;
    final current = GameplayActionsService.resourceCurrent(_hero, f);
    final c = Theme.of(context).colorScheme;
    return Instrument(
      key: ValueKey('kit-pool-${f.id}'),
      accent: accent,
      title: f.getName(locale),
      about: _about(f, locale, ru),
      trailing: pool.recoveryType == RecoveryType.shortRest || pool.recoveryType == RecoveryType.longRest
          ? RestChip(
              short: pool.recoveryType == RecoveryType.shortRest,
              onRestore: () => restoreFeature(context, _hero, f, done: () => setState(() => widget.onChanged?.call())))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: BigCount(current, of: pool.maxUses)),
          GhostButton(
            label: ru ? 'Потратить' : 'Spend',
            glyph: 'minus',
            onTap: _busy || current <= 0
                ? null
                : () async {
                    final n = await showNumberKeypad(context,
                        kicker: f.getName(locale), title: ru ? 'Сколько потратить' : 'How much to spend', action: ru ? 'Потратить' : 'Spend');
                    if (n == null || n <= 0 || !mounted) return;
                    HapticFeedback.mediumImpact();
                    await _guard(() => GameplayActionsService.spendResource(_hero, f, amount: math.min(n, GameplayActionsService.resourceCurrent(_hero, f))));
                  },
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: c.onSurface.withValues(alpha: .09))),
              AnimatedFractionallySizedBox(
                duration: AppMotion.of(context, const Duration(milliseconds: 600)),
                curve: AppMotion.snappyCurve,
                widthFactor: pool.maxUses <= 0 ? 0 : (current / pool.maxUses).clamp(0.0, 1.0),
                heightFactor: 1,
                alignment: Alignment.centerLeft,
                child: DecoratedBox(decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _object(BuildContext context, CharacterFeature f, Color accent, bool ru, String locale) {
    final kind = _kind(f, locale);
    final c = Theme.of(context).colorScheme;
    final cost = _cost(f);
    final rounds = _rounds[f.id] ?? 0;
    final on = kind == _Kind.toggle && rounds > 0;
    Widget costLine() {
      if (on) return Text(ru ? 'раунд $rounds / 10' : 'round $rounds / 10', style: hintStyle(context).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600));
      if (cost != null) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          InstrumentGlyph('spark', size: 12, color: c.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
              child: Text('${cost.$2} · ${cost.$1.getName(locale).toLowerCase()}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: hintStyle(context).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600))),
        ]);
      }
      final economy = switch (f.actionEconomy) {
        'bonus_action' => ru ? 'бонусное действие' : 'bonus action',
        'reaction' => ru ? 'реакция' : 'reaction',
        'action' => ru ? 'действие' : 'action',
        _ => null,
      };
      return economy == null ? const SizedBox.shrink() : Text(economy, style: hintStyle(context).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600));
    }

    final die = _die(f, locale);
    final sides = int.tryParse(UniversalKitPanel.dice.firstMatch(f.getDescription(locale))?.group(2) ?? '') ?? 6;
    return Peek(
      title: f.getName(locale),
      text: _peekText(f, locale),
      child: Pressable(
        key: ValueKey('kit-object-${f.id}'),
        onTap: _busy
            ? null
            : () async {
                if (kind == _Kind.toggle) {
                  if (on) {
                    HapticFeedback.selectionClick();
                    setState(() => _rounds[f.id] = rounds >= 10 ? 0 : rounds + 1);
                    return;
                  }
                  if (!await _pay(f, ru) || !mounted) return;
                  HapticFeedback.mediumImpact();
                  setState(() => _rounds[f.id] = 1);
                  return;
                }
                if (kind == _Kind.dice) {
                  if (!await _pay(f, ru) || !mounted) return;
                  final m = UniversalKitPanel.dice.firstMatch(f.getDescription(locale))!;
                  final n = int.parse(m.group(1)!), d = int.parse(m.group(2)!);
                  final r = List.generate(n, (_) => math.Random().nextInt(d) + 1).fold(0, (a, b) => a + b);
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _rolls[f.id] = r;
                    _rollKeys[f.id] = (_rollKeys[f.id] ?? 0) + 1;
                  });
                  return;
                }
                if (cost != null) {
                  if (!await _pay(f, ru) || !context.mounted) return;
                  HapticFeedback.mediumImpact();
                  floatUp(context, '−${cost.$2}', accent);
                  return;
                }
                if (mounted) showInstrumentAbout(context, _about(f, locale, ru), accent);
              },
        selected: on,
        scale: .96,
        semanticLabel: f.getName(locale),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: on ? mixColor(accent, .22, c.surfaceContainer) : c.surfaceContainerLow, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (kind == _Kind.dice)
              TumbleDie(
                  shape: dieShapeFor(sides),
                  label: _rolls[f.id] != null ? '${_rolls[f.id]}' : die,
                  accent: accent,
                  rollKey: _rollKeys[f.id] ?? 0,
                  sides: sides,
                  size: 42)
            else
              Pulse(
                trigger: on,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? accent : accent.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                  child: InstrumentGlyph(_glyph(f), size: 22, color: on ? c.surface : accent),
                ),
              ),
            const SizedBox(height: 8),
            Text(f.getName(locale), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppType.body, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 6),
            costLine(),
          ]),
        ),
      ),
    );
  }
}

/// One use of a class resource: a hex token of the rune motif.
class _Token extends StatelessWidget {
  const _Token({required this.lit, required this.accent, required this.crack});
  final bool lit, crack;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey('$lit$crack'),
      tween: Tween(begin: crack ? 0 : 1, end: 1),
      duration: AppMotion.of(context, const Duration(milliseconds: 600)),
      curve: AppMotion.snappyCurve,
      builder: (context, t, child) => Transform.rotate(
        angle: crack ? math.sin(t * math.pi * 3) * .12 * (1 - t) : 0,
        child: Transform.scale(scale: crack ? .9 + .1 * t : 1, child: child),
      ),
      child: SizedBox(
        width: 48,
        height: 54,
        child: CustomPaint(painter: _TokenPainter(lit, accent, c.surfaceContainer, c.outline, c.onSurface)),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  _TokenPainter(this.lit, this.accent, this.cont, this.outline, this.ink);
  final bool lit;
  final Color accent, cont, outline, ink;
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100, sy = size.height / 110;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final hex = Path()..addPolygon([p(50, 4), p(94, 29), p(94, 81), p(50, 106), p(6, 81), p(6, 29)], true);
    final rune = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * sx
      ..strokeCap = StrokeCap.round
      ..color = mixColor(accent, .6, ink).withValues(alpha: lit ? .6 : .15);
    if (lit) {
      canvas.drawPath(hex, Paint()
        ..color = accent.withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawPath(hex, Paint()..color = mixColor(accent, .34, cont));
      canvas.drawPath(hex, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * sx
        ..strokeJoin = StrokeJoin.round
        ..color = accent);
    } else {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * sx
        ..color = outline;
      for (final metric in hex.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 11 * sx) {
          canvas.drawPath(metric.extractPath(d, d + 6 * sx), dash);
        }
      }
    }
    canvas.drawLine(p(50, 26), p(50, 84), rune);
    canvas.drawLine(p(34, 42), p(66, 68), rune);
    canvas.drawLine(p(66, 42), p(34, 68), rune);
  }

  @override
  bool shouldRepaint(_TokenPainter old) => old.lit != lit || old.accent != accent;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.name, required this.glyph, required this.accent, required this.peek, required this.onTap, this.locked = false});
  final String name, glyph, peek;
  final Color accent;
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Peek(
      title: name,
      text: peek,
      child: Pressable(
        onTap: onTap,
        scale: .96,
        semanticLabel: name,
        child: Opacity(
          opacity: locked ? .55 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
            decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .05), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              InstrumentGlyph(glyph, size: 24, color: locked ? c.onSurfaceVariant : accent),
              const SizedBox(height: 6),
              Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppType.body, fontSize: 12, fontWeight: FontWeight.w600, height: 1.15, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

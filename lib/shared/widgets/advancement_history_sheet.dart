import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/character.dart';
import '../../core/progression/advancement_history.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/page_kit.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../features/character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';

/// The advancement history (wave 6): the hero's levels as a ladder, the
/// newest on top. Every confirmed level-up is a rung that can be taken
/// back; a tap shows what goes with it, and the rollback is held, not
/// tapped. Levels from before the history was kept stay quiet.
Future<bool?> showAdvancementHistory(BuildContext context, Character hero) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _HistorySheet(hero));

class _HistorySheet extends StatefulWidget {
  const _HistorySheet(this.hero);
  final Character hero;
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  RollbackPreview? _preview;
  AdvancementRecord? _target;
  bool _busy = false, _falling = false;
  String? _issue;

  void _choose(AdvancementRecord record, Tr tr) {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _issue = null;
      if (_target?.id == record.id) {
        _preview = null;
        _target = null;
        return;
      }
      try {
        _preview = AdvancementHistory.preview(widget.hero, record.id);
        _target = record;
      } catch (_) {
        _preview = null;
        _target = null;
        _issue = tr.t(
            'После этого повышения некоторые решения были изменены вручную. Автоматический откат не сможет сохранить их однозначно.',
            'Some choices were edited after this level-up. They cannot be preserved unambiguously by an automatic rollback.');
      }
    });
  }

  Future<void> _rollback(Tr tr, int falling) async {
    if (_busy || _preview == null) return;
    setState(() {
      _busy = true;
      _falling = true;
    });
    // The rungs that go slide away, top first, before the sheet is rewritten.
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(Duration(milliseconds: 520 + falling * 120));
    }
    try {
      await AdvancementHistory.apply(widget.hero, _preview!);
      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _falling = false;
        _preview = null;
        _target = null;
        _issue = tr.t(
            'Лист изменился или запись не завершилась. Выбери повышение заново; изменения не применены.',
            'The sheet changed or saving failed. Select the level-up again; no changes were applied.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final locale = tr.ru ? 'ru' : 'en';
    final hero = widget.hero;
    List<AdvancementRecord> records = [];
    bool readable = true;
    try {
      records = AdvancementHistory.read(hero);
    } catch (_) {
      readable = false;
    }
    final byLevel = {for (final r in records) r.to: r};
    final primary = hero.classes.isEmpty ? null : hero.classes.first.id;
    final heroAccent = classAccent(context, primary ?? hero.characterClass);
    final rollTo = _target?.from;
    final going = rollTo == null ? 0 : hero.level - rollTo;
    return PopScope(
        canPop: !_busy,
        child: KeyboardPadding(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PageCap(
                          tr.t('${hero.name} · ${hero.level}-й уровень',
                              '${hero.name} · level ${hero.level}'),
                          accent: heroAccent),
                      const SizedBox(height: 6),
                      Text(tr.t('История повышений', 'Level-up history'),
                          style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1.2,
                              color: c.onSurface)),
                      const SizedBox(height: 10),
                      Text(
                          tr.t(
                              'Каждое подтверждённое повышение — ступень. Откатить можно последние ступени, начиная сверху: журнал, имущество и текущие ОЗ сохранятся.',
                              'Every confirmed level-up is a rung. The latest rungs can be taken back from the top: the journal, belongings and current HP stay.'),
                          style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: c.onSurfaceVariant)),
                      const SizedBox(height: 20),
                      if (!readable)
                        _note(
                            context,
                            tr.t(
                                'История недоступна в этой версии. Сохранённые сведения оставлены без изменений.',
                                'This history is unavailable in this version. Saved records are preserved.'))
                      else ...[
                        if (records.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _note(
                                context,
                                tr.t(
                                    'Первое повышение откроет историю: здесь появятся новые подтверждённые уровни. Для прежних решения ещё не записывались.',
                                    'Your next level-up starts the history: new confirmed levels appear here. Earlier choices were not recorded.'),
                                icon: 'book'),
                          ),
                        for (var l = hero.level; l >= 1; l--)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _Rise(
                              // The ladder is climbed once: rungs rise from the bottom.
                              index: l - 1,
                              child: _Rung(
                                level: l,
                                record: byLevel[l],
                                className: CharacterClassContext(
                                        hero, byLevel[l]?.classId ?? primary ?? '')
                                    .name(locale),
                                accent: classAccent(context,
                                    byLevel[l]?.classId ?? primary ?? ''),
                                selected: rollTo != null && l == rollTo + 1,
                                goes: rollTo != null && l > rollTo,
                                fall: _falling && rollTo != null && l > rollTo,
                                fallDelay: hero.level - l,
                                onTap: byLevel[l] == null || _busy
                                    ? null
                                    : () => _choose(byLevel[l]!, tr),
                              ),
                            ),
                          ),
                      ],
                      if (_issue != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_issue!,
                                style: TextStyle(
                                    fontSize: 14, height: 1.4, color: c.error))),
                      PageReveal(
                        open: _preview != null,
                        child: _preview == null
                            ? const SizedBox(width: double.infinity)
                            : _after(context, tr, locale, going),
                      ),
                    ]))));
  }

  Widget _after(BuildContext context, Tr tr, String locale, int going) {
    final c = Theme.of(context).colorScheme;
    final hero = widget.hero, result = _preview!.result;
    final lost = [
      for (final feature in hero.features)
        if (!result.features.any((old) => old.id == feature.id))
          feature.getName(locale)
    ];
    final red = AppAccents.of(context).at(0);
    Widget row(String icon, String label, String from, String to) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            LineIcon(icon, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.onSurface))),
            Text(from,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
            const SizedBox(width: 8),
            LineIcon('forward', size: 14, color: c.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(to,
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(c.onSurface, red, .8))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: Text(tr.t('После отката', 'After reverting'),
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
              color: c.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            row('up', tr.t('Уровень героя', 'Hero level'), '${hero.level}',
                '${result.level}'),
            row('heart', tr.t('Максимум ОЗ', 'Maximum HP'), '${hero.maxHp}',
                '${result.maxHp}'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                  result.classes
                      .map((entry) =>
                          '${CharacterClassContext(result, entry.id).name(locale)} ${entry.level}')
                      .join(' / '),
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
            ),
            if (lost.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LineIcon('x', size: 18, color: c.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr.t('Уйдут: ${lost.join(', ')}', 'Goes away: ${lost.join(', ')}'),
                        style: TextStyle(
                            fontSize: 14, height: 1.4, color: c.onSurface)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LineIcon('check', size: 18, color: c.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                tr.t(
                    'Журнал, имущество, деньги и текущие ОЗ (не выше нового максимума) сохранятся. Потраченные ресурсы не восстановятся.',
                    'The journal, belongings, money and current HP (up to the new maximum) stay. Spent resources are not restored.'),
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: c.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 14),
        PageHold(
          key: const ValueKey('history-rollback-hold'),
          icon: 'back',
          label: tr.t('Удерживайте, чтобы откатить', 'Hold to roll back'),
          detail: tr.t('Герой вернётся к ${result.level}-му уровню',
              'The hero returns to level ${result.level}'),
          onDone: () => _rollback(tr, going),
        ),
      ]),
    );
  }

  Widget _note(BuildContext context, String text, {String icon = 'info'}) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LineIcon(icon, size: 20, color: c.secondary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 14, height: 1.4, color: c.onSurface))),
      ]),
    );
  }
}

/// A level on the ladder (`.rung`). A recorded one can be chosen; the one
/// the hero returns past takes the red, squares its corners and its number.
class _Rung extends StatelessWidget {
  const _Rung(
      {required this.level,
      required this.record,
      required this.className,
      required this.accent,
      required this.selected,
      required this.goes,
      required this.fall,
      required this.fallDelay,
      this.onTap});
  final int level, fallDelay;
  final AdvancementRecord? record;
  final String className;
  final Color accent;
  final bool selected, goes, fall;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final tr = Tr(context);
    final red = AppAccents.of(context).at(0);
    final old = record == null;
    final tone = goes ? red : accent;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final body = AnimatedContainer(
      duration: dur,
      curve: AppMotion.snappyCurve,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(selected ? 14 : 20),
        color: old
            ? Colors.transparent
            : selected
                ? pageMix(red, .1, c.surfaceContainerLow)
                : goes
                    ? pageMix(red, .07, c.surfaceContainerLow)
                    : c.surfaceContainerLow,
        border: Border.all(
            color: old
                ? c.onSurface.withValues(alpha: .08)
                : selected
                    ? red.withValues(alpha: .5)
                    : Colors.transparent,
            width: old ? 1.4 : 1.5),
      ),
      child: Row(children: [
        AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: old
                  ? c.onSurface.withValues(alpha: .06)
                  : pageMix(tone, goes ? .22 : .2, c.surfaceContainer),
              borderRadius: BorderRadius.circular(selected ? 20 : 14)),
          child: Text('$level',
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: old
                      ? c.onSurfaceVariant
                      : goes
                          ? red
                          : Color.lerp(c.onSurface, accent, .8))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr.t('$className · $level-й уровень', '$className · level $level'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: old ? c.onSurfaceVariant : c.onSurface)),
            const SizedBox(height: 3),
            Text(
                old
                    ? level == 1
                        ? tr.t('Создание героя', 'The hero was created')
                        : tr.t('до записи истории', 'before the history')
                    : tr.t('Уровень героя ${record!.from} → ${record!.to}',
                        'Character level ${record!.from} → ${record!.to}'),
                style: TextStyle(
                    fontSize: 12.5, height: 1.3, color: c.onSurfaceVariant)),
          ]),
        ),
        if (!old) ...[
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: dur,
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goes
                    ? red.withValues(alpha: .18)
                    : c.onSurface.withValues(alpha: .06)),
            child: LineIcon('back',
                size: 16, color: goes ? red : c.onSurfaceVariant),
          ),
        ],
      ]),
    );
    return _Fall(
      fall: fall,
      delay: fallDelay,
      child: Pressable(onTap: onTap, scale: .985, selected: selected, child: body),
    );
  }
}

/// Rises into place on the way in, one rung after another from the bottom.
class _Rise extends StatefulWidget {
  const _Rise({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 460));
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0 || _wait != null) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    _wait = Timer(Duration(milliseconds: 80 + 60 * widget.index.clamp(0, 12)),
        () => mounted ? _c.forward() : null);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = AppMotion.snappyCurve.transform(_c.value);
          return Opacity(
            opacity: AppMotion.standard.transform(_c.value),
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)),
              child: Transform.scale(scale: .96 + .04 * t, child: child),
            ),
          );
        },
        child: widget.child,
      );
}

/// A rung that goes slides off to the side and fades, the top one first.
class _Fall extends StatelessWidget {
  const _Fall({required this.fall, required this.delay, required this.child});
  final bool fall;
  final int delay;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fall ? 1 : 0),
      duration: reduced
          ? Duration.zero
          : Duration(milliseconds: 520 + (fall ? delay * 120 : 0)),
      curve: fall
          ? Interval(
              (delay * 120) / (520 + delay * 120), 1, curve: AppMotion.standard)
          : AppMotion.standard,
      builder: (context, t, child) => FractionalTranslation(
        translation: Offset(1.1 * t, 0),
        child: Opacity(opacity: 1 - t, child: child),
      ),
      child: child,
    );
  }
}

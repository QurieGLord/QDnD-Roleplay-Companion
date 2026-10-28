import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/magic/magic_slots.dart';
import '../../../../core/magic/spellbook_state.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/spell.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/spell_service.dart';
import '../../../../core/services/spellbook_actions_service.dart';
import '../../../../core/utils/spell_utils.dart';
import '../../../../core/ui/sheet_drag_region.dart' show SheetSafeArea;
import '../../../../shared/widgets/spell_details_sheet.dart';
import 'instrument/instrument_kit.dart';
import 'instrument/slot_recovery_instrument.dart';

/// Wizard (prototype `CLASS.wizard`, fourth pass). Recovery is a row of
/// crystals per circle within a budget of circles; the spellbook is a cell
/// that opens the pages to prepare from; an evoker sculpts a safe pocket in
/// the blast.
class WizardMagicWidget extends StatefulWidget {
  final Character character;
  final VoidCallback onStateChanged;

  const WizardMagicWidget({
    super.key,
    required this.character,
    required this.onStateChanged,
  });

  @override
  State<WizardMagicWidget> createState() => _WizardMagicWidgetState();
}

class _WizardMagicWidgetState extends State<WizardMagicWidget> {
  static const _source = 'class:wizard';
  int _sculpt = 1, _bookKey = 0;

  Character get _hero => widget.character;
  CharacterClassContext get _owner => CharacterClassContext(_hero, 'wizard');

  /// The levelled spells of the wizard's own book, with their prepared mark.
  List<(Spell, bool)> _book() {
    final state = SpellbookState.read(_hero.spellbookData);
    final single = _hero.classes.length == 1;
    final known = {...state.ids(_source, 'known'), if (single) ...state.unassignedKnown(_hero)};
    final prepared = {
      ...state.ids(_source, 'prepared'),
      ...state.ids(_source, 'alwaysPrepared'),
      if (single) ...state.unassignedPrepared(_hero),
    };
    return [
      for (final id in {...known, ...prepared})
        if (SpellService.getSpellById(id) case final s? when s.level > 0) (s, prepared.contains(id))
    ]..sort((a, b) => a.$1.level != b.$1.level ? a.$1.level - b.$1.level : a.$1.nameRu.compareTo(b.$1.nameRu));
  }

  bool get _sculptor => _hero.features.any((f) => _owner.canUseFeature(f) && f.id.toLowerCase().replaceAll('_', '-').contains('sculpt-spells'));

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final a4 = accentOf(context, 4), a1 = accentOf(context, 1);
    final level = _owner.level;
    final book = _book();
    final ready = book.where((e) => e.$2).length;
    final cap = SpellbookActionsService.preparationLimit(_hero, _source);
    final half = (level + 1) ~/ 2;

    final tiles = <Widget>[
      CellTile(
        key: const ValueKey('wizard-spellbook'),
        accent: a4,
        onTap: () {
          setState(() => _bookKey++);
          Future.delayed(const Duration(milliseconds: 260), () {
            if (mounted) _showBook(this.context);
          });
        },
        peek: (ru ? 'Книга заклинаний' : 'Spellbook', ru ? 'Заклинания вашей книги. Коснитесь — открыть и подготовить.' : 'The spells in your book. Tap to open and prepare.'),
        children: [
          _BookGlyph(accent: a4, openKey: _bookKey),
          InstrumentCap(ru ? 'Книга' : 'Book', accent: a4),
          RollingNumber(book.length, style: bigStyle(context)),
          InstrumentHint(cap == null ? (ru ? 'готово $ready' : '$ready ready') : (ru ? 'готово $ready из $cap' : '$ready of $cap ready')),
        ],
      ),
      if (_sculptor) _sculptCell(context, ru, a1, a4),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SlotRecoveryInstrument(
        key: const ValueKey('wizard-arcane-recovery'),
        hero: _hero,
        classId: 'wizard',
        title: ru ? 'Восстановление' : 'Recovery',
        accent: a4,
        used: _hero.arcaneRecoveryUsed,
        about: InstrumentAbout(
            title: AppLocalizations.of(context)!.arcaneRecovery,
            kicker: ru ? 'Раз в день · короткий отдых' : 'Once a day · short rest',
            paragraphs: [
              ru
                  ? 'Во время короткого отдыха вы возвращаете потраченные ячейки, сумма кругов которых не больше половины уровня волшебника с округлением вверх — сейчас $half. Ячейки 6 круга и выше так не вернуть.'
                  : 'During a short rest you recover spent slots whose circles add up to half your wizard level, rounded up — $half now. No slot of 6th level or higher.',
            ],
            how: ru ? 'Тусклые кристаллы — потраченные ячейки. Коснитесь их и нажмите «Вернуть».' : 'Dim crystals are spent slots. Touch them, then press Recover.'),
        onChanged: () {
          if (mounted) setState(() {});
          widget.onStateChanged();
        },
      ),
      const SizedBox(height: 12),
      TileRow(children: tiles),
    ]);
  }

  Widget _sculptCell(BuildContext context, bool ru, Color a1, Color a4) {
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(_hero);
    } catch (_) {}
    final circles = [
      for (var n = 1; n <= 5; n++)
        if (slots != null && n - 1 < slots.maximum.length && slots.maximum[n - 1] > 0) n
    ];
    if (circles.isNotEmpty && !circles.contains(_sculpt)) _sculpt = circles.last;
    return Peek(
      title: ru ? 'Ваяние заклинаний' : 'Sculpt Spells',
      text: ru
          ? 'Выберите 1 + круг существ: они проходят спасбросок и не получают урона от вашего воплощения'
          : 'Choose 1 + the spell level creatures: they succeed on the save and take no damage from your evocation',
      child: Container(
        key: const ValueKey('wizard-sculpt'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${(ru ? 'Ваяние' : 'Sculpt').toUpperCase()} · ', style: capStyle(context, a1))),
            RollingNumber(1 + _sculpt, style: capStyle(context, a1)),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 58,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (1 + _sculpt).toDouble()),
              duration: AppMotion.of(context, const Duration(milliseconds: 300)),
              builder: (context, safe, _) => CustomPaint(
                size: Size.infinite,
                painter: _SculptPainter(safe, a1, a4, accentOf(context, 0), Theme.of(context).colorScheme.surfaceContainerLow),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 3, runSpacing: 3, children: [
            for (final n in circles)
              Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sculpt = n);
                },
                selected: _sculpt == n,
                scale: .9,
                semanticLabel: '$n',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _sculpt == n ? a1 : Theme.of(context).colorScheme.onSurface.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('$n',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _sculpt == n ? Theme.of(context).colorScheme.surface : null)),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  void _openSpell(BuildContext context, Spell spell, VoidCallback refresh) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => FloatingGrab(child: SheetSafeArea(
          child: SpellDetailsSheet(
              spell: spell,
              character: _hero,
              editable: true,
              onChanged: () {
                refresh();
                if (mounted) setState(() {});
                widget.onStateChanged();
              }))),
    );
  }

  /// The spellbook: every spell the wizard has written down. Preparing one
  /// (the star) puts it among today's spells in the circles of Magic below;
  /// a ritual can be cast from the book without preparing it.
  void _showBook(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final a4 = accentOf(context, 4), a2 = accentOf(context, 2);
    showCompanionSheet<void>(context, builder: (context) {
      return StatefulBuilder(builder: (context, setSheet) {
        final book = _book();
        final ready = book.where((e) => e.$2).length;
        final cap = SpellbookActionsService.preparationLimit(_hero, _source);
        final c = Theme.of(context).colorScheme;
        Future<void> toggle(Spell s, bool on) async {
          if (!on && cap != null && ready >= cap) {
            HapticFeedback.heavyImpact();
            AppSnackBar.info(context, ru ? 'Подготовлено $ready из $cap — сначала уберите другое' : '$ready of $cap prepared — remove one first');
            return;
          }
          HapticFeedback.selectionClick();
          try {
            await SpellbookActionsService.setPrepared(_hero, s.id, !on, source: _source);
          } catch (_) {
            if (context.mounted) AppSnackBar.error(context, l.sheetSaveFailed);
          }
          if (context.mounted) setSheet(() {});
          if (mounted) setState(() {});
          widget.onStateChanged();
        }

        Widget badge(String text) => Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .09), borderRadius: BorderRadius.circular(6)),
              child: Text(text, style: TextStyle(fontFamily: AppType.body, fontSize: 10, fontWeight: FontWeight.w600, height: 1, color: c.onSurfaceVariant)),
            );

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text([ru ? 'Волшебник' : 'Wizard', subclassDisplayName(_hero, 'wizard', locale)].whereType<String>().join(' · '),
              style: TextStyle(fontFamily: AppType.body, fontSize: 13, fontWeight: FontWeight.w600, color: a4)),
          const SizedBox(height: 8),
          SheetHeading(ru ? 'Книга заклинаний' : 'Spellbook'),
          const SizedBox(height: 10),
          Text(
              ru
                  ? 'Всё, что записано в книге. Звезда — подготовить на сегодня: подготовленные появляются в кругах «Магии» и тратят ячейки. Ритуалы (Р) можно проводить прямо из книги без подготовки. Коснитесь строки — описание.'
                  : 'Everything written in the book. The star prepares a spell for today: prepared spells appear in the circles of Magic and use slots. Rituals (R) can be cast from the book unprepared. Tap a row for its description.',
              style: hintStyle(context).copyWith(fontSize: 13, height: 1.45)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            RollingNumber(ready, style: hugeStyle(context)),
            if (cap != null) Text(' / $cap', style: ofStyle(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(ru ? 'подготовлено · в книге ${book.length}' : 'prepared · ${book.length} in the book', style: hintStyle(context).copyWith(fontSize: 13))),
          ]),
          if (cap != null && cap > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                  value: (ready / cap).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: ready > cap ? accentOf(context, 0) : a4,
                  backgroundColor: c.onSurface.withValues(alpha: .08)),
            ),
          ],
          if (book.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: InstrumentHint(ru ? 'В книге пока нет заклинаний — их добавляет Альманах.' : 'The book is empty — add spells in the Almanac.', center: true),
            ),
          for (var circle = 1; circle <= 9; circle++)
            if (book.where((e) => e.$1.level == circle).toList() case final page when page.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(ru ? '$circle круг' : 'Level $circle', style: capStyle(context, c.onSurfaceVariant))),
                Text(ru ? 'готово ${page.where((e) => e.$2).length} из ${page.length}' : '${page.where((e) => e.$2).length} of ${page.length} ready',
                    style: hintStyle(context).copyWith(fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: [mixColor(const Color(0xFFF3E6C8), .08, c.surfaceContainerLow), c.surfaceContainerLow]),
                ),
                child: Column(children: [
                  for (final (s, on) in page)
                    AnimatedContainer(
                      key: ValueKey('wizard-book-${s.id}'),
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(color: on ? a4.withValues(alpha: .1) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Pressable(
                          key: ValueKey('wizard-book-star-${s.id}'),
                          onTap: () => toggle(s, on),
                          selected: on,
                          scale: .85,
                          semanticLabel: on ? (ru ? 'Убрать из подготовки' : 'Unprepare') : (ru ? 'Подготовить' : 'Prepare'),
                          child: SizedBox.square(
                            dimension: 48,
                            child: Center(
                              child: AnimatedRotation(
                                turns: on ? .2 : 0,
                                duration: AppMotion.of(context, const Duration(milliseconds: 400)),
                                curve: AppMotion.snappyCurve,
                                child: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded, size: 24, color: on ? a2 : c.outline),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Pressable(
                            onTap: () => _openSpell(context, s, () => setSheet(() {})),
                            scale: .99,
                            semanticLabel: s.getName(locale),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text.rich(
                                        TextSpan(children: [
                                          TextSpan(text: s.getName(locale)),
                                          if (s.concentration) WidgetSpan(alignment: PlaceholderAlignment.middle, child: badge(ru ? 'К' : 'C')),
                                          if (s.ritual) WidgetSpan(alignment: PlaceholderAlignment.middle, child: badge(ru ? 'Р' : 'R')),
                                        ]),
                                        style: const TextStyle(fontFamily: AppType.body, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.25)),
                                    const SizedBox(height: 2),
                                    Text('${SpellUtils.getLocalizedSchool(l, s.school)} · ${SpellUtils.getLocalizedValue(l, s.castingTime)}',
                                        maxLines: 1, overflow: TextOverflow.ellipsis, style: hintStyle(context).copyWith(fontSize: 12)),
                                  ]),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 20, color: c.onSurfaceVariant),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
        ]);
      });
    });
  }
}

/// The book cover of the spellbook cell; it swings open on tap.
class _BookGlyph extends StatelessWidget {
  const _BookGlyph({required this.accent, required this.openKey});
  final Color accent;
  final int openKey;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(openKey),
      tween: Tween(begin: openKey == 0 ? 1 : 0, end: 1),
      duration: AppMotion.of(context, const Duration(milliseconds: 700)),
      builder: (context, t, _) {
        // 0 → 1: the cover opens to ~70° and falls back.
        final open = t < .5 ? t * 2 : (1 - t) * 2;
        return SizedBox(
          width: 40,
          height: 46,
          child: Stack(children: [
            Positioned(
              left: 4,
              top: 3,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: mixColor(const Color(0xFFF3E6C8), .6, c.surfaceContainer),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(8)))),
            ),
            Positioned.fill(
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .004)
                  ..rotateY(-1.2 * open),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4), right: Radius.circular(10)),
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [mixColor(accent, .7, c.surfaceContainer), mixColor(accent, .35, c.surfaceContainer)]),
                  ),
                  child: const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 4, height: double.infinity, child: ColoredBox(color: Color(0x33000000)))),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _SculptPainter extends CustomPainter {
  _SculptPainter(this.safe, this.area, this.safeColor, this.hitColor, this.surface);
  final double safe;
  final Color area, safeColor, hitColor, surface;
  static const _dots = [Offset(34, 20), Offset(62, 18), Offset(50, 32), Offset(30, 42), Offset(68, 44), Offset(50, 52)];
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / 64;
    final dx = (size.width - 100 * k) / 2;
    Offset p(Offset o) => Offset(dx + o.dx * k, o.dy * k);
    final centre = p(const Offset(50, 32));
    canvas.drawCircle(centre, 28 * k, Paint()..color = area.withValues(alpha: .22));
    final ring = Path()..addOval(Rect.fromCircle(center: centre, radius: 28 * k));
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = area;
    for (final m in ring.computeMetrics()) {
      for (double d = 0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), dash);
      }
    }
    for (var i = 0; i < _dots.length; i++) {
      final on = (safe - i).clamp(0.0, 1.0);
      final color = Color.lerp(hitColor.withValues(alpha: .8), safeColor, on)!;
      canvas.drawCircle(p(_dots[i]), 5 * k, Paint()..color = color);
      if (on > 0) {
        canvas.drawCircle(
            p(_dots[i]),
            5 * k,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = surface.withValues(alpha: on));
      }
    }
  }

  @override
  bool shouldRepaint(_SculptPainter old) => old.safe != safe;
}

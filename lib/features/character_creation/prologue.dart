import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../core/models/background_data.dart';
import '../../core/models/character.dart';
import '../../core/models/character_feature.dart';
import '../../core/models/class_data.dart';
import '../../core/models/item.dart';
import '../../core/models/race_data.dart';
import '../../core/progression/proficiency_identity.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/feature_service.dart';
import '../../core/services/item_service.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import '../../core/ui/page_kit.dart';
import '../character_level_up/widgets/advancement_climb.dart';
import '../character_level_up/widgets/advancement_layout.dart';
import '../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../journal/journal_kit.dart';
import 'character_creation_state.dart';
import 'character_creation_wizard.dart' show starterEquipment;
import 'prologue_abilities.dart';
import 'steps/features_spells_step.dart';

/// Character creation as «Пролог» (wave 6, after the accepted prototype
/// `docs/prototypes/wave6/index.html`): chapters in order under a hero
/// card that builds itself, a bar of chapters that flows from one to the
/// next, and the island dock. A long press or the «i» opens any choice.
class Prologue extends StatefulWidget {
  const Prologue(
      {super.key,
      required this.saving,
      required this.compose,
      required this.onCreate});
  final bool saving;

  /// The hero as chosen so far, for the finale.
  final Character Function() compose;
  final VoidCallback onCreate;
  @override
  State<Prologue> createState() => _PrologueState();
}

enum PrologueChapter {
  name,
  race,
  cls,
  abilities,
  background,
  skills,
  features,
  gear,
  done
}

/// Room a chapter leaves at its end for the island.
const double prologueDockRoom = 148;

/// Where the people of a race come from: a glyph and an accent.
(String, int) raceLook(String id) {
  final r = id.toLowerCase();
  if (r.contains('dwarf')) return ('peaks', 0);
  if (r.contains('half-elf') || r.contains('half_elf')) return ('leaf', 5);
  if (r.contains('elf')) return ('leaf', 3);
  if (r.contains('halfling')) return ('heart', 2);
  if (r.contains('dragon')) return ('flame', 0);
  if (r.contains('gnome')) return ('gem', 4);
  if (r.contains('orc')) return ('axe', 3);
  if (r.contains('tiefling')) return ('flame', 5);
  if (r.contains('human')) return ('person', 1);
  return ('person', id.hashCode.abs() % 6);
}

String abilityShort(Tr tr, String key) => switch (key) {
      'strength' => tr.t('СИЛ', 'STR'),
      'dexterity' => tr.t('ЛОВ', 'DEX'),
      'constitution' => tr.t('ТЕЛ', 'CON'),
      'intelligence' => tr.t('ИНТ', 'INT'),
      'wisdom' => tr.t('МДР', 'WIS'),
      _ => tr.t('ХАР', 'CHA'),
    };

String abilityName(AppLocalizations l, String key) => switch (key) {
      'strength' => l.abilityStr,
      'dexterity' => l.abilityDex,
      'constitution' => l.abilityCon,
      'intelligence' => l.abilityInt,
      'wisdom' => l.abilityWis,
      _ => l.abilityCha,
    };

String skillName(AppLocalizations l, String value) =>
    switch (ProficiencyIdentity.normalize(value)) {
      'acrobatics' => l.skillAcrobatics,
      'animal-handling' => l.skillAnimalHandling,
      'arcana' => l.skillArcana,
      'athletics' => l.skillAthletics,
      'deception' => l.skillDeception,
      'history' => l.skillHistory,
      'insight' => l.skillInsight,
      'intimidation' => l.skillIntimidation,
      'investigation' => l.skillInvestigation,
      'medicine' => l.skillMedicine,
      'nature' => l.skillNature,
      'perception' => l.skillPerception,
      'performance' => l.skillPerformance,
      'persuasion' => l.skillPersuasion,
      'religion' => l.skillReligion,
      'sleight-of-hand' => l.skillSleightOfHand,
      'stealth' => l.skillStealth,
      'survival' => l.skillSurvival,
      _ => value,
    };

const _skillAbility = {
  'acrobatics': 'dexterity',
  'animal-handling': 'wisdom',
  'arcana': 'intelligence',
  'athletics': 'strength',
  'deception': 'charisma',
  'history': 'intelligence',
  'insight': 'wisdom',
  'intimidation': 'charisma',
  'investigation': 'intelligence',
  'medicine': 'wisdom',
  'nature': 'intelligence',
  'perception': 'wisdom',
  'performance': 'charisma',
  'persuasion': 'charisma',
  'religion': 'intelligence',
  'sleight-of-hand': 'dexterity',
  'stealth': 'dexterity',
  'survival': 'wisdom',
};

String _signed(int n) => n >= 0 ? '+$n' : '−${-n}';
int _mod(int v) => (v - 10) ~/ 2 - (v < 10 && v.isOdd ? 1 : 0);

/// The accent the page wears: the class once chosen, else the people.
Color prologueAccent(BuildContext context, CharacterCreationState s) {
  if (s.selectedClass != null) return classAccent(context, s.selectedClass!.id);
  if (s.selectedRace != null) {
    return AppAccents.of(context).at(raceLook(s.selectedRace!.id).$2);
  }
  return AppAccents.of(context).at(1);
}

class _PrologueState extends State<Prologue>
    with SingleTickerProviderStateMixin {
  int _i = 0, _dir = 1;
  bool _leaving = false;
  // The chapter bar flows from the chapter we came from to this one.
  late final AnimationController _bar = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 560), value: 1);
  int _was = 0;
  // One scroll for the hero card, the chapter bar and the chapter.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _bar.dispose();
    _scroll.dispose();
    super.dispose();
  }

  PrologueChapter get _chapter => PrologueChapter.values[_i];

  bool _ok(CharacterCreationState s, PrologueChapter k) => switch (k) {
        PrologueChapter.name => s.name.trim().isNotEmpty,
        PrologueChapter.race => s.selectedRace != null &&
            (s.selectedRace!.subraces.isEmpty || s.selectedSubrace != null),
        PrologueChapter.cls =>
          s.selectedClass != null && s.selectedClass!.declares('hitDie'),
        PrologueChapter.abilities => s.abilitiesComplete,
        PrologueChapter.background => s.selectedBackground != null,
        PrologueChapter.skills => s.isStepValid(6),
        PrologueChapter.features => s.isStepValid(3),
        PrologueChapter.gear => true,
        PrologueChapter.done => true,
      };

  String _hint(CharacterCreationState s, PrologueChapter k, Tr tr) =>
      switch (k) {
        PrologueChapter.name => tr.t('Назовите героя', 'Name the hero'),
        PrologueChapter.race => s.selectedRace == null
            ? tr.t('Выберите народ', 'Choose a people')
            : tr.t('Выберите разновидность', 'Choose a subrace'),
        PrologueChapter.cls => tr.t('Выберите класс', 'Choose a class'),
        PrologueChapter.abilities => s.allocationMethod == 'point_buy'
            ? tr.t('Потрачено больше 27 очков', 'More than 27 points spent')
            : s.allocationMethod == 'roll' && s.rolledScores == null
                ? tr.t('Бросьте кости', 'Roll the dice')
                : tr.t('Расставьте все шесть значений', 'Place all six values'),
        PrologueChapter.background =>
          tr.t('Выберите предысторию', 'Choose a background'),
        PrologueChapter.skills => () {
            final need = s.selectedClass?.skillProficiencies.choose ?? 0;
            final left = need - s.selectedSkills.length;
            if (left > 0) return tr.t('Выберите ещё $left', 'Choose $left more');
            return tr.t('Выберите компетентность', 'Choose expertise');
          }(),
        PrologueChapter.features =>
          tr.t('Сделайте выборы класса', 'Make the class choices'),
        _ => '',
      };

  void _move(int d) {
    final s = context.read<CharacterCreationState>();
    if (d > 0 && !_ok(s, _chapter)) return;
    final next = (_i + d).clamp(0, PrologueChapter.values.length - 1);
    if (next == _i) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _dir = d;
      _was = _i;
      _i = next;
    });
    _bar.forward(from: 0);
    // Every chapter opens from the top.
    if (_scroll.hasClients && _scroll.offset > 0) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 420),
            curve: AppMotion.standard);
      }
    }
  }

  Future<void> _finish() async {
    if (widget.saving || _leaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _leaving = true);
    // The card lifts away towards the party, then the hero is saved.
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (!mounted) return;
    widget.onCreate();
    setState(() => _leaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final accent = prologueAccent(context, s);
    final k = _chapter;
    final ok = _ok(s, k);
    final done = k == PrologueChapter.done;
    final names = [
      tr.t('Имя', 'Name'),
      tr.t('Народ', 'People'),
      tr.t('Класс', 'Class'),
      tr.t('Характеристики', 'Abilities'),
      tr.t('Предыстория', 'Background'),
      tr.t('Навыки', 'Skills'),
      tr.t('Умения', 'Features'),
      tr.t('Снаряжение', 'Gear'),
      tr.t('Итог', 'Summary'),
    ];
    final questions = [
      tr.t('Как зовут героя?', 'What is the hero called?'),
      tr.t('Откуда он родом?', 'Where do they come from?'),
      tr.t('Чем он живёт?', 'What is their calling?'),
      tr.t('В чём его сила?', 'Where does their strength lie?'),
      tr.t('Кем он был до приключений?', 'Who were they before?'),
      tr.t('Чему он научился?', 'What have they learned?'),
      tr.t('Что даёт класс на старте?', 'What does the class give at first?'),
      tr.t('С чем выходит в путь?', 'What do they set out with?'),
      tr.t('Вот он, ваш герой', 'Here is your hero'),
    ];
    return Scaffold(
      backgroundColor: c.surface,
      body: Stack(children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              key: const ValueKey('prologue-scroll'),
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: MediaQuery.paddingOf(context).top +
                            JournalTopBar.height)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SoftSize(
                            duration: AppMotion.of(context, AppMotion.long),
                            curve: AppMotion.standard,
                            child: done
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: PrologueHeroCard(accent: accent),
                                  ),
                          ),
                          AnimatedBuilder(
                            animation: _bar,
                            builder: (context, _) => _ChapterBar(
                                count: names.length,
                                at: _was +
                                    (_i - _was) *
                                        AppMotion.standard.transform(_bar.value),
                                accent: accent),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: PageCap('${_i + 1} · ${names[_i]}',
                                    accent: accent)),
                            if (!done)
                              Text(
                                  tr.t('далее: ${names[_i + 1]}',
                                      'next: ${names[_i + 1]}'),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: c.onSurfaceVariant)),
                          ]),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: AppMotion.of(context, AppMotion.medium),
                            layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.topLeft,
                                children: [...previous, if (current != null) current]),
                            child: Text(questions[_i],
                                key: ValueKey(_i),
                                style: TextStyle(
                                    fontFamily: AppType.display,
                                    fontSize: 30,
                                    height: 1.08,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -.9,
                                    color: c.onSurface)),
                          ),
                        ]),
                  ),
                ),
              SliverToBoxAdapter(
               // The chapter's height eases, so the page never jumps.
               child: SoftSize(
                duration: AppMotion.of(context, const Duration(milliseconds: 460)),
                curve: AppMotion.standard,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                duration: AppMotion.of(context, const Duration(milliseconds: 460)),
                switchInCurve: AppMotion.snappyCurve,
                switchOutCurve: AppMotion.exit,
                layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current]),
                transitionBuilder: (child, a) {
                  final entering = child.key == ValueKey(_i);
                  return FadeTransition(
                    opacity: a,
                    child: AnimatedBuilder(
                      animation: a,
                      child: child,
                      builder: (context, child) => Transform.translate(
                          offset: Offset(
                              (entering ? _dir : -_dir) * 44 * (1 - a.value), 0),
                          child: child),
                    ),
                  );
                },
                child: KeyedSubtree(
                    key: ValueKey(_i),
                    child: _body(k, accent, s)),
              ),
               ),
              ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: JournalTopBar(
            titled: true,
            title: tr.t('Новый герой', 'New hero'),
            leading: JournalRound(
                icon: 'x',
                label: tr.t('Закрыть', 'Close'),
                onTap: widget.saving ? null : () => Navigator.of(context).pop()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AdvancementIsland(
                key: const ValueKey('prologue-island'),
                action: AdvancementDockAction(
                    label: done
                        ? tr.t('Создать героя', 'Create the hero')
                        : tr.t('Далее', 'Next'),
                    hint: ok ? null : _hint(s, k, tr),
                    busy: widget.saving || _leaving,
                    onPressed:
                        ok ? (done ? _finish : () => _move(1)) : null),
                canGoBack: _i > 0 && !widget.saving,
                onBack: () => _move(-1),
                accent: accent,
                last: done,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _body(PrologueChapter k, Color accent, CharacterCreationState s) =>
      switch (k) {
        PrologueChapter.name => const _NameChapter(),
        PrologueChapter.race => const _RaceChapter(),
        PrologueChapter.cls => const _ClassChapter(),
        PrologueChapter.abilities => const PrologueAbilities(),
        PrologueChapter.background => const _BackgroundChapter(),
        PrologueChapter.skills => const _SkillsChapter(),
        PrologueChapter.features => const FeaturesSpellsStep(embedded: true),
        PrologueChapter.gear => const _GearChapter(),
        PrologueChapter.done =>
          _Finale(compose: widget.compose, leaving: _leaving),
      };
}

/// The chapter bar (`.chap6`): settled chapters in a soft accent, the
/// current one longer in the full accent; [at] moves between chapters so
/// the bar flows instead of jumping.
class _ChapterBar extends StatelessWidget {
  const _ChapterBar(
      {required this.count, required this.at, required this.accent});
  final int count;
  final double at;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final weights = [
      for (var i = 0; i < count; i++)
        1 + 1.4 * math.max(0.0, 1 - (i - at).abs())
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, box) {
      final room = box.maxWidth - 4 * (count - 1);
      return Row(children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: room * weights[i] / total,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Color.lerp(
                  Color.lerp(c.onSurface.withValues(alpha: .1),
                      pageMix(accent, .55, c.surfaceContainer),
                      (at - i).clamp(0.0, 1.0)),
                  accent,
                  math.max(0.0, 1 - (i - at).abs()))!,
            ),
          ),
        ],
      ]);
    });
  }
}

/// The hero card that builds itself (`.hc6`): the letter, the name or
/// «Безымянный герой», what is chosen so far, and chips of each choice.
class PrologueHeroCard extends StatelessWidget {
  const PrologueHeroCard({super.key, required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final locale = tr.ru ? 'ru' : 'en';
    final race = s.selectedRace, cls = s.selectedClass, bg = s.selectedBackground;
    final name = s.name.trim();
    final raceName = race == null
        ? null
        : s.selectedSubrace == null
            ? race.getName(locale)
            : s.selectedSubrace!.getName(locale);
    final skills = s.selectedSkills.length +
        (bg?.skillProficiencies.length ?? 0);
    final con = s.finalScore('constitution');
    final bits = <(String, String, String)>[
      if (raceName != null) ('race', raceLook(race!.id).$1, raceName),
      if (cls != null)
        ('class', classSigil(cls.id),
            '${cls.getName(locale)} · ${tr.t('к', 'd')}${cls.hitDie}'),
      if (bg != null) ('bg', 'book', bg.getName(locale)),
      if (s.selectedSkills.isNotEmpty)
        ('skills', 'target', tr.t('Навыков: $skills', 'Skills: $skills')),
      if (cls != null && s.abilitiesComplete && con != null)
        ('hp', 'heart', tr.t('ОЗ ${math.max(1, cls.hitDie + _mod(con))}',
            'HP ${math.max(1, cls.hitDie + _mod(con))}')),
    ];
    final line = [
      if (race != null) race.getName(locale),
      if (cls != null) tr.t('${cls.getName(locale)}, 1-й уровень',
          '${cls.getName(locale)}, level 1'),
    ].join(' · ');
    final dur = AppMotion.of(context, AppMotion.long);
    return AnimatedContainer(
      duration: dur,
      curve: AppMotion.standard,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
            begin: const Alignment(-.6, -1),
            end: const Alignment(.6, 1),
            colors: [
              pageMix(accent, .16, c.surfaceContainerLow),
              c.surfaceContainerLow
            ],
            stops: const [0, .7]),
      ),
      child: SoftSize(
        duration: dur,
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            AnimatedContainer(
              duration: dur,
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(22)),
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.medium),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: name.isNotEmpty
                    ? Text(name.characters.first.toUpperCase(),
                        key: ValueKey(name.characters.first),
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: pageOnAccent(c)))
                    : InstrumentGlyph(
                        cls == null ? 'person' : classSigil(cls.id),
                        key: ValueKey(cls?.id),
                        size: 30,
                        color: pageOnAccent(c)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? tr.t('Безымянный герой', 'Nameless hero') : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppType.display,
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.44,
                            color: name.isEmpty ? c.onSurfaceVariant : c.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                        line.isEmpty
                            ? tr.t('Народ и класс ещё впереди',
                                'People and class are still ahead')
                            : line,
                        style: TextStyle(
                            fontSize: 13, color: c.onSurfaceVariant)),
                  ]),
            ),
          ]),
          if (bits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (key, glyph, text) in bits)
                _Bit(key: ValueKey('$key:$text'), glyph: glyph, text: text, accent: accent),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// A chip of the hero card that stamps in when it appears or changes.
class _Bit extends StatelessWidget {
  const _Bit({super.key, required this.glyph, required this.text, required this.accent});
  final String glyph, text;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
      duration: AppMotion.of(context, AppMotion.snappySettle),
      curve: AppMotion.snappyCurve,
      builder: (context, t, child) =>
          Transform.scale(scale: .7 + .3 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
      child: Container(
        height: 32,
        padding: const EdgeInsets.fromLTRB(9, 0, 12, 0),
        decoration: BoxDecoration(
            color: c.onSurface.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InstrumentGlyph(glyph, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: c.onSurface)),
        ]),
      ),
    );
  }
}

/// A chapter's list with the dock's room at its end.
class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, prologueDockRoom),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// A quiet explanation with a glyph (`.hint5`).
class PrologueHint extends StatelessWidget {
  const PrologueHint(this.text, {super.key, this.icon = 'info'});
  final String text, icon;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LineIcon(icon, size: 17, color: c.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: c.onSurfaceVariant))),
      ]),
    );
  }
}

/// A group title (`.grp6`).
class PrologueGroup extends StatelessWidget {
  const PrologueGroup(this.title, {super.key, this.note});
  final String title;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.17,
                      color: c.onSurface)),
            ),
            if (note != null)
              Text(note!,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.onSurfaceVariant)),
          ]),
    );
  }
}

/* ---------------- Name ---------------- */

class _NameChapter extends StatefulWidget {
  const _NameChapter();
  @override
  State<_NameChapter> createState() => _NameChapterState();
}

class _NameChapterState extends State<_NameChapter> {
  late final _text =
      TextEditingController(text: context.read<CharacterCreationState>().name);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final accent = prologueAccent(context, context.watch<CharacterCreationState>());
    final on = _focus.hasFocus;
    return _ChapterList(children: [
      AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 220)),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: on ? pageMix(accent, .07, c.surfaceContainerLow) : c.surfaceContainerLow,
          border: Border.all(
              color: on ? accent.withValues(alpha: .5) : Colors.transparent,
              width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr.t('ИМЯ ГЕРОЯ', 'HERO NAME'),
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .92,
                  color: c.onSurfaceVariant)),
          TextField(
            key: const ValueKey('prologue-name'),
            controller: _text,
            focusNode: _focus,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => context.read<CharacterCreationState>().updateName(v),
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -.24,
                color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 8, bottom: 2),
              hintText: tr.t('Например, Лира', 'For example, Lyra'),
              hintStyle: TextStyle(color: c.onSurface.withValues(alpha: .3)),
            ),
          ),
        ]),
      ),
      PrologueHint(tr.t(
          'Облик, возраст и характер — в анкете героя: её можно заполнить и потом.',
          'Looks, age and character live in the hero form: fill it in any time later.')),
    ]);
  }
}

/* ---------------- Decks: peoples and classes ---------------- */

/// A deck card (`.dc`): a filled sigil, the name, a few lines, facts at
/// the bottom; chosen, it squares its corners and takes an accent ring.
class _DeckCard extends StatelessWidget {
  const _DeckCard(
      {required this.title,
      required this.text,
      required this.facts,
      required this.glyph,
      required this.accent,
      required this.selected,
      required this.onTap,
      required this.onInfo,
      this.source});
  final String title, text, glyph;
  final List<String> facts;
  final Color accent;
  final bool selected;
  final String? source;
  final VoidCallback onTap, onInfo;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final glow = AppCalm.of(context).glow;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return AdvancementHold(
      accent: accent,
      radius: selected ? 20 : 28,
      onHold: onInfo,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        selected: selected,
        scale: .98,
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(selected ? 20 : 28),
            gradient: LinearGradient(
                begin: const Alignment(-.5, -1),
                end: const Alignment(.5, 1),
                colors: [pageMix(accent, .2, c.surfaceContainerLow), c.surfaceContainerLow],
                stops: const [0, .72]),
            border: Border.all(
                color: selected ? accent : Colors.transparent, width: 2),
          ),
          child: Stack(children: [
            if (glow > 0)
              Positioned(
                right: -60,
                top: -80,
                width: 220,
                height: 200,
                child: Opacity(
                  opacity: glow,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            accent.withValues(alpha: .3),
                            accent.withValues(alpha: 0)
                          ], stops: const [0, .66]))),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(20)),
                    child: InstrumentGlyph(glyph, size: 30, color: pageOnAccent(c)),
                  ),
                  const Spacer(),
                  if (source != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          color: c.onSurface.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(99)),
                      child: Text(source!,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: c.onSurfaceVariant)),
                    ),
                  AdvancementInfoButton(onTap: onInfo),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    duration: AppMotion.of(context, const Duration(milliseconds: 420)),
                    curve: AppMotion.snappyCurve,
                    scale: selected ? 1 : 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: accent, borderRadius: BorderRadius.circular(9)),
                      child: Icon(Icons.check_rounded, size: 17, color: pageOnAccent(c)),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 26,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.65,
                        color: c.onSurface)),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: c.onSurface.withValues(alpha: .78))),
                ),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final f in facts)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                          color: c.onSurface.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(f,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: c.onSurface)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A horizontal deck that snaps to a card and brings the chosen one in.
class _Deck extends StatefulWidget {
  const _Deck({required this.count, required this.selected, required this.builder});
  final int count;
  final int selected;
  final Widget Function(BuildContext context, int index, VoidCallback reveal)
      builder;
  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  late final _pages = PageController(
      viewportFraction: .82, initialPage: math.max(0, widget.selected));
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 268,
        child: PageView.builder(
          controller: _pages,
          padEnds: false,
          itemCount: widget.count,
          onPageChanged: (_) => HapticFeedback.selectionClick(),
          itemBuilder: (context, i) => Padding(
            padding: EdgeInsets.fromLTRB(i == 0 ? 20 : 6, 4, 6, 8),
            child: widget.builder(context, i, () {
              _pages.animateToPage(i,
                  duration: AppMotion.of(context, const Duration(milliseconds: 420)),
                  curve: AppMotion.standard);
            }),
          ),
        ),
      );
}

String _bonusText(Tr tr, Map<String, int> bonus) {
  if (bonus.containsKey('all')) return tr.t('+${bonus['all']} ко всем', '+${bonus['all']} to all');
  return bonus.entries
      .where((e) => e.value != 0)
      .map((e) => '${abilityShort(tr, e.key)} ${_signed(e.value)}')
      .join(', ');
}

void _raceInfo(BuildContext context, RaceData r) {
  final tr = Tr(context);
  final locale = tr.ru ? 'ru' : 'en';
  final look = raceLook(r.id);
  showAdvancementInfo(
      context,
      AdvancementInfo(
          kicker: r.sourceId == null
              ? tr.t('Народ · SRD', 'People · SRD')
              : tr.t('Народ · библиотека', 'People · library'),
          title: r.getName(locale),
          icon: look.$1,
          accent: AppAccents.of(context).at(look.$2),
          text: r.getDescription(locale),
          facts: [
            if (_bonusText(tr, r.abilityScoreIncreases).isNotEmpty)
              _bonusText(tr, r.abilityScoreIncreases),
            tr.t('Скорость ${r.speed}', 'Speed ${r.speed}'),
            if (r.size.isNotEmpty) r.size,
          ],
          feats: [
            for (final t in r.traits)
              (t.getName(locale), t.getDescription(locale), advancementFeatureGlyph(t.iconName)),
            for (final sub in r.subraces)
              (tr.t('Разновидность: ${sub.getName(locale)}', 'Subrace: ${sub.getName(locale)}'),
                  _bonusText(tr, sub.additionalAbilityScores), 'person'),
          ],
          featsTitle: tr.t('Особенности', 'Traits')));
}

class _RaceChapter extends StatelessWidget {
  const _RaceChapter();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final locale = tr.ru ? 'ru' : 'en';
    final races = CharacterDataService.shelfRaces();
    final race = s.selectedRace;
    final look = race == null ? null : raceLook(race.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: prologueDockRoom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Deck(
          count: races.length,
          selected: races.indexWhere((r) => r.id == race?.id),
          builder: (context, i, reveal) {
            final r = races[i];
            final l = raceLook(r.id);
            return _DeckCard(
              title: r.getName(locale),
              text: r.getDescription(locale),
              facts: [
                if (_bonusText(tr, r.abilityScoreIncreases).isNotEmpty)
                  _bonusText(tr, r.abilityScoreIncreases),
                tr.t('Скорость ${r.speed}', 'Speed ${r.speed}'),
              ],
              glyph: l.$1,
              accent: AppAccents.of(context).at(l.$2),
              selected: race?.id == r.id,
              source: r.sourceId == null ? null : tr.t('Библиотека', 'Library'),
              onTap: () {
                if (race?.id != r.id) s.updateRace(r);
                reveal();
              },
              onInfo: () => _raceInfo(context, r),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrologueHint(tr.t('Листайте колоду. Удержание карточки — все особенности народа.',
                'Swipe the deck. Hold a card for all of the people\'s traits.')),
            // The subraces unfold under the deck when the people has them.
            PageReveal(
              open: race != null && race.subraces.isNotEmpty,
              child: race == null || race.subraces.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      key: ValueKey(race.id),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrologueGroup(tr.t('Разновидность', 'Subrace'), note: race.getName(locale)),
                        for (final (i, sub) in race.subraces.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PageEntrance(
                              index: i,
                              child: AdvancementPick(
                                selected: s.selectedSubrace?.id == sub.id,
                                title: sub.getName(locale),
                                subtitle: _bonusText(tr, sub.additionalAbilityScores),
                                icon: look!.$1,
                                accent: AppAccents.of(context).at(look.$2),
                                onTap: () => s.updateSubrace(sub),
                                onInfo: sub.additionalTraits.isEmpty
                                    ? null
                                    : () => showAdvancementInfo(
                                        context,
                                        AdvancementInfo(
                                            kicker: tr.t('Разновидность · ${race.getName(locale)}',
                                                'Subrace · ${race.getName(locale)}'),
                                            title: sub.getName(locale),
                                            icon: look.$1,
                                            accent: AppAccents.of(context).at(look.$2),
                                            text: _bonusText(tr, sub.additionalAbilityScores),
                                            feats: [
                                              for (final t in sub.additionalTraits)
                                                (t.getName(locale), t.getDescription(locale),
                                                    advancementFeatureGlyph(t.iconName)),
                                            ],
                                            featsTitle: tr.t('Особенности', 'Traits'))),
                              ),
                            ),
                          ),
                      ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

List<CharacterFeature> _firstLevel(ClassData c) {
  final out = <CharacterFeature>[
    ...FeatureService.getFeaturesForLevel(classId: c.id, level: 1)
  ];
  for (final f in c.features[1] ?? const <CharacterFeature>[]) {
    if (!out.any((o) => o.id == f.id)) out.add(f);
  }
  return out.where((f) => f.minLevel <= 1).toList();
}

void showClassInfo(BuildContext context, ClassData cls) {
  final tr = Tr(context);
  final l = AppLocalizations.of(context)!;
  final locale = tr.ru ? 'ru' : 'en';
  final armor = cls.armorProficiencies;
  final weapons = cls.weaponProficiencies;
  showAdvancementInfo(
      context,
      AdvancementInfo(
          kicker: cls.sourceId == null
              ? tr.t('Класс · SRD', 'Class · SRD')
              : tr.t('Класс · библиотека', 'Class · library'),
          title: cls.getName(locale),
          icon: classSigil(cls.id),
          accent: classAccent(context, cls.id),
          text: cls.getDescription(locale),
          facts: [
            tr.t('Кость хитов к${cls.hitDie}', 'Hit die d${cls.hitDie}'),
            if (cls.primaryAbilities.isNotEmpty)
              tr.t('Основная: ', 'Primary: ') +
                  cls.primaryAbilities.map((a) => abilityName(l, a)).join(', '),
            if (cls.savingThrowProficiencies.isNotEmpty)
              tr.t('Спасброски: ', 'Saves: ') +
                  cls.savingThrowProficiencies.map((a) => abilityName(l, a)).join(', '),
          ],
          rows: [
            (
              tr.t('Доспехи', 'Armour'),
              [
                if (armor.light) tr.t('лёгкие', 'light'),
                if (armor.medium) tr.t('средние', 'medium'),
                if (armor.heavy) tr.t('тяжёлые', 'heavy'),
                if (armor.shields) tr.t('щиты', 'shields'),
              ].join(', ').ifEmpty(tr.t('нет', 'none')),
              'shield'
            ),
            (
              tr.t('Оружие', 'Weapons'),
              [
                if (weapons.simple) tr.t('простое', 'simple'),
                if (weapons.martial) tr.t('воинское', 'martial'),
                ...weapons.specific,
              ].join(', ').ifEmpty(tr.t('нет', 'none')),
              'sword'
            ),
            (
              tr.t('Навыки', 'Skills'),
              tr.t('${cls.skillProficiencies.choose} из ${cls.skillProficiencies.from.length}',
                  '${cls.skillProficiencies.choose} of ${cls.skillProficiencies.from.length}'),
              'target'
            ),
          ],
          feats: [
            for (final f in _firstLevel(cls))
              (f.getName(locale), advancementGist(f.getDescription(locale), max: 200),
                  advancementFeatureGlyph(f.iconName)),
          ],
          featsTitle: tr.t('На 1-м уровне', 'At level 1')));
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _ClassChapter extends StatelessWidget {
  const _ClassChapter();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final locale = tr.ru ? 'ru' : 'en';
    final classes = CharacterDataService.getAllClasses();
    return Padding(
      padding: const EdgeInsets.only(bottom: prologueDockRoom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Deck(
          count: classes.length,
          selected: classes.indexWhere((c) => c.id == s.selectedClass?.id),
          builder: (context, i, reveal) {
            final cls = classes[i];
            return _DeckCard(
              title: cls.getName(locale),
              text: advancementGist(cls.getDescription(locale), max: 160),
              facts: [
                tr.t('к${cls.hitDie}', 'd${cls.hitDie}'),
                if (cls.primaryAbilities.isNotEmpty)
                  cls.primaryAbilities.map((a) => abilityName(l, a)).join(', '),
                if (cls.savingThrowProficiencies.isNotEmpty)
                  tr.t('Спасброски: ', 'Saves: ') +
                      cls.savingThrowProficiencies
                          .map((a) => abilityShort(tr, a))
                          .join(', '),
              ],
              glyph: classSigil(cls.id),
              accent: classAccent(context, cls.id),
              selected: s.selectedClass?.id == cls.id,
              source: cls.sourceId == null ? null : tr.t('Библиотека', 'Library'),
              onTap: () {
                s.updateClass(cls);
                reveal();
              },
              onInfo: () => showClassInfo(context, cls),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PrologueHint(tr.t(
              'Удержание карточки — доспехи, оружие, навыки и умения 1-го уровня. Класс из вашей библиотеки стоит в той же колоде.',
              'Hold a card for armour, weapons, skills and level 1 features. Classes from your library are in the same deck.')),
        ),
      ]),
    );
  }
}

/* ---------------- Background ---------------- */

void _backgroundInfo(BuildContext context, BackgroundData b) {
  final tr = Tr(context);
  final l = AppLocalizations.of(context)!;
  final locale = tr.ru ? 'ru' : 'en';
  final accent = AppAccents.of(context).at(5);
  showAdvancementInfo(
      context,
      AdvancementInfo(
          kicker: b.sourceId == null
              ? tr.t('Предыстория · SRD', 'Background · SRD')
              : tr.t('Предыстория · библиотека', 'Background · library'),
          title: b.getName(locale),
          icon: 'book',
          accent: accent,
          text: b.getDescription(locale),
          facts: [
            for (final sk in b.skillProficiencies)
              tr.t('Навык: ', 'Skill: ') + skillName(l, sk),
          ],
          feats: [(b.feature.getName(locale), b.feature.getDescription(locale), 'star')],
          featsTitle: tr.t('Умение предыстории', 'Background feature'),
          rows: [
            if ((b.toolProficiencies[locale] ?? const []).isNotEmpty)
              (tr.t('Инструменты', 'Tools'), b.toolProficiencies[locale]!.join(', '), 'key'),
            if ((b.equipment[locale] ?? const []).isNotEmpty)
              (tr.t('Снаряжение', 'Equipment'), b.equipment[locale]!.join(', '), 'bag'),
          ]));
}

class _BackgroundChapter extends StatelessWidget {
  const _BackgroundChapter();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final locale = tr.ru ? 'ru' : 'en';
    final accent = AppAccents.of(context).at(5);
    final backgrounds = CharacterDataService.shelfBackgrounds();
    return _ChapterList(children: [
      for (final (i, b) in backgrounds.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PageEntrance(
            index: i,
            child: AdvancementPick(
              selected: s.selectedBackground?.id == b.id,
              title: b.getName(locale),
              subtitle: advancementGist(b.getDescription(locale), max: 110),
              icon: 'book',
              accent: accent,
              chips: [
                for (final sk in b.skillProficiencies) skillName(l, sk),
                b.feature.getName(locale),
              ],
              source: b.sourceId == null ? null : tr.t('Библиотека', 'Library'),
              onTap: () => s.updateBackground(b),
              onInfo: () => _backgroundInfo(context, b),
            ),
          ),
        ),
    ]);
  }
}

/* ---------------- Skills ---------------- */

/// A skill capsule (`.ch6`): chosen, it squares its corners and fills.
class PrologueChip extends StatelessWidget {
  const PrologueChip(
      {super.key,
      required this.label,
      required this.selected,
      this.locked = false,
      this.dim = false,
      this.icon,
      this.onTap});
  final String label;
  final bool selected, locked, dim;
  final String? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final green = AppAccents.of(context).at(3);
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    final fg = selected
        ? c.surface
        : locked
            ? Color.lerp(c.onSurface, green, .75)!
            : c.onSurface;
    return AnimatedOpacity(
      duration: AppMotion.of(context, AppMotion.medium),
      opacity: dim ? .4 : 1,
      child: Pressable(
        onTap: dim || locked || onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        scale: .95,
        selected: selected,
        semanticLabel: label,
        child: SelectPulse(
         on: selected,
         child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(selected ? 12 : 19),
            color: selected
                ? c.secondary
                : locked
                    ? pageMix(green, .16, c.surfaceContainerLow)
                    : c.surfaceContainerLow,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              InstrumentGlyph(icon!, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ]),
         ),
        ),
      ),
    );
  }
}

/// A count of the prototype (`.mbar`): a rolling number and what it counts.
class PrologueCount extends StatelessWidget {
  const PrologueCount(
      {super.key,
      required this.value,
      required this.title,
      required this.text,
      required this.accent});
  final int value;
  final String title, text;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: pageMix(accent, .1, c.surfaceContainerLow),
          borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        RollingNumber(value,
            style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w600,
                color: c.onSurface)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600, color: c.onSurface)),
            const SizedBox(height: 2),
            Text(text,
                style: TextStyle(fontSize: 13, height: 1.3, color: c.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _SkillsChapter extends StatelessWidget {
  const _SkillsChapter();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final locale = tr.ru ? 'ru' : 'en';
    final cls = s.selectedClass;
    if (cls == null) return const SizedBox.shrink();
    final accent = prologueAccent(context, s);
    final fromBg = s.selectedBackground?.skillProficiencies ?? const <String>[];
    final need = cls.skillProficiencies.choose;
    final expertise = s.requiredExpertiseCount;
    final proficient = {...fromBg, ...s.selectedSkills}.toList();
    return _ChapterList(children: [
      PrologueCount(
          value: s.selectedSkills.length,
          title: tr.t('из $need навыков класса', 'of $need class skills'),
          text: tr.t('Сверх лимита новый выбор сменит самый ранний',
              'Over the limit a new pick replaces the earliest'),
          accent: accent),
      if (fromBg.isNotEmpty) ...[
        PrologueGroup(tr.t('От предыстории', 'From the background'),
            note: s.selectedBackground!.getName(locale)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final sk in fromBg)
            PrologueChip(label: skillName(l, sk), selected: false, locked: true, icon: 'book'),
        ]),
      ],
      PrologueGroup(tr.t('Навыки класса · ${cls.getName(locale)}',
          'Class skills · ${cls.getName(locale)}')),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final sk in cls.skillProficiencies.from)
          PrologueChip(
            key: ValueKey('prologue-skill-$sk'),
            label: skillName(l, sk),
            selected: s.selectedSkills.contains(sk),
            dim: fromBg.contains(sk),
            onTap: () => s.pickSkill(sk),
          ),
      ]),
      if (expertise > 0) ...[
        PrologueGroup(tr.t('Компетентность', 'Expertise'),
            note: '${s.selectedExpertise.length} / $expertise'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final sk in [...proficient, if (cls.id == 'rogue') 'thieves_tools'])
            PrologueChip(
              label: sk == 'thieves_tools'
                  ? tr.t('Воровские инструменты', 'Thieves\' tools')
                  : skillName(l, sk),
              icon: sk == 'thieves_tools' ? 'key' : 'star',
              selected: s.selectedExpertise.contains(sk),
              onTap: () => s.pickExpertise(sk),
            ),
        ]),
        PrologueHint(tr.t(
            'Компетентность удваивает бонус мастерства. Выбирается из навыков, которыми герой владеет.',
            'Expertise doubles the proficiency bonus. Choose among skills the hero is proficient in.')),
      ],
    ]);
  }
}

/* ---------------- Gear ---------------- */

/// The items of a starting set, counted by name.
List<(String, int, String, String)> prologueItems(String classId, String package, String locale) {
  final out = <String, (String, int, String, String)>{};
  for (final id in starterEquipment(classId, package)) {
    final item = ItemService.createItemFromTemplate(id);
    if (item == null) continue;
    final name = item.getName(locale);
    final glyph = switch (item.type) {
      ItemType.weapon => 'sword',
      ItemType.armor => 'shield',
      ItemType.tool => 'key',
      _ => 'bag',
    };
    final had = out[name];
    out[name] = (name, (had?.$2 ?? 0) + 1,
        advancementGist(item.getDescription(locale), max: 90), glyph);
  }
  return out.values.toList();
}

class _GearChapter extends StatelessWidget {
  const _GearChapter();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final locale = tr.ru ? 'ru' : 'en';
    final cls = s.selectedClass;
    if (cls == null) return const SizedBox.shrink();
    final accent = prologueAccent(context, s);
    final standard = prologueItems(cls.id, 'standard', locale);
    final other = prologueItems(cls.id, 'alternative', locale);
    final sets = [
      ('standard', tr.t('Набор класса', 'Class set'), 'bag', standard),
      if (other.map((e) => e.$1).join() != standard.map((e) => e.$1).join())
        ('alternative', tr.t('Другой набор', 'Another set'), 'swords', other),
      (null, tr.t('Соберу сам', 'I will gather my own'), 'gem',
          <(String, int, String, String)>[]),
    ];
    return _ChapterList(children: [
      for (final (i, (id, name, glyph, items)) in sets.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PageEntrance(
            index: i,
            child: AdvancementPick(
              selected: s.selectedEquipmentPackage == id ||
                  (id == null && s.selectedEquipmentPackage == 'custom'),
              title: name,
              subtitle: items.isEmpty
                  ? tr.t('Без стартовых предметов — добавите в инвентаре',
                      'No starting items — add them in the inventory')
                  : items.take(3).map((e) => e.$1).join(', '),
              icon: glyph,
              accent: accent,
              chips: [
                for (final (n, q, _, _) in items.take(4)) q > 1 ? '$n ×$q' : n,
                if (items.length > 4) '+${items.length - 4}',
              ],
              onTap: () => s.updateEquipmentPackage(id),
              onInfo: items.isEmpty
                  ? null
                  : () => showAdvancementInfo(
                      context,
                      AdvancementInfo(
                          kicker: tr.t('Снаряжение · ${cls.getName(locale)}',
                              'Gear · ${cls.getName(locale)}'),
                          title: name,
                          icon: glyph,
                          accent: accent,
                          feats: [
                            for (final (n, q, t, g) in items)
                              (q > 1 ? '$n × $q' : n, t, g),
                          ],
                          featsTitle: tr.t('Весь состав', 'Everything inside'))),
            ),
          ),
        ),
      PrologueHint(tr.t('Предметы лягут в инвентарь; менять их можно и после создания.',
          'The items go to the inventory; you can change them after creation too.')),
    ]);
  }
}

/* ---------------- The finale ---------------- */

class _Finale extends StatelessWidget {
  const _Finale({required this.compose, required this.leaving});
  final Character Function() compose;
  final bool leaving;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<CharacterCreationState>();
    final tr = Tr(context);
    final l = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final locale = tr.ru ? 'ru' : 'en';
    Character hero;
    try {
      hero = compose();
    } catch (_) {
      return _ChapterList(children: [
        PrologueHint(tr.t('Не удалось собрать героя: вернитесь и проверьте выборы.',
            'The hero could not be put together: go back and check the choices.')),
      ]);
    }
    final cls = s.selectedClass!, race = s.selectedRace!, bg = s.selectedBackground;
    final accent = classAccent(context, cls.id);
    final glow = AppCalm.of(context).glow;
    final scores = hero.abilityScores.toJson();
    final prime = cls.primaryAbilities.take(2).toSet();
    final fromBg = bg?.skillProficiencies.map(ProficiencyIdentity.normalize).toSet() ?? {};
    final fromClass = s.selectedSkills.map(ProficiencyIdentity.normalize).toSet();
    final skills = [
      for (final sk in hero.proficientSkills)
        if (_skillAbility.containsKey(ProficiencyIdentity.normalize(sk))) sk
    ];
    final gear = <String, (String, int, String, String)>{};
    final gearText = <String, String>{};
    for (final item in hero.inventory) {
      final name = item.getName(locale);
      final glyph = switch (item.type) {
        ItemType.weapon => 'sword',
        ItemType.armor => 'shield',
        ItemType.tool => 'key',
        _ => 'bag',
      };
      final had = gear[name];
      gear[name] = (name, (had?.$2 ?? 0) + item.quantity,
          advancementGist(item.getDescription(locale), max: 70), glyph);
      gearText[name] = item.getDescription(locale);
    }
    final items = gear.values.toList();
    final stats = [
      // The table's own short names, so every label fits its tile.
      ('heart', tr.t('ОЗ', 'HP'), hero.maxHp, false),
      ('shield', tr.t('КД', 'AC'), hero.armorClass, false),
      ('bolt', tr.t('Иниц.', 'Init.'), hero.initiative, true),
      ('run', tr.t('Скор.', 'Speed'), hero.speed, false),
      ('star', tr.t('БМ', 'Prof.'), 2, true),
    ];
    final line = [
      s.selectedSubrace?.getName(locale) ?? race.getName(locale),
      cls.getName(locale),
      if (bg != null) bg.getName(locale),
    ].join(' · ');
    final card = AnimatedSlide(
      duration: AppMotion.of(context, const Duration(milliseconds: 420)),
      curve: AppMotion.exit,
      offset: leaving ? const Offset(0, -.2) : Offset.zero,
      child: AnimatedScale(
        duration: AppMotion.of(context, const Duration(milliseconds: 420)),
        curve: AppMotion.exit,
        scale: leaving ? .55 : 1,
        child: AnimatedOpacity(
          duration: AppMotion.of(context, const Duration(milliseconds: 420)),
          opacity: leaving ? 0 : 1,
          child: _Rise(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                    begin: const Alignment(-.6, -1),
                    end: const Alignment(.6, 1),
                    colors: [
                      pageMix(accent, .26, c.surfaceContainerLow),
                      pageMix(accent, .06, c.surfaceContainerLow)
                    ],
                    stops: const [0, .75]),
                border: Border.all(color: accent.withValues(alpha: .3)),
                boxShadow: [
                  if (glow > 0)
                    BoxShadow(
                        color: accent.withValues(alpha: .5 * glow),
                        blurRadius: 50,
                        spreadRadius: -32,
                        offset: const Offset(0, 26)),
                ],
              ),
              child: Stack(children: [
                Positioned(
                  right: -30,
                  top: -26,
                  child: InstrumentGlyph(classSigil(cls.id),
                      size: 190, color: accent.withValues(alpha: .22)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: accent, borderRadius: BorderRadius.circular(30)),
                        child: Text(hero.name.characters.first.toUpperCase(),
                            style: TextStyle(
                                fontFamily: AppType.display,
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                color: pageOnAccent(c))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          PageCap(tr.t('Новый герой · 1-й уровень', 'New hero · level 1'),
                              accent: accent),
                          const SizedBox(height: 5),
                          Text(hero.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AppType.display,
                                  fontSize: 30,
                                  height: 1.05,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.9,
                                  color: c.onSurface)),
                          const SizedBox(height: 5),
                          Text(line,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: c.onSurface.withValues(alpha: .75))),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      for (final (i, (glyph, name, value, sign)) in stats.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            decoration: BoxDecoration(
                                color: c.surface.withValues(alpha: .45),
                                borderRadius: BorderRadius.circular(18)),
                            child: Column(children: [
                              InstrumentGlyph(glyph, size: 17, color: accent),
                              const SizedBox(height: 5),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (sign)
                                    Text(value < 0 ? '−' : '+',
                                        style: TextStyle(
                                            fontFamily: AppType.display,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: c.onSurface)),
                                  // The numbers count up from nothing as the card arrives.
                                  RollingNumber(value.abs(),
                                      from: 0,
                                      style: TextStyle(
                                          fontFamily: AppType.display,
                                          fontSize: 22,
                                          height: 1,
                                          fontWeight: FontWeight.w600,
                                          color: c.onSurface)),
                                ]),
                              ),
                              const SizedBox(height: 5),
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, color: c.onSurfaceVariant)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    final features = [
      for (final f in hero.features) (f.getName(locale), f.getDescription(locale), advancementFeatureGlyph(f.iconName), cls.getName(locale)),
      if (bg != null)
        (bg.feature.getName(locale), bg.feature.getDescription(locale), 'book', bg.getName(locale)),
    ];
    var wave = 0;
    Widget enter(Widget child) => PageEntrance(index: wave++, child: child);
    return _ChapterList(children: [
      card,
      enter(PrologueGroup(tr.t('Характеристики', 'Abilities'),
          note: tr.t('с бонусами народа', 'with the people\'s bonuses'))),
      enter(LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 16) / 3;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final key in CharacterCreationState.abilityKeys)
            Container(
              width: w,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: prime.contains(key) ? null : c.surfaceContainerLow,
                gradient: prime.contains(key)
                    ? LinearGradient(
                        begin: const Alignment(-.6, -1),
                        end: const Alignment(.6, 1),
                        colors: [pageMix(accent, .16, c.surfaceContainerLow), c.surfaceContainerLow],
                        stops: const [0, .7])
                    : null,
                border: Border.all(
                    color: prime.contains(key)
                        ? accent.withValues(alpha: .35)
                        : Colors.transparent,
                    width: 1.5),
              ),
              child: Column(children: [
                Text(abilityShort(tr, key),
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .92,
                        color: c.onSurfaceVariant)),
                const SizedBox(height: 6),
                RollingNumber(scores[key] as int,
                    from: 0,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(_signed(_mod(scores[key] as int)),
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color.lerp(c.onSurface, accent, .8))),
                ),
              ]),
            ),
        ]);
      })),
      if (skills.isNotEmpty) ...[
        enter(PrologueGroup(tr.t('Навыки', 'Skills'),
            note: tr.t('${skills.length} · бонус мастерства +2',
                '${skills.length} · proficiency bonus +2'))),
        for (final sk in skills)
          enter(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Builder(builder: (context) {
              final id = ProficiencyIdentity.normalize(sk);
              final ab = _skillAbility[id]!;
              final expert = hero.expertSkills.map(ProficiencyIdentity.normalize).contains(id);
              final bonus = _mod(scores[ab] as int) + (expert ? 4 : 2);
              final source = fromBg.contains(id)
                  ? tr.t('предыстория', 'background')
                  : fromClass.contains(id)
                      ? tr.t('класс', 'class')
                      : tr.t('народ', 'people');
              return Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  PageSeal(fromBg.contains(id) ? 'book' : 'target',
                      accent: fromBg.contains(id) ? AppAccents.of(context).at(5) : accent,
                      size: PageSealSize.sm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(skillName(l, sk),
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600, color: c.onSurface)),
                      Text('${abilityShort(tr, ab)} · $source${expert ? tr.t(' · компетентность', ' · expertise') : ''}',
                          style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant)),
                    ]),
                  ),
                  Text(_signed(bonus),
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color.lerp(c.onSurface, accent, .8))),
                ]),
              );
            }),
          )),
      ],
      if (features.isNotEmpty) ...[
        enter(PrologueGroup(tr.t('Умения', 'Features'),
            note: tr.t('касание — подробно', 'tap for details'))),
        for (final (name, text, glyph, source) in features)
          enter(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdvancementGain(
              icon: glyph,
              title: name,
              text: '$source · ${advancementGist(text, max: 90)}',
              accent: accent,
              onTap: () => showAdvancementInfo(
                  context,
                  AdvancementInfo(
                      kicker: source, title: name, icon: glyph, accent: accent, text: text)),
            ),
          )),
      ],
      if (items.isNotEmpty) ...[
        enter(PrologueGroup(tr.t('Снаряжение', 'Gear'),
            note: tr.t('${items.length} предм.', '${items.length} items'))),
        enter(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The first and an even last tile run the full width; the rest
          // stand in pairs of equal height.
          for (final row in _gearRows(items.length))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (k, i) in row.indexed) ...[
                    if (k > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _GearTile(
                        name: items[i].$1,
                        count: items[i].$2,
                        text: items[i].$3,
                        glyph: items[i].$4,
                        wide: row.length == 1,
                        accent: accent,
                        onTap: () => showAdvancementInfo(
                            context,
                            AdvancementInfo(
                                kicker: tr.t('Снаряжение', 'Gear'),
                                title: items[i].$1,
                                icon: items[i].$4,
                                accent: accent,
                                text: gearText[items[i].$1] ?? '',
                                facts: [
                                  if (items[i].$2 > 1)
                                    tr.t('Количество: ${items[i].$2}', 'Quantity: ${items[i].$2}'),
                                ])),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
        ])),
      ],
    ]);
  }
}

/// Rows of gear tiles: the first alone, then pairs; an odd one out at the
/// end runs the full width too.
List<List<int>> _gearRows(int n) {
  if (n == 0) return [];
  final rows = <List<int>>[
    [0]
  ];
  for (var i = 1; i < n; i += 2) {
    rows.add([i, if (i + 1 < n) i + 1]);
  }
  return rows;
}

/// A gear tile (`.gi6`): in a pair the seal stands on top of the name, the
/// wide one reads in a row; a count sits in the corner. A tap opens it.
class _GearTile extends StatelessWidget {
  const _GearTile(
      {required this.name,
      required this.count,
      required this.text,
      required this.glyph,
      required this.wide,
      required this.accent,
      required this.onTap});
  final String name, text, glyph;
  final int count;
  final bool wide;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: 14, height: 1.2, fontWeight: FontWeight.w600, color: c.onSurface)),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.35, color: c.onSurfaceVariant)),
          ],
        ]);
    final badge = count > 1
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: accent.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(10)),
            child: Text('×$count',
                style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(c.onSurface, accent, .8))),
          )
        : null;
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: .97,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              begin: const Alignment(-.6, -1),
              end: const Alignment(.6, 1),
              colors: [pageMix(accent, .09, c.surfaceContainerLow), c.surfaceContainerLow],
              stops: const [0, .7]),
        ),
        child: wide
            ? Row(children: [
                PageSeal(glyph, accent: accent, size: PageSealSize.sm),
                const SizedBox(width: 12),
                Expanded(child: words),
                if (badge != null) ...[const SizedBox(width: 8), badge],
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PageSeal(glyph, accent: accent, size: PageSealSize.sm),
                  const Spacer(),
                  if (badge != null) badge,
                ]),
                const SizedBox(height: 10),
                words,
              ]),
      ),
    );
  }
}


/// The finale's card rises into place.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
        duration: AppMotion.of(context, AppMotion.gentleSettle),
        curve: AppMotion.gentleCurve,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: Transform.scale(scale: .94 + .06 * t, child: child),
          ),
        ),
        child: child,
      );
}

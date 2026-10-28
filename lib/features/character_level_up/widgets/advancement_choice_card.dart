import 'package:flutter/material.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/page_kit.dart';
import 'advancement_climb.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/advancement_choice.dart';
import '../../../../core/progression/proficiency_identity.dart';
import 'advancement_choice_captions.dart';
import 'advancement_selection.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class AdvancementChoiceCard extends StatefulWidget {
  const AdvancementChoiceCard(
      {super.key,
      required this.choice,
      required this.character,
      required this.classLevel,
      required this.title,
      required this.selected,
      required this.labelFor,
      required this.onChanged,
      this.accent});
  final AdvancementChoice choice;
  final Character character;
  final int classLevel;
  final String title;
  final Set<String> selected;
  final String Function(AdvancementOption) labelFor;
  final ValueChanged<Set<String>> onChanged;
  final Color? accent;
  @override
  State<AdvancementChoiceCard> createState() => _AdvancementChoiceCardState();
}

class _AdvancementChoiceCardState extends State<AdvancementChoiceCard> {
  bool get _ru => Localizations.localeOf(context).languageCode == 'ru';
  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200);
  String _label(AdvancementOption o) {
    final text = widget.labelFor(o);
    return text.startsWith('${widget.title}: ')
        ? text.substring(widget.title.length + 2)
        : text;
  }

  bool _already(AdvancementOption o) => widget.choice.kind ==
          AdvancementChoiceKind.skillProficiency
      ? ProficiencyIdentity.contains(widget.character.proficientSkills, o.id)
      : widget.choice.kind == AdvancementChoiceKind.feature &&
          widget.character.hasFeatureId(o.id);
  String? _reason(AdvancementOption o) {
    if (_already(o)) return _ru ? 'Уже освоено' : 'Already learned';
    if (o.minimumClassLevel > widget.classLevel) {
      return _ru
          ? 'С ${o.minimumClassLevel}-го уровня класса'
          : 'Class level ${o.minimumClassLevel} required';
    }
    if (!o.available(widget.character, widget.classLevel)) {
      return _ru
          ? 'Нужны связанные умения или заклинания'
          : 'Requires related features or spells';
    }
    return null;
  }

  /// Options shown in the card itself; the rest open in a sheet.
  static const _shown = 5;

  Set<String> _toggled(Set<String> selected, AdvancementOption o) {
    if (!selected.contains(o.id) && _reason(o) != null) return selected;
    HapticFeedback.selectionClick();
    return toggleAdvancementSelection(selected, o.id, widget.choice.count);
  }

  String _glyph(AdvancementOption o) =>
      widget.choice.kind == AdvancementChoiceKind.skillProficiency
          ? 'target'
          : o.feature?.iconName == null
              ? 'spark'
              : advancementFeatureGlyph(o.feature!.iconName);

  Color _accent(BuildContext context) =>
      widget.accent ?? Theme.of(context).colorScheme.secondary;

  void _details(AdvancementOption o) {
    final reason = _reason(o);
    showAdvancementInfo(
        context,
        AdvancementInfo(
            kicker: widget.title,
            title: _label(o),
            icon: _glyph(o),
            accent: _accent(context),
            text: [
              o.feature?.getDescription(_ru ? 'ru' : 'en') ??
                  (_ru
                      ? 'Новое владение для проверок навыка.'
                      : 'A new proficiency for skill checks.'),
              if (reason != null) reason,
            ].join('\n\n')));
  }

  List<AdvancementOption> get _known => widget.choice.options
      .where((o) =>
          o.feature != null ||
          widget.choice.kind != AdvancementChoiceKind.feature)
      .toList();

  // Every option, searchable, in a sheet of the same cards.
  Future<void> _all() async {
    var picked = widget.selected;
    var query = '';
    await showCompanionSheet<void>(context, builder: (sheet) {
      return StatefulBuilder(builder: (sheet, setSheet) {
        final known = _known;
        final shown = known
            .where((o) => _label(o).toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageSheetHead(
              kicker: widget.title,
              title: _ru ? 'Все варианты' : 'All options',
              sub: _ru
                  ? 'Выбрано ${picked.length} из ${widget.choice.count} · ${known.length} вариантов'
                  : '${picked.length} of ${widget.choice.count} chosen · ${known.length} options'),
          if (known.length > 8) ...[
            const SizedBox(height: 14),
            _Search(
                hint: _ru ? 'Найти вариант' : 'Find an option',
                onChanged: (v) => setSheet(() => query = v)),
          ],
          const SizedBox(height: 14),
          for (final o in shown)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _tile(o, picked, (next) {
                  setSheet(() => picked = next);
                  widget.onChanged(next);
                })),
          if (shown.isEmpty)
            Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_ru ? 'Ничего не найдено' : 'Nothing found',
                    textAlign: TextAlign.center)),
        ]);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final known = _known;
    final visible = [
      for (final (i, o) in known.indexed)
        if (i < _shown || widget.selected.contains(o.id)) o
    ];
    final complete = widget.choice
        .isSatisfied(widget.selected, widget.character, widget.classLevel);
    final accent = _accent(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // A group title of the prototype with the count as a pill.
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        fontFamily: AppType.display,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: c.onSurface))),
            const SizedBox(width: 12),
            AnimatedContainer(
                duration: _motion,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: complete
                        ? accent
                        : c.onSurface.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(complete ? 10 : 16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (complete) ...[
                    Icon(Icons.check_rounded, size: 15, color: pageOnAccent(c)),
                    const SizedBox(width: 4)
                  ],
                  Text('${widget.selected.length}/${widget.choice.count}',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: complete ? pageOnAccent(c) : c.onSurface))
                ]))
          ]),
          const SizedBox(height: 4),
          Text(
              AppLocalizations.of(context)!
                  .advancementChooseOptions(widget.choice.count),
              style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
          if (known.length != widget.choice.options.length ||
              known.length < widget.choice.count)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    _ru
                        ? 'В подключённых источниках не хватает данных для этого выбора.'
                        : 'The installed sources do not contain enough data for this choice.',
                    style: TextStyle(color: c.error))),
          const SizedBox(height: 12),
          for (final o in visible)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _tile(o, widget.selected, widget.onChanged)),
          if (known.length > visible.length)
            Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                key: const ValueKey('advancement-choice-all'),
                onTap: _all,
                haptic: true,
                scale: .96,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(19)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LineIcon('grid', size: 16, color: accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                          _ru
                              ? 'Все варианты · ${known.length}'
                              : 'All options · ${known.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.onSurface)),
                    ),
                    const SizedBox(width: 4),
                    LineIcon('forward', size: 14, color: c.onSurfaceVariant),
                  ]),
                ),
              ),
            ),
        ]));
  }

  Widget _tile(AdvancementOption o, Set<String> selected,
      ValueChanged<Set<String>> changed) {
    final on = selected.contains(o.id);
    final reason = _reason(o);
    final enabled = on || reason == null && widget.choice.count > 0;
    final description = AdvancementChoiceCaptions.forFeature(
            o.feature, AppLocalizations.of(context)!) ??
        o.feature?.getDescription(_ru ? 'ru' : 'en') ??
        (_ru ? 'Владение навыком' : 'Skill proficiency');
    return AdvancementPick(
      key: ValueKey('advancement-option-${o.id}'),
      selected: on,
      multi: widget.choice.count > 1,
      blocked: !enabled,
      title: _label(o),
      subtitle: reason ?? advancementGist(description, max: 120),
      icon: _glyph(o),
      accent: _accent(context),
      onTap: () {
        final next = _toggled(selected, o);
        if (!identical(next, selected)) changed(next);
      },
      onInfo: () => _details(o),
    );
  }
}

/// The search field of a long list of options.
class _Search extends StatelessWidget {
  const _Search({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return TextField(
      autofocus: false,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: LineIcon('search', size: 20, color: c.onSurfaceVariant)),
        filled: true,
        fillColor: c.surfaceContainerLow,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: c.secondary.withValues(alpha: .5))),
      ),
    );
  }
}

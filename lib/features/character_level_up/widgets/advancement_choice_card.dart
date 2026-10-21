import 'package:flutter/material.dart';
import '../../../core/ui/companion_surface.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/advancement_choice.dart';
import '../../../../core/progression/proficiency_identity.dart';
import '../../../../core/ui/sheet_drag_region.dart';
import 'advancement_choice_captions.dart';
import 'advancement_selection.dart';

class AdvancementChoiceCard extends StatefulWidget {
  const AdvancementChoiceCard(
      {super.key,
      required this.choice,
      required this.character,
      required this.classLevel,
      required this.title,
      required this.selected,
      required this.labelFor,
      required this.onChanged});
  final AdvancementChoice choice;
  final Character character;
  final int classLevel;
  final String title;
  final Set<String> selected;
  final String Function(AdvancementOption) labelFor;
  final ValueChanged<Set<String>> onChanged;
  @override
  State<AdvancementChoiceCard> createState() => _AdvancementChoiceCardState();
}

class _AdvancementChoiceCardState extends State<AdvancementChoiceCard> {
  bool _expanded = false;
  String _query = '';
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

  IconData _icon(AdvancementOption o) => switch (o.id) {
        'metamagic-careful-spell' => Icons.shield_outlined,
        'metamagic-distant-spell' => Icons.open_in_full_rounded,
        'metamagic-empowered-spell' => Icons.auto_awesome_rounded,
        'metamagic-extended-spell' => Icons.schedule_rounded,
        'metamagic-heightened-spell' => Icons.flare_rounded,
        'metamagic-quickened-spell' => Icons.bolt_rounded,
        'metamagic-subtle-spell' => Icons.visibility_off_outlined,
        'metamagic-twinned-spell' => Icons.filter_2_rounded,
        _ => widget.choice.kind == AdvancementChoiceKind.skillProficiency
            ? Icons.school_outlined
            : Icons.auto_awesome_rounded,
      };
  void _toggle(AdvancementOption o) {
    if (!widget.selected.contains(o.id) && _reason(o) != null) return;
    final next =
        toggleAdvancementSelection(widget.selected, o.id, widget.choice.count);
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _details(AdvancementOption o) {
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Icon(_icon(o),
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(_label(o),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                      o.feature?.getDescription(_ru ? 'ru' : 'en') ??
                          (_ru
                              ? 'Новое владение для проверок навыка.'
                              : 'A new proficiency for skill checks.'),
                      style: Theme.of(context).textTheme.bodyLarge),
                  if (_reason(o) != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_reason(o)!,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant))),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final known = widget.choice.options
        .where((o) =>
            o.feature != null ||
            widget.choice.kind != AdvancementChoiceKind.feature)
        .toList();
    final filtered = known
        .where((o) => _label(o).toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final visible = _expanded || _query.isNotEmpty
        ? filtered
        : filtered
            .where(
                (o) => known.indexOf(o) < 4 || widget.selected.contains(o.id))
            .toList();
    final complete = widget.choice
        .isSatisfied(widget.selected, widget.character, widget.classLevel);
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: Text(widget.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600))),
            const SizedBox(width: 12),
            AnimatedContainer(
                duration: _motion,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: complete
                        ? colors.primaryContainer
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (complete) ...[
                    Icon(Icons.check_rounded,
                        size: 16, color: colors.onPrimaryContainer),
                    const SizedBox(width: 5)
                  ],
                  Text('${widget.selected.length}/${widget.choice.count}',
                      style: theme.textTheme.labelLarge)
                ]))
          ]),
          const SizedBox(height: 6),
          Text(
              AppLocalizations.of(context)!
                  .advancementChooseOptions(widget.choice.count),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant)),
          if (known.length != widget.choice.options.length ||
              known.length < widget.choice.count)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    _ru
                        ? 'В подключённых источниках не хватает данных для этого выбора.'
                        : 'The installed sources do not contain enough data for this choice.',
                    style: TextStyle(color: colors.error))),
          if (known.length > 8 && _expanded)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: _ru ? 'Найти вариант' : 'Find an option'),
                    onChanged: (v) => setState(() => _query = v))),
          const SizedBox(height: 16),
          AnimatedSize(
              duration: _motion,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(children: [
                for (final o in visible)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _tile(o)),
              ])),
          if (known.length > 4)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextButton.icon(
                    onPressed: () => setState(() {
                          _expanded = !_expanded;
                          _query = '';
                        }),
                    icon: Icon(_expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded),
                    label: Text(_expanded
                        ? (_ru ? 'Свернуть' : 'Show less')
                        : (_ru
                            ? 'Все варианты · ${known.length}'
                            : 'All options · ${known.length}')))),
        ]));
  }

  Widget _tile(AdvancementOption o) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = widget.selected.contains(o.id);
    final reason = _reason(o);
    final enabled = selected || reason == null && widget.choice.count > 0;
    final description = AdvancementChoiceCaptions.forFeature(
            o.feature, AppLocalizations.of(context)!) ??
        o.feature?.getDescription(_ru ? 'ru' : 'en') ??
        (_ru ? 'Владение навыком' : 'Skill proficiency');
    return Semantics(
        checked: selected,
        enabled: enabled,
        child: CompanionSurface(
          color:
              selected ? colors.secondaryContainer : colors.surfaceContainerLow,
          contour: CompanionContour.focus,
          raised: selected,
          quiet: !selected,
          padding: EdgeInsets.zero,
          child: InkWell(
            key: ValueKey('advancement-option-${o.id}'),
            onTap: enabled ? () => _toggle(o) : null,
            onLongPress: () => _details(o),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                          duration: _motion,
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: selected
                                  ? colors.secondary
                                  : colors.surfaceContainerHigh,
                              borderRadius:
                                  BorderRadius.circular(selected ? 12 : 18)),
                          child: Icon(selected ? Icons.check_rounded : _icon(o),
                              size: 20,
                              color: selected
                                  ? colors.onSecondary
                                  : colors.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_label(o),
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: enabled
                                        ? colors.onSurface
                                        : colors.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(reason ?? description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                          ])),
                      IconButton(
                          tooltip:
                              AppLocalizations.of(context)!.advancementDetails,
                          onPressed: () => _details(o),
                          icon: Icon(Icons.info_outline_rounded,
                              size: 20, color: colors.onSurfaceVariant)),
                    ])),
          ),
        ));
  }
}

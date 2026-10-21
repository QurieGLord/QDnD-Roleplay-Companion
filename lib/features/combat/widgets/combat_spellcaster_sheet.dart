import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/magic/spell_use.dart';
import '../../../core/search/journal_search.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../core/ui/sheet_drag_region.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/spell_cast_sheet.dart';
import '../../../shared/widgets/spell_details_sheet.dart';
import '../../character_sheet/widgets/spell_slots_widget.dart';

class CombatSpellcasterSheet extends StatefulWidget {
  const CombatSpellcasterSheet(
      {super.key, required this.character, required this.onStateChange});
  final Character character;
  final VoidCallback onStateChange;
  @override
  State<CombatSpellcasterSheet> createState() => _CombatSpellcasterSheetState();
}

class _CombatSpellcasterSheetState extends State<CombatSpellcasterSheet> {
  String _query = '';
  bool _casting = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        ru = Localizations.localeOf(context).languageCode == 'ru',
        t = Theme.of(context).textTheme;
    final search = JournalSearch(_query),
        spells = SpellUse.visible(widget.character)
            .where((s) => search
                .matches([s.getName(ru ? 'ru' : 'en'), s.nameEn, s.nameRu]))
            .toList()
          ..sort((a, b) => a.level != b.level
              ? a.level.compareTo(b.level)
              : a
                  .getName(ru ? 'ru' : 'en')
                  .compareTo(b.getName(ru ? 'ru' : 'en')));
    return DraggableScrollableSheet(
        initialChildSize: .85,
        minChildSize: .45,
        maxChildSize: .96,
        expand: false,
        builder: (context, scroll) =>
            CustomScrollView(controller: scroll, slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SheetDragRegion(
                                enabled: !_casting,
                                child: Row(children: [
                                  Expanded(
                                      child: Text(l.castSpell,
                                          style: t.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w800))),
                                  IconButton(
                                      tooltip: l.cancel,
                                      onPressed: _casting
                                          ? null
                                          : () => Navigator.pop(context),
                                      icon: const Icon(Icons.close_rounded))
                                ])),
                            const SizedBox(height: 12),
                            SpellSlotsWidget(
                                character: widget.character,
                                showArcanum: false,
                                onChanged: () {
                                  setState(() {});
                                  widget.onStateChange();
                                }),
                            const SizedBox(height: 12),
                            TextField(
                                autofocus: false,
                                decoration: InputDecoration(
                                    hintText: l.searchSpells,
                                    prefixIcon:
                                        const Icon(Icons.search_rounded)),
                                onChanged: (v) => setState(() => _query = v)),
                          ]))),
              if (spells.isEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(l.noSpellsFound))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.builder(
                      itemCount: spells.length,
                      itemBuilder: (context, index) {
                        final spell = spells[index];
                        List<SpellUseSource> sources = [];
                        try {
                          sources = SpellUse.sources(widget.character, spell);
                        } catch (_) {}
                        final ready = sources.any((s) => s.ready || s.ritual);
                        return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CompanionSurface(
                                contour: CompanionContour.focus,
                                quiet: !ready,
                                padding: const EdgeInsets.all(15),
                                onTap: _casting
                                    ? null
                                    : () async {
                                        setState(() => _casting = true);
                                        try {
                                          final applied =
                                              await showSpellCastSheet(context,
                                                  widget.character, spell);
                                          if (mounted && applied) {
                                            widget.onStateChange();
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _casting = false);
                                          }
                                        }
                                      },
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(spell.getName(ru ? 'ru' : 'en'),
                                            style: t.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 5),
                                        Text(
                                            '${spell.level == 0 ? l.cantrips : l.levelLabel(spell.level)} · ${sources.map((s) => s.label(ru ? 'ru' : 'en')).join(' / ')}',
                                            style: t.bodySmall),
                                        if (!ready)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 5),
                                              child: Text(
                                                  ru
                                                      ? 'Проверь источник и подготовку'
                                                      : 'Check source and preparation',
                                                  style: t.labelSmall)),
                                      ])),
                                  IconButton(
                                      tooltip: ru ? 'Описание' : 'Details',
                                      onPressed: () =>
                                          showResponsiveSheet<void>(
                                              context: context,
                                              isScrollControlled: true,
                                              useSafeArea: true,
                                              builder: (_) => SpellDetailsSheet(
                                                  spell: spell,
                                                  character: widget.character,
                                                  editable: true,
                                                  onChanged: () {
                                                    setState(() {});
                                                    widget.onStateChange();
                                                  })),
                                      icon: const Icon(
                                          Icons.info_outline_rounded))
                                ])));
                      })),
            ]));
  }
}

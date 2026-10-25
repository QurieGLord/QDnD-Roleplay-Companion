import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/magic/magic_slots.dart';
import '../../core/models/character.dart';
import '../../core/models/character_feature.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/services/feature_slot_actions_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';

Future<bool?> showPrimevalAwarenessSheet(
        BuildContext context, Character hero, CharacterFeature feature) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _FeatureSlotSheet(hero: hero, feature: feature));

class _FeatureSlotSheet extends StatefulWidget {
  const _FeatureSlotSheet({required this.hero, required this.feature});
  final Character hero;
  final CharacterFeature feature;
  @override
  State<_FeatureSlotSheet> createState() => _FeatureSlotSheetState();
}

class _FeatureSlotSheetState extends State<_FeatureSlotSheet> {
  MagicPool _pool = MagicPool.shared;
  int? _circle;
  bool _busy = false, _ruling = false;
  late final String _digest, _classId;
  @override
  void initState() {
    super.initState();
    final entry = CharacterClassContext(widget.hero, 'ranger').entry!;
    _classId = entry.id;
    _digest = CharacterClassRules.resolve(entry).snapshot['digest'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru',
        theme = Theme.of(context),
        c = theme.colorScheme;
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(widget.hero);
    } catch (_) {}
    final reserve = slots;
    final circles = reserve == null
        ? <int>[]
        : [
            for (var i = 1; i <= 9; i++)
              if (reserve.remaining(_pool, i) > 0) i
          ];
    final circle = circles.contains(_circle) ? _circle : circles.firstOrNull;
    return PopScope(
        canPop: !_busy,
        child: KeyboardPadding(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                24, 12, 24, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.feature.getName(ru ? 'ru' : 'en'),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                      ru
                          ? 'Почувствуй присутствие существ вокруг. Мастер сообщит результат; выбранная ячейка задаёт длительность.'
                          : 'Sense the presence of creatures around you. Your GM gives the result; the chosen slot determines the duration.',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  CompanionSurface(
                      contour: CompanionContour.focus,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ru ? 'Из какого запаса?' : 'Which reserve?',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final pool in MagicPool.values)
                                if (pool == MagicPool.shared ||
                                    reserve?.pact != null)
                                  ChoiceChip(
                                      label: Text(pool == MagicPool.shared
                                          ? (ru
                                              ? 'Общие ячейки'
                                              : 'Shared slots')
                                          : (ru
                                              ? 'Магия договора'
                                              : 'Pact Magic')),
                                      selected: _pool == pool,
                                      showCheckmark: false,
                                      onSelected: _busy
                                          ? null
                                          : (_) {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _pool = pool;
                                                _circle = null;
                                                _ruling = false;
                                              });
                                            })
                            ]),
                            const SizedBox(height: 20),
                            if (reserve == null)
                              Text(ru
                                  ? 'Сначала уточни разделение ячеек в листе.'
                                  : 'Resolve the slot reserves on your sheet first.')
                            else if (circles.isEmpty)
                              Text(ru
                                  ? 'В этом запасе не осталось ячеек.'
                                  : 'No slots remain in this reserve.')
                            else
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                for (final n in circles)
                                  ChoiceChip(
                                      label: Text(ru
                                          ? '$n круг · ${reserve.remaining(_pool, n)}'
                                          : 'Level $n · ${reserve.remaining(_pool, n)}'),
                                      selected: circle == n,
                                      showCheckmark: false,
                                      onSelected: _busy
                                          ? null
                                          : (_) {
                                              HapticFeedback.selectionClick();
                                              setState(() => _circle = n);
                                            })
                              ]),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                child: Text(
                                    circle == null
                                        ? '—'
                                        : (ru ? '$circle мин.' : '$circle min'),
                                    key: ValueKey(circle),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: c.secondary))),
                            const SizedBox(height: 6),
                            Text(
                                ru
                                    ? 'Одна ячейка. Концентрация сохраняется.'
                                    : 'One slot. Concentration is preserved.',
                                style: theme.textTheme.bodyMedium),
                          ])),
                  if (_pool == MagicPool.pact)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _ruling,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _ruling = v == true),
                            title: Text(ru
                                ? 'Мастер разрешил Магию договора'
                                : 'GM permits Pact Magic payment'),
                            subtitle: Text(ru
                                ? 'В описании умения указана ячейка следопыта.'
                                : 'The feature specifies a ranger spell slot.'))),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: _busy ||
                              circle == null ||
                              (_pool == MagicPool.pact && !_ruling)
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await FeatureSlotActionsService
                                    .primevalAwareness(widget.hero,
                                        classId: _classId,
                                        featureId: widget.feature.id,
                                        pool: _pool,
                                        circle: circle,
                                        locale: ru ? 'ru' : 'en',
                                        expectedRulesDigest: _digest,
                                        tableRuling: _ruling);
                                if (!context.mounted) return;
                                HapticFeedback.lightImpact();
                                Navigator.pop(context, true);
                              } catch (_) {
                                if (!context.mounted) return;
                                setState(() => _busy = false);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(ru
                                        ? 'Не удалось применить умение. Проверь выбранный запас.'
                                        : 'Could not use the ability. Check the selected reserve.')));
                              }
                            },
                      icon: const Icon(Icons.explore_rounded),
                      label:
                          Text(ru ? 'Ощутить присутствие' : 'Sense presence')),
                ]))));
  }
}

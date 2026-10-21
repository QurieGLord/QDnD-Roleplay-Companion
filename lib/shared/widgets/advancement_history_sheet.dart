import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/character.dart';
import '../../core/progression/advancement_history.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';

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
  bool _busy = false;
  String? _issue;
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru',
        theme = Theme.of(context),
        c = theme.colorScheme;
    List<AdvancementRecord> records = [];
    bool readable = true;
    try {
      records = AdvancementHistory.read(widget.hero);
    } catch (_) {
      readable = false;
    }
    return PopScope(
        canPop: !_busy,
        child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ru ? 'История повышений' : 'Level-up history',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                      ru
                          ? 'Отмени одно или несколько последних повышений. Журнал, имущество и текущие ОЗ сохранятся.'
                          : 'Revert one or more recent level-ups. Your journal, belongings and current HP are preserved.',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                  if (!readable)
                    CompanionSurface(
                        quiet: true,
                        child: Text(ru
                            ? 'История недоступна в этой версии. Сохранённые сведения оставлены без изменений.'
                            : 'This history is unavailable in this version. Saved records are preserved.'))
                  else if (records.isEmpty)
                    CompanionSurface(
                        quiet: true,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.auto_stories_rounded,
                                  color: c.secondary, size: 32),
                              const SizedBox(height: 14),
                              Text(
                                  ru
                                      ? 'Первое повышение откроет историю'
                                      : 'Your next level-up starts the history',
                                  style: theme.textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(
                                  ru
                                      ? 'Здесь появятся новые подтверждённые повышения. Для прежних уровней решения ещё не записывались.'
                                      : 'New confirmed level-ups will appear here. Earlier choices were not recorded.',
                                  style: theme.textTheme.bodyMedium),
                            ]))
                  else ...[
                    for (final record in (_preview == null
                        ? records.reversed
                        : <AdvancementRecord>[]))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CompanionSurface(
                              onTap: _busy
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _issue = null;
                                        try {
                                          _preview = AdvancementHistory.preview(
                                              widget.hero, record.id);
                                        } catch (_) {
                                          _preview = null;
                                          _issue = ru
                                              ? 'После этого повышения некоторые решения были изменены вручную. Автоматический откат не сможет сохранить их однозначно.'
                                              : 'Some choices were edited after this level-up. They cannot be preserved unambiguously by an automatic rollback.';
                                        }
                                      });
                                    },
                              quiet: _preview?.targetId != record.id,
                              contour: CompanionContour.soft,
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          CharacterClassContext(
                                                  widget.hero, record.classId)
                                              .name(ru ? 'ru' : 'en'),
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      Text(
                                          ru
                                              ? 'Уровень героя ${record.from} → ${record.to}'
                                              : 'Character level ${record.from} → ${record.to}',
                                          style: theme.textTheme.bodyMedium),
                                    ])),
                                const SizedBox(width: 12),
                                Icon(
                                    _preview?.targetId == record.id
                                        ? Icons.check_circle_rounded
                                        : Icons.history_rounded,
                                    color: c.secondary),
                              ]))),
                    if (_issue != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_issue!,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: c.error))),
                    if (_preview != null) ...[
                      TextButton.icon(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _preview = null),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: Text(ru
                              ? 'Выбрать другое повышение'
                              : 'Choose another level-up')),
                      const SizedBox(height: 12),
                      CompanionSurface(
                          contour: CompanionContour.focus,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ru ? 'После отката' : 'After reverting',
                                    style: theme.textTheme.titleLarge),
                                const SizedBox(height: 14),
                                Text(
                                    _preview!.result.classes
                                        .map((entry) =>
                                            '${CharacterClassContext(_preview!.result, entry.id).name(ru ? 'ru' : 'en')} ${entry.level}')
                                        .join(' / '),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 12),
                                Text(
                                    ru
                                        ? 'Максимум ОЗ: ${widget.hero.maxHp} → ${_preview!.result.maxHp}\nТекущие ОЗ: ${widget.hero.currentHp}'
                                        : 'Maximum HP: ${widget.hero.maxHp} → ${_preview!.result.maxHp}\nCurrent HP: ${widget.hero.currentHp}',
                                    style: theme.textTheme.bodyLarge),
                                const SizedBox(height: 12),
                                ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                        ru ? 'Что изменится' : 'What changes'),
                                    children: [
                                      for (final feature in widget.hero.features
                                          .where((f) => !_preview!
                                              .result.features
                                              .any((old) => old.id == f.id)))
                                        ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            leading: Icon(
                                                Icons
                                                    .remove_circle_outline_rounded,
                                                color: c.onSurfaceVariant),
                                            title: Text(feature
                                                .getName(ru ? 'ru' : 'en'))),
                                    ]),
                                Text(
                                    ru
                                        ? 'Приобретённые в этих повышениях умения и выборы будут отменены. Потраченные ресурсы не восстановятся.'
                                        : 'Features and choices gained in these level-ups are reverted. Spent resources are not restored.',
                                    style: theme.textTheme.bodyMedium),
                              ])),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await AdvancementHistory.apply(
                                        widget.hero, _preview!);
                                    if (context.mounted) {
                                      HapticFeedback.mediumImpact();
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    setState(() {
                                      _busy = false;
                                      _preview = null;
                                      _issue = ru
                                          ? 'Лист изменился или запись не завершилась. Выбери повышение заново; изменения не применены.'
                                          : 'The sheet changed or saving failed. Select the level-up again; no changes were applied.';
                                    });
                                  }
                                },
                          icon: const Icon(Icons.history_rounded),
                          label: Text(
                              ru ? 'Подтвердить откат' : 'Confirm rollback')),
                    ],
                  ],
                  const SizedBox(height: 12),
                ])));
  }
}

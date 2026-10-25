import 'package:flutter/material.dart';
import '../../core/magic/spell_preparation_rules.dart';
import '../../core/models/character.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/services/spell_preparation_rules_service.dart';
import '../../core/ui/sheet_drag_region.dart';
import 'spell_preparation_rules_editor.dart';

Future<bool?> showSpellPreparationRulesSheet(
        BuildContext context, Character hero, String classId) =>
    showResponsiveSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _RulesSheet(hero: hero, classId: classId));

class _RulesSheet extends StatefulWidget {
  const _RulesSheet({required this.hero, required this.classId});
  final Character hero;
  final String classId;
  @override
  State<_RulesSheet> createState() => _RulesSheetState();
}

class _RulesSheetState extends State<_RulesSheet> {
  late final CharacterClassRules _owned;
  late final int _level;
  late final String? _subclass;
  SpellPreparationRules? _rules;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final entry =
        widget.hero.classes.singleWhere((c) => c.id == widget.classId);
    _owned = CharacterClassRules.resolve(entry);
    _level = entry.level;
    _subclass = entry.subclass;
    _rules = SpellPreparationRules.resolve(_owned.data);
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final theme = Theme.of(context);
    final raw = _owned.data.rulesMetadata['spellPreparation'];
    final unsupported =
        _owned.data.rulesMetadata.containsKey('spellPreparation') &&
            SpellPreparationRules.fromJson(raw) == null;
    return PopScope(
        canPop: !_busy,
        child: SheetScrollDismiss(
            enabled: !_busy,
            child: KeyboardPadding(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    20, 12, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(ru ? 'Правила магии' : 'Magic rules',
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(_owned.data.getName(ru ? 'ru' : 'en'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 10),
                      Text(
                          ru
                              ? 'Для этого героя. Сверь подготовку и ритуалы со своей книгой; запасы и выбранные заклинания сохранятся.'
                              : 'For this hero. Match preparation and rituals to your book; resources and chosen spells are preserved.',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 20),
                      if (unsupported)
                        Text(ru
                            ? 'В книге указан неподдерживаемый вариант правил подготовки. Он сохранён без изменений.'
                            : 'This book declares unsupported preparation rules. They are preserved unchanged.')
                      else
                        SpellPreparationRulesEditor(
                            initial: _rules,
                            enabled: !_busy,
                            onChanged: (v) => setState(() => _rules = v)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: _busy || _rules == null || unsupported
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  try {
                                    await SpellPreparationRulesService.save(
                                        widget.hero, widget.classId, _rules!,
                                        expectedDigest:
                                            _owned.snapshot['digest'] as String,
                                        expectedLevel: _level,
                                        expectedSubclass: _subclass);
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    setState(() => _busy = false);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                        content: Text(ru
                                            ? 'Не удалось сохранить. Открой правила заново и повтори.'
                                            : 'Could not save. Reopen the rules and try again.')));
                                  }
                                },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(ru
                              ? 'Сохранить для героя'
                              : 'Save for this hero')),
                    ])))));
  }
}

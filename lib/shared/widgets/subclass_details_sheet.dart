import 'package:flutter/material.dart';
import '../../core/models/character.dart';
import '../../core/progression/character_class_context.dart';
import '../../core/services/class_reference_actions_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/ui/sheet_drag_region.dart';

Future<void> showClassSubclassDetails(
        BuildContext context, Character character, String classId) =>
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) =>
            SubclassDetailsSheet(character: character, classId: classId));

class SubclassDetailsSheet extends StatefulWidget {
  const SubclassDetailsSheet(
      {super.key, required this.character, required this.classId});
  final Character character;
  final String classId;
  @override
  State<SubclassDetailsSheet> createState() => _SubclassDetailsSheetState();
}

class _SubclassDetailsSheetState extends State<SubclassDetailsSheet> {
  bool _busy = false;
  Future<void> _choose(String signature) async {
    setState(() => _busy = true);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    try {
      await ClassReferenceActionsService.select(
          widget.character, widget.classId, signature);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ru
                ? 'Не удалось выбрать книгу. Попробуйте ещё раз.'
                : 'Could not select the book. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _book(String? id, bool ru) {
    if (id == null) return ru ? 'Основные правила' : 'Core rules';
    try {
      return StorageService.getAllSources()
              .where((s) => s.id == id)
              .firstOrNull
              ?.name ??
          (ru ? 'Загруженная книга' : 'Imported book');
    } catch (_) {
      return ru ? 'Загруженная книга' : 'Imported book';
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = CharacterClassContext(widget.character, widget.classId);
    final reference = owner.subclassReference;
    final locale = Localizations.localeOf(context).languageCode;
    final ru = locale == 'ru';
    final theme = Theme.of(context), colors = theme.colorScheme;
    final text = reference?.description(locale) ?? '';
    final missing = reference?.selectionMissing == true;
    final ambiguous = reference?.requiresChoice == true;
    final candidates = reference?.candidates ?? [];
    final features = reference?.features ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(owner.name(locale),
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary)),
        const SizedBox(height: 6),
        Text(owner.subclassName(locale) ?? '',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.7)),
        const SizedBox(height: 20),
        if (text.isNotEmpty)
          SelectableText(text,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6))
        else if (features.isEmpty)
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24)),
              child: Text(
                  missing
                      ? ru
                          ? 'Выбранная книга недоступна или её текст изменился. Загрузите её снова или выберите другой источник ниже.'
                          : 'The chosen book is unavailable or its text has changed. Import it again or choose another source below.'
                      : ambiguous
                          ? ru
                              ? 'Выберите доступную книгу для описания этого персонажа.'
                              : 'Choose an available book for this character’s description.'
                          : ru
                              ? 'В доступных книгах пока нет описания этого подкласса. Его название и сведения персонажа сохранены.'
                              : 'The available books do not include this subclass description yet. Its name and your character data are preserved.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5))),
        if (features.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(ru ? 'Умения подкласса' : 'Subclass features',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    backgroundColor: colors.surfaceContainerLow,
                    collapsedBackgroundColor: colors.surfaceContainerLow,
                    title: Text(feature.getName(locale),
                        style: theme.textTheme.titleMedium),
                    subtitle: Text(ru
                        ? '${feature.minLevel}-й уровень класса'
                        : 'Class level ${feature.minLevel}'),
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                          child: SelectableText(feature.getDescription(locale),
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(height: 1.6)))
                    ])),
        ],
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: 24),
          ExpansionTile(
              key: ValueKey('reference-${missing || ambiguous}'),
              initiallyExpanded: missing || ambiguous,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              backgroundColor: colors.surfaceContainerLow,
              collapsedBackgroundColor: colors.surfaceContainerLow,
              leading: const Icon(Icons.auto_stories_rounded),
              title: Text(ru ? 'Источник описания' : 'Description source'),
              children: [
                for (final candidate in candidates)
                  ListTile(
                      enabled: !_busy,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 4),
                      title: Text(_book(candidate.owner.sourceId, ru)),
                      subtitle: Text(candidate.subclass.getName(locale)),
                      trailing: candidate.signature ==
                              owner.entry?.referenceData['signature']
                          ? Icon(Icons.check_circle_rounded,
                              color: colors.primary)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => _choose(candidate.signature)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    child: Text(
                        ru
                            ? 'Выбор меняет только справочное описание. Правила и значения героя остаются прежними.'
                            : 'This choice changes reference text only. Your character’s rules and values stay as they are.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant))),
              ]),
        ],
      ]),
    );
  }
}

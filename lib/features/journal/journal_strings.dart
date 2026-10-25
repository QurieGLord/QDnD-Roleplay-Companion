import 'package:flutter/material.dart';
import '../../core/journal/journal_graph.dart';

class JournalStrings {
  JournalStrings(BuildContext context)
      : ru = Localizations.localeOf(context).languageCode == 'ru';
  final bool ru;
  String t(String russian, String english) => ru ? russian : english;
  String kind(JournalEntityKind kind) => switch (kind) {
        JournalEntityKind.person => t('Персонаж', 'Person'),
        JournalEntityKind.place => t('Место', 'Place'),
        JournalEntityKind.item => t('Предмет', 'Item'),
        JournalEntityKind.event => t('Событие', 'Event'),
        JournalEntityKind.story => t('История', 'Story'),
      };
  IconData icon(JournalEntityKind kind) => switch (kind) {
        JournalEntityKind.person => Icons.person_outline,
        JournalEntityKind.place => Icons.place_outlined,
        JournalEntityKind.item => Icons.auto_awesome_outlined,
        JournalEntityKind.event => Icons.history,
        JournalEntityKind.story => Icons.auto_stories_outlined,
      };
  /// «3 записи», «1 entry»: Russian takes one, few, many; English one, many.
  String plural(int n, List<String> ru, List<String> en) {
    if (!this.ru) return '$n ${n == 1 ? en[0] : en[1]}';
    final last = n % 10, teen = n % 100;
    final form = teen >= 11 && teen <= 14
        ? 2
        : last == 1
            ? 0
            : last >= 2 && last <= 4
                ? 1
                : 2;
    return '$n ${ru[form]}';
  }

  String records(int n) =>
      plural(n, const ['запись', 'записи', 'записей'], const ['entry', 'entries']);

  String count(int n) {
    if (!ru) return '$n ${n == 1 ? 'entry' : 'entries'}';
    final last = n % 10, teen = n % 100;
    final noun = teen >= 11 && teen <= 14
        ? 'материалов'
        : last == 1
            ? 'материал'
            : last >= 2 && last <= 4
                ? 'материала'
                : 'материалов';
    return '$n $noun';
  }
}

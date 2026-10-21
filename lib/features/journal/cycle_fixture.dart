import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/character.dart';
import '../../core/models/journal_note.dart';
import '../../core/models/quest.dart';
import '../../core/services/storage_service.dart';

/// Explicit opt-in for the separate Cycle package only; never replaces a hero.
Future<void> seedJournalCycle() async {
  const id = 'cycle-journal-working-20261008';
  if (StorageService.getCharacter(id) != null) return;
  final c = Character(
      id: id,
      name: 'Cycle · Журнал',
      race: 'human',
      characterClass: 'fighter',
      level: 3,
      maxHp: 24,
      currentHp: 24,
      spellSlots: [],
      maxSpellSlots: [],
      abilityScores: AbilityScores(
          strength: 14,
          dexterity: 14,
          constitution: 14,
          intelligence: 12,
          wisdom: 12,
          charisma: 12));
  c.journalNotes.addAll([
    JournalNote(
        id: 'cycle-letter',
        title: 'Письмо из Лесной гавани',
        category: NoteCategory.story,
        tags: ['улика', 'письмо'],
        isPinned: true,
        content:
            'В письме есть имя Элиан и упоминание старой пристани. Пока не установлено, тот ли это человек.',
        createdAt: DateTime(2026, 10, 1)),
    JournalNote(
        id: 'cycle-last',
        title: 'Последние слова',
        category: NoteCategory.npc,
        tags: ['Альдрен'],
        content:
            'Альдрен попросил найти сына Элиана. Он ушёл из семьи ради её защиты. Элиан из старого письма — его сын?',
        createdAt: DateTime(2026, 10, 8)),
    JournalNote(
        id: 'cycle-blade',
        title: 'Клинок из сокровищницы',
        category: NoteCategory.artifact,
        tags: ['снаряжение'],
        content:
            'После победы на Северной дороге найден клинок. С мастером договорились о трёх зарядах; свойства запишем в Кузницу.'),
  ]);
  c.quests.addAll([
    Quest(
        id: 'cycle-find',
        title: 'Найти Элиана',
        description:
            'Передать последние слова Альдрена. Первая зацепка ведёт в Лесную гавань.',
        objectives: [
          QuestObjective(
              description: 'Перечитать старое письмо', isCompleted: true),
          QuestObjective(description: 'Расспросить смотрителя пристани'),
          QuestObjective(description: 'Передать Элиану слова отца')
        ]),
    Quest(
        id: 'cycle-road',
        title: 'Угроза на северной дороге',
        description: 'Дорога снова безопасна.',
        status: QuestStatus.completed,
        objectives: [
          QuestObjective(
              description: 'Проверить Северную дорогу', isCompleted: true)
        ]),
  ]);
  final g = JournalGraph(entities: [
    JournalEntity(
        id: 'cycle-elian',
        name: 'Элиан',
        aliases: ['Elian'],
        description:
            'Сын Альдрена. Личность человека из письма ещё предстоит проверить.'),
    JournalEntity(
        id: 'cycle-aldren',
        name: 'Альдрен',
        aliases: ['Aldren'],
        description: 'Передал последние слова сыну.'),
    JournalEntity(
        id: 'cycle-haven',
        name: 'Лесная гавань',
        aliases: ['Woodland Haven'],
        kind: JournalEntityKind.place,
        description: 'В письме упоминается старая пристань.'),
    JournalEntity(
        id: 'cycle-north',
        name: 'Северная дорога',
        aliases: ['Northern road'],
        kind: JournalEntityKind.place),
  ]);
  g.forRecord('n:cycle-letter').session = 2;
  g.forRecord('n:cycle-last').session = 6;
  g.forRecord('n:cycle-last').records.add('n:cycle-letter');
  g.forRecord('q:cycle-find').records.add('n:cycle-last');
  JournalService.reconcile(c, g);
  c.journalData = g.toJson();
  await StorageService.saveCharacter(c);
  if (StorageService.getSetting('locale_code') == null) {
    await StorageService.saveSetting('locale_code', 'ru');
  }
}

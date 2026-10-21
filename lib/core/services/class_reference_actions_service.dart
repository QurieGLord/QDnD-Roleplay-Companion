import '../models/character.dart';
import '../progression/character_class_context.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

class ClassReferenceActionsService {
  /// Only the explicit reference choice is saved. No text, rule snapshot,
  /// class level or resource is rewritten when a library is added or removed.
  static Future<void> select(
          Character character, String classId, String signature,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(character, () async {
        final context = CharacterClassContext(character, classId);
        final entry = context.entry;
        final subclass = context.subclass;
        final candidate = context.subclassReference?.candidates
            .where((c) => c.signature == signature)
            .firstOrNull;
        if (entry == null || subclass == null || candidate == null) {
          throw StateError('The reference source is no longer available.');
        }
        if (entry.referenceData.isNotEmpty &&
            entry.referenceData['version'] != 1) {
          throw const FormatException('Unsupported reference choice.');
        }
        final before = entry.referenceData;
        final timestamp = character.updatedAt;
        try {
          entry.referenceData = {...before, ...candidate.selection(subclass)};
          await (write ?? StorageService.saveCharacter)(character);
        } catch (_) {
          entry.referenceData = before;
          character.updatedAt = timestamp;
          rethrow;
        }
      });
}

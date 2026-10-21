import 'package:hive/hive.dart';

/// Durable undo log for a multi-box source install. No character box is exposed.
/// Source records publish last; an interrupted applying/rollback phase recovers
/// before catalogs are loaded. Cleanup failure after commit does not undo data.
class CatalogInstallJournal {
  CatalogInstallJournal(this.settings, this.boxes, {this.writeBatch});
  static const key = 'catalog_install_pending_v1';
  final Box settings;
  final Map<String, Box> boxes;
  final Future<void> Function(String, Map<String, dynamic>)? writeBatch;

  Future<void> install(
      String sourceId, Map<String, Map<String, dynamic>> writes,
      {Future<void> Function(String)? afterWrite}) async {
    await recover();
    if (writes.keys.any((name) => !boxes.containsKey(name))) {
      throw ArgumentError('Unknown catalog box.');
    }
    final backup = <Map<String, dynamic>>[];
    for (final box in writes.entries) {
      for (final entry in box.value.entries) {
        backup.add({
          'box': box.key,
          'key': entry.key,
          'exists': boxes[box.key]!.containsKey(entry.key),
          'value': boxes[box.key]!.get(entry.key)
        });
      }
    }
    var record = <String, dynamic>{
      'version': 1,
      'sourceId': sourceId,
      'state': 'applying',
      'backup': backup
    };
    await settings.put(key, record);
    await settings.flush();
    var committed = false;
    try {
      for (final entry in writes.entries) {
        if (writeBatch != null) {
          await writeBatch!(entry.key, entry.value);
        } else {
          for (final value in entry.value.entries) {
            await boxes[entry.key]!.put(value.key, value.value);
          }
        }
        await boxes[entry.key]!.flush();
        await afterWrite?.call(entry.key);
      }
      record = {...record, 'state': 'committed'};
      await settings.put(key, record);
      await settings.flush();
      committed = true;
    } catch (_) {
      if (!committed) {
        // Do not start undo until its durable state is recorded. If even this
        // write fails, the retained log is recovered on the next startup.
        record = {...record, 'state': 'rollingBack'};
        await settings.put(key, record);
        await settings.flush();
        await _undo(record);
      }
      rethrow;
    }
    try {
      await settings.delete(key);
      await settings.flush();
    } catch (_) {
      /* A committed log is only pending cleanup, never pending undo. */
    }
  }

  Future<void> recover() async {
    final value = settings.get(key);
    if (value == null) return;
    if (value is! Map ||
        value['version'] != 1 ||
        value['backup'] is! List ||
        value['sourceId'] is! String ||
        !{'applying', 'rollingBack', 'committed'}.contains(value['state'])) {
      throw StateError('Unsupported catalog recovery record.');
    }
    final record = Map<String, dynamic>.from(value);
    if (record['state'] == 'committed') {
      await settings.delete(key);
      await settings.flush();
      return;
    }
    await settings.put(key, {...record, 'state': 'rollingBack'});
    await settings.flush();
    await _undo(record);
  }

  Future<void> _undo(Map<String, dynamic> record) async {
    final entries = record['backup'] as List;
    // Validate the whole log before restoring any entry.
    for (final value in entries) {
      if (value is! Map ||
          !boxes.containsKey(value['box']) ||
          value['key'] is! String ||
          value['exists'] is! bool) {
        throw StateError('Invalid catalog recovery entry.');
      }
    }
    for (final value in entries.reversed) {
      final box = boxes[value['box']]!;
      if (value['exists'] == true) {
        await box.put(value['key'], value['value']);
      } else {
        await box.delete(value['key']);
      }
      await box.flush();
    }
    await settings.delete(key);
    await settings.flush();
  }
}

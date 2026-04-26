import 'package:uuid/uuid.dart';

class BundleIdMapper {
  final Uuid _uuid;
  final Map<String, String> _characterIds = {};
  final Map<String, Map<String, String>> _contentIds = {};

  BundleIdMapper({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  String mapCharacterId(String oldId) {
    return _characterIds.putIfAbsent(oldId, () => _uuid.v4());
  }

  String createContentId(String contentType, String oldId) {
    final typeMap = _contentIds.putIfAbsent(contentType, () => {});
    return typeMap.putIfAbsent(
      oldId,
      () => 'qdnd_${contentType}_${_uuid.v4()}',
    );
  }

  void registerContentId(String contentType, String oldId, String newId) {
    _contentIds.putIfAbsent(contentType, () => {})[oldId] = newId;
  }

  String mapContentId(String contentType, String oldId) {
    return _contentIds[contentType]?[oldId] ?? oldId;
  }

  bool hasContentId(String contentType, String oldId) {
    return _contentIds[contentType]?.containsKey(oldId) ?? false;
  }
}

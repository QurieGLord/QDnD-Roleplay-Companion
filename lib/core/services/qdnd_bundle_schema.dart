import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/character.dart';

const int qdndBundleSchemaVersion = 1;
const String qdndBundleFormat = 'qdnd.bundle';

enum QdndBundleExportPolicy {
  embedded,
  referenceOnly,
  snapshotOnly,
  userCreated,
}

enum QdndBundleDiagnosticSeverity {
  info,
  warning,
  error,
}

enum QdndBundleConflictPolicy {
  duplicate,
}

class QdndBundleException implements Exception {
  final String code;
  final String message;

  const QdndBundleException(this.code, this.message);

  @override
  String toString() => message;
}

class QdndBundleDiagnostic {
  final QdndBundleDiagnosticSeverity severity;
  final String code;
  final String message;
  final String? context;

  const QdndBundleDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.context,
  });

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'code': code,
        'message': message,
        'context': context,
      };
}

class QdndBundleDiagnostics {
  final List<QdndBundleDiagnostic> entries = [];

  bool get isEmpty => entries.isEmpty;
  bool get hasWarnings => entries.any(
        (entry) => entry.severity == QdndBundleDiagnosticSeverity.warning,
      );

  int get warningCount => entries
      .where(
        (entry) => entry.severity == QdndBundleDiagnosticSeverity.warning,
      )
      .length;

  void info(String code, String message, {String? context}) {
    entries.add(
      QdndBundleDiagnostic(
        severity: QdndBundleDiagnosticSeverity.info,
        code: code,
        message: message,
        context: context,
      ),
    );
  }

  void warning(String code, String message, {String? context}) {
    entries.add(
      QdndBundleDiagnostic(
        severity: QdndBundleDiagnosticSeverity.warning,
        code: code,
        message: message,
        context: context,
      ),
    );
  }

  void error(String code, String message, {String? context}) {
    entries.add(
      QdndBundleDiagnostic(
        severity: QdndBundleDiagnosticSeverity.error,
        code: code,
        message: message,
        context: context,
      ),
    );
  }
}

class QdndBundleExportOptions {
  final bool includeUserCreatedContent;

  const QdndBundleExportOptions({
    this.includeUserCreatedContent = false,
  });
}

class QdndBundleImportOptions {
  final QdndBundleConflictPolicy conflictPolicy;

  const QdndBundleImportOptions({
    this.conflictPolicy = QdndBundleConflictPolicy.duplicate,
  });
}

class QdndBundleExportResult {
  final Uint8List bytes;
  final Map<String, dynamic> manifest;
  final int embeddedContentCount;
  final int dependencyCount;
  final List<QdndBundleDiagnostic> diagnostics;

  const QdndBundleExportResult({
    required this.bytes,
    required this.manifest,
    required this.embeddedContentCount,
    required this.dependencyCount,
    this.diagnostics = const [],
  });
}

class QdndBundleMediaEntry {
  final String kind;
  final String ownerId;
  final String fieldName;
  final String originalName;
  final String? bundlePath;
  final String? fileName;
  final int? sizeBytes;
  final String? contentHash;
  final bool embedded;
  final QdndBundleExportPolicy exportPolicy;

  const QdndBundleMediaEntry({
    required this.kind,
    required this.ownerId,
    required this.fieldName,
    required this.originalName,
    this.bundlePath,
    this.fileName,
    this.sizeBytes,
    this.contentHash,
    this.embedded = true,
    this.exportPolicy = QdndBundleExportPolicy.userCreated,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'ownerId': ownerId,
        'fieldName': fieldName,
        'originalName': originalName,
        'bundlePath': bundlePath,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'contentHash': contentHash,
        'embedded': embedded,
        'exportPolicy': exportPolicy.name,
      };

  factory QdndBundleMediaEntry.fromJson(Map<String, dynamic> json) {
    return QdndBundleMediaEntry(
      kind: json['kind'] as String? ?? 'unknown',
      ownerId: json['ownerId'] as String? ?? '',
      fieldName: json['fieldName'] as String? ?? '',
      originalName: json['originalName'] as String? ?? '',
      bundlePath: json['bundlePath'] as String?,
      fileName: json['fileName'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
      contentHash: json['contentHash'] as String?,
      embedded: json['embedded'] as bool? ?? false,
      exportPolicy: QdndBundleExportPolicy.values.firstWhere(
        (policy) => policy.name == json['exportPolicy'],
        orElse: () => QdndBundleExportPolicy.referenceOnly,
      ),
    );
  }
}

class QdndBundleImportPreview {
  final String characterName;
  final int level;
  final List<String> classes;
  final int embeddedContentCount;
  final int dependencyCount;
  final int resolvedDependencyCount;
  final int missingDependencyCount;
  final List<BundleDependencyReference> dependencies;

  const QdndBundleImportPreview({
    required this.characterName,
    required this.level,
    required this.classes,
    required this.embeddedContentCount,
    required this.dependencyCount,
    this.resolvedDependencyCount = 0,
    this.missingDependencyCount = 0,
    required this.dependencies,
  });

  QdndBundleImportPreview copyWith({
    int? resolvedDependencyCount,
    int? missingDependencyCount,
  }) {
    return QdndBundleImportPreview(
      characterName: characterName,
      level: level,
      classes: classes,
      embeddedContentCount: embeddedContentCount,
      dependencyCount: dependencyCount,
      resolvedDependencyCount:
          resolvedDependencyCount ?? this.resolvedDependencyCount,
      missingDependencyCount:
          missingDependencyCount ?? this.missingDependencyCount,
      dependencies: dependencies,
    );
  }
}

class QdndBundleImportResult {
  final Character character;
  final QdndBundleImportPreview preview;
  final List<QdndBundleDiagnostic> diagnostics;
  final int embeddedContentCount;
  final int resolvedDependencyCount;
  final int missingDependencyCount;

  const QdndBundleImportResult({
    required this.character,
    required this.preview,
    required this.diagnostics,
    required this.embeddedContentCount,
    required this.resolvedDependencyCount,
    required this.missingDependencyCount,
  });

  bool get hasWarnings => diagnostics.any(
        (entry) => entry.severity == QdndBundleDiagnosticSeverity.warning,
      );
}

class BundleDependencyReference {
  final String contentType;
  final String localId;
  final String? canonicalName;
  final String? sourceId;
  final String? sourceName;
  final String sourceKind;
  final String? contentHash;
  final String? ruleset;
  final List<String> requiredFor;
  final String fallbackBehavior;
  final QdndBundleExportPolicy exportPolicy;

  const BundleDependencyReference({
    required this.contentType,
    required this.localId,
    this.canonicalName,
    this.sourceId,
    this.sourceName,
    this.sourceKind = 'external',
    this.contentHash,
    this.ruleset,
    this.requiredFor = const [],
    this.fallbackBehavior = 'snapshot',
    this.exportPolicy = QdndBundleExportPolicy.referenceOnly,
  });

  String get key => '$contentType:$localId';

  Map<String, dynamic> toJson() => {
        'contentType': contentType,
        'localId': localId,
        'canonicalName': canonicalName,
        'sourceId': sourceId,
        'sourceName': sourceName,
        'sourceKind': sourceKind,
        'contentHash': contentHash,
        'ruleset': ruleset,
        'requiredFor': requiredFor,
        'fallbackBehavior': fallbackBehavior,
        'exportPolicy': exportPolicy.name,
      };

  factory BundleDependencyReference.fromJson(Map<String, dynamic> json) {
    return BundleDependencyReference(
      contentType: json['contentType'] as String? ?? 'unknown',
      localId: json['localId'] as String? ?? '',
      canonicalName: json['canonicalName'] as String?,
      sourceId: json['sourceId'] as String?,
      sourceName: json['sourceName'] as String?,
      sourceKind: json['sourceKind'] as String? ?? 'external',
      contentHash: json['contentHash'] as String?,
      ruleset: json['ruleset'] as String?,
      requiredFor: List<String>.from(json['requiredFor'] as List? ?? const []),
      fallbackBehavior: json['fallbackBehavior'] as String? ?? 'snapshot',
      exportPolicy: QdndBundleExportPolicy.values.firstWhere(
        (policy) => policy.name == json['exportPolicy'],
        orElse: () => QdndBundleExportPolicy.referenceOnly,
      ),
    );
  }
}

class QdndBundleHashes {
  static String bytesHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  static String entityHash(Object? value) {
    return bytesHash(utf8.encode(_canonicalJson(value)));
  }

  static String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) {
        return '${jsonEncode(key)}:${_canonicalJson(value[key])}';
      }).join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_canonicalJson).join(',')}]';
    }
    return jsonEncode(value);
  }
}

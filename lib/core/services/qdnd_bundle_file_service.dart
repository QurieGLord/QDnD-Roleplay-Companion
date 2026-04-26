import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'qdnd_bundle_import_service.dart';
import 'qdnd_bundle_schema.dart';

class QdndBundleFileService {
  static bool isSupportedBundleName(String nameOrPath) {
    final normalized = nameOrPath.trim().toLowerCase();
    return normalized.endsWith('.qdnd') || normalized.endsWith('.zip');
  }

  static Future<Uint8List> readPlatformFile(PlatformFile file) async {
    final nameOrPath = _nameOrPath(file);
    if (!isSupportedBundleName(nameOrPath)) {
      throw const QdndBundleException(
        'unsupported_file_type',
        'Choose a .qdnd or .zip QDND bundle file.',
      );
    }

    if (file.bytes != null) {
      return Uint8List.fromList(file.bytes!);
    }

    final stream = file.readStream;
    if (stream != null) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    }

    final path = _safePath(file);
    if (path != null && path.isNotEmpty) {
      return File(path).readAsBytes();
    }

    throw const QdndBundleException(
      'file_unavailable',
      'The selected file could not be read. Try choosing it again.',
    );
  }

  static Future<QdndBundleImportPreview> previewPlatformFile(
    PlatformFile file,
  ) async {
    return QdndBundleImportService.previewBytes(
      await readPlatformFile(file),
    );
  }

  static Future<QdndBundleImportResult> importPlatformFile(
    PlatformFile file, {
    QdndBundleImportOptions options = const QdndBundleImportOptions(),
  }) async {
    return QdndBundleImportService.importBytes(
      await readPlatformFile(file),
      options: options,
    );
  }

  static String _nameOrPath(PlatformFile file) {
    final path = _safePath(file);
    if (isSupportedBundleName(file.name)) return file.name;
    if (path != null && isSupportedBundleName(path)) return path;
    if (file.name.trim().isNotEmpty) return file.name;
    return path ?? '';
  }

  static String? _safePath(PlatformFile file) {
    try {
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

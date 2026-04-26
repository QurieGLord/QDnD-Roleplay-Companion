import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/character.dart';
import 'fc5_parser.dart';

class FC5MediaImportService {
  static const int _maxMediaFiles = 24;
  static const int _maxMediaFileBytes = 8 * 1024 * 1024;
  static const int _maxMediaTotalBytes = 18 * 1024 * 1024;

  static Future<void> materializeCharacterMedia({
    required Character character,
    required List<FC5EmbeddedMedia> media,
    required FC5ParseDiagnostics diagnostics,
  }) async {
    if (media.isEmpty) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final importDir = Directory(
      '${documentsDir.path}${Platform.pathSeparator}fc5_media'
      '${Platform.pathSeparator}${character.id}',
    );
    await importDir.create(recursive: true);

    var embeddedCount = 0;
    var totalBytes = 0;
    var avatarImported = false;
    final importedNoteIndexes = <int>{};
    final importedItemIndexes = <int>{};

    for (final entry in media) {
      if (embeddedCount >= _maxMediaFiles) {
        diagnostics.warning(
          'image_data_file_limit',
          'Embedded FC5 imageData was skipped because the media file limit was reached.',
          context: entry.context,
        );
        continue;
      }

      if (entry.kind == 'avatar' && avatarImported) {
        diagnostics.warning(
          'image_data_duplicate_avatar',
          'Additional FC5 avatar imageData was skipped.',
          context: entry.context,
        );
        continue;
      }

      if (entry.kind == 'note') {
        final noteIndex = entry.noteIndex;
        if (noteIndex == null ||
            noteIndex < 0 ||
            noteIndex >= character.journalNotes.length) {
          diagnostics.warning(
            'image_data_note_missing',
            'Embedded FC5 note imageData was skipped because its note was not found.',
            context: entry.context,
          );
          continue;
        }
        if (importedNoteIndexes.contains(noteIndex)) {
          diagnostics.warning(
            'image_data_duplicate_note',
            'Additional FC5 note imageData was skipped.',
            context: entry.context,
          );
          continue;
        }
      } else if (entry.kind == 'item') {
        final itemIndex = entry.itemIndex;
        if (itemIndex == null ||
            itemIndex < 0 ||
            itemIndex >= character.inventory.length) {
          diagnostics.warning(
            'image_data_item_missing',
            'Embedded FC5 item imageData was skipped because its item was not found.',
            context: entry.context,
          );
          continue;
        }
        if (importedItemIndexes.contains(itemIndex)) {
          diagnostics.warning(
            'image_data_duplicate_item',
            'Additional FC5 item imageData was skipped.',
            context: entry.context,
          );
          continue;
        }
      } else if (entry.kind != 'avatar') {
        diagnostics.warning(
          'image_data_unsupported',
          'Embedded FC5 imageData was skipped because its target is unsupported.',
          context: entry.context,
        );
        continue;
      }

      final decoded = _decodeImageData(entry, diagnostics);
      if (decoded == null) continue;

      if (!_isSupportedRasterImage(decoded.bytes, decoded.mimeType)) {
        diagnostics.warning(
          'image_data_unsupported_format',
          'Embedded FC5 imageData was skipped because it is not a supported raster image.',
          context: entry.context,
        );
        continue;
      }

      if (decoded.bytes.length > _maxMediaFileBytes) {
        diagnostics.warning(
          'image_data_too_large',
          'Embedded FC5 imageData was skipped because it is too large.',
          context: entry.context,
        );
        continue;
      }

      if (totalBytes + decoded.bytes.length > _maxMediaTotalBytes) {
        diagnostics.warning(
          'image_data_total_limit',
          'Embedded FC5 imageData was skipped because the total media limit was reached.',
          context: entry.context,
        );
        continue;
      }

      final fileName = _mediaFileName(entry, decoded, embeddedCount + 1);
      final outputFile =
          File('${importDir.path}${Platform.pathSeparator}$fileName');

      try {
        await outputFile.writeAsBytes(decoded.bytes, flush: true);
      } catch (error) {
        diagnostics.warning(
          'image_data_write_failed',
          'Failed to save embedded FC5 imageData: $error',
          context: entry.context,
        );
        continue;
      }

      embeddedCount++;
      totalBytes += decoded.bytes.length;

      if (entry.kind == 'avatar') {
        character.avatarPath = outputFile.path;
        avatarImported = true;
        continue;
      }

      if (entry.kind == 'note') {
        final noteIndex = entry.noteIndex!;
        character.journalNotes[noteIndex].imagePath = outputFile.path;
        importedNoteIndexes.add(noteIndex);
        continue;
      }

      final itemIndex = entry.itemIndex!;
      character.inventory[itemIndex].customImagePath = outputFile.path;
      importedItemIndexes.add(itemIndex);
    }
  }

  static _DecodedImageData? _decodeImageData(
    FC5EmbeddedMedia entry,
    FC5ParseDiagnostics diagnostics,
  ) {
    final raw = entry.rawData.trim();
    if (raw.isEmpty) {
      final referenceId = entry.referenceId;
      if (referenceId == null) {
        diagnostics.warning(
          'image_data_empty',
          'Embedded FC5 imageData was empty.',
          context: entry.context,
        );
      } else {
        diagnostics.warning(
          'image_data_reference_missing',
          'FC5 imageData reference "$referenceId" did not include embedded image bytes.',
          context: entry.context,
        );
      }
      return null;
    }

    if (raw.toLowerCase().startsWith('data:')) {
      return _decodeDataUri(raw, entry, diagnostics);
    }

    final encoding = entry.encoding?.trim().toLowerCase();
    if (encoding == null || encoding.isEmpty || encoding == 'base64') {
      return _decodeBase64(raw, entry, diagnostics);
    }

    diagnostics.warning(
      'image_data_unsupported_encoding',
      'Embedded FC5 imageData used unsupported encoding "$encoding".',
      context: entry.context,
    );
    return null;
  }

  static _DecodedImageData? _decodeDataUri(
    String raw,
    FC5EmbeddedMedia entry,
    FC5ParseDiagnostics diagnostics,
  ) {
    final commaIndex = raw.indexOf(',');
    if (commaIndex <= 5) {
      diagnostics.warning(
        'image_data_invalid',
        'Embedded FC5 data URI imageData was invalid.',
        context: entry.context,
      );
      return null;
    }

    final metadata = raw.substring(5, commaIndex);
    final payload = raw.substring(commaIndex + 1);
    final metadataParts = metadata.split(';');
    final mimeType = metadataParts.first.trim().isEmpty
        ? entry.mimeType
        : metadataParts.first.trim();
    final isBase64 = metadataParts
        .skip(1)
        .any((part) => part.trim().toLowerCase() == 'base64');

    if (isBase64) {
      return _decodeBase64(payload, entry, diagnostics, mimeType: mimeType);
    }

    try {
      return _DecodedImageData(
        Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload))),
        mimeType: mimeType,
      );
    } catch (_) {
      diagnostics.warning(
        'image_data_invalid',
        'Embedded FC5 data URI imageData was invalid.',
        context: entry.context,
      );
      return null;
    }
  }

  static _DecodedImageData? _decodeBase64(
    String raw,
    FC5EmbeddedMedia entry,
    FC5ParseDiagnostics diagnostics, {
    String? mimeType,
  }) {
    try {
      final normalized = raw.replaceAll(RegExp(r'\s+'), '');
      final bytes = Uint8List.fromList(base64.decode(normalized));
      if (bytes.isEmpty) {
        diagnostics.warning(
          'image_data_empty',
          'Embedded FC5 imageData was empty.',
          context: entry.context,
        );
        return null;
      }
      return _DecodedImageData(bytes, mimeType: mimeType ?? entry.mimeType);
    } catch (_) {
      diagnostics.warning(
        'image_data_invalid',
        'Embedded FC5 base64 imageData was invalid.',
        context: entry.context,
      );
      return null;
    }
  }

  static String _mediaFileName(
    FC5EmbeddedMedia entry,
    _DecodedImageData decoded,
    int index,
  ) {
    final kind = switch (entry.kind) {
      'note' => 'note',
      'item' => 'item',
      _ => 'avatar',
    };
    final extension = _extensionFor(entry, decoded);
    return '${index}_$kind.$extension';
  }

  static String _extensionFor(FC5EmbeddedMedia entry, _DecodedImageData data) {
    final explicit = entry.format?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) {
      final sanitized = explicit.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sanitized.isNotEmpty) return sanitized;
    }

    final mime = (data.mimeType ?? entry.mimeType)?.trim().toLowerCase();
    switch (mime) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
    }

    final bytes = data.bytes;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    return 'bin';
  }

  static bool _isSupportedRasterImage(Uint8List bytes, String? mimeType) {
    final mime = mimeType?.trim().toLowerCase();
    if (mime != null &&
        mime.isNotEmpty &&
        mime != 'image/png' &&
        mime != 'image/jpeg' &&
        mime != 'image/jpg' &&
        mime != 'image/gif' &&
        mime != 'image/webp') {
      return false;
    }

    return _hasPngSignature(bytes) ||
        _hasJpegSignature(bytes) ||
        _hasGifSignature(bytes) ||
        _hasWebpSignature(bytes);
  }

  static bool _hasPngSignature(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
  }

  static bool _hasJpegSignature(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }

  static bool _hasGifSignature(Uint8List bytes) {
    return bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61;
  }

  static bool _hasWebpSignature(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}

class _DecodedImageData {
  final Uint8List bytes;
  final String? mimeType;

  const _DecodedImageData(this.bytes, {this.mimeType});
}

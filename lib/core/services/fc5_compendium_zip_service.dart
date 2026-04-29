import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class FC5CompendiumZipException implements Exception {
  const FC5CompendiumZipException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class FC5CompendiumZipEntryPreview {
  const FC5CompendiumZipEntryPreview({
    required this.rawPath,
    required this.displayPath,
    required this.displayName,
    required this.sizeBytes,
    required this.items,
    required this.spells,
    required this.races,
    required this.classes,
    required this.backgrounds,
    required this.feats,
    required this.monsters,
    required this.warningCount,
    required this.errorCount,
    required this.isCombinedCandidate,
  });

  final String rawPath;
  final String displayPath;
  final String displayName;
  final int sizeBytes;
  final int items;
  final int spells;
  final int races;
  final int classes;
  final int backgrounds;
  final int feats;
  final int monsters;
  final int warningCount;
  final int errorCount;
  final bool isCombinedCandidate;

  int get supportedCount =>
      items + spells + races + classes + backgrounds + feats;

  bool get canImport => supportedCount > 0 && errorCount == 0;

  String get path => rawPath;
}

enum FC5CompendiumZipScanStage {
  readingArchive,
  scanningXml,
  preparingModules,
}

class FC5CompendiumZipScanProgress {
  const FC5CompendiumZipScanProgress({
    required this.stage,
    this.current = 0,
    this.total = 0,
    this.path,
  });

  final FC5CompendiumZipScanStage stage;
  final int current;
  final int total;
  final String? path;
}

typedef FC5CompendiumZipScanProgressCallback = void Function(
  FC5CompendiumZipScanProgress progress,
);

class FC5CompendiumZipPreview {
  const FC5CompendiumZipPreview({
    required this.archiveName,
    required this.entries,
    required this.ignoredFileCount,
    required this.totalUncompressedBytes,
  });

  final String archiveName;
  final List<FC5CompendiumZipEntryPreview> entries;
  final int ignoredFileCount;
  final int totalUncompressedBytes;

  FC5CompendiumZipEntryPreview? get suggestedEntry {
    final importable = entries.where((entry) => entry.canImport).toList();
    if (importable.isEmpty) return null;

    final combined = importable.where((entry) => entry.isCombinedCandidate);
    if (combined.isNotEmpty) {
      return combined.reduce(
        (a, b) => a.supportedCount >= b.supportedCount ? a : b,
      );
    }

    return importable.reduce(
      (a, b) => a.supportedCount >= b.supportedCount ? a : b,
    );
  }
}

class FC5CompendiumZipService {
  static const int maxFileCount = 128;
  static const int maxXmlFileCount = 64;
  static const int maxSingleFileBytes = 12 * 1024 * 1024;
  static const int maxTotalUncompressedBytes = 32 * 1024 * 1024;

  static Future<FC5CompendiumZipPreview> previewFile(
    File file, {
    FC5CompendiumZipScanProgressCallback? onProgress,
  }) async {
    final archiveName = file.path.split(Platform.pathSeparator).last;
    onProgress?.call(
      const FC5CompendiumZipScanProgress(
        stage: FC5CompendiumZipScanStage.readingArchive,
      ),
    );
    return previewBytes(
      await file.readAsBytes(),
      archiveName: archiveName,
      onProgress: onProgress,
    );
  }

  static Future<FC5CompendiumZipPreview> previewBytes(
    List<int> bytes, {
    String archiveName = 'compendium.zip',
    FC5CompendiumZipScanProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const FC5CompendiumZipScanProgress(
        stage: FC5CompendiumZipScanStage.readingArchive,
      ),
    );
    final archive = _decodeArchive(bytes);
    final nameIndex = _ZipNameIndex.fromBytes(bytes);
    final entries = <FC5CompendiumZipEntryPreview>[];
    final seenPaths = <String>{};
    final xmlEntries = <_ZipArchiveEntry>[];
    var ignoredFileCount = 0;
    var totalUncompressedBytes = 0;

    for (final entry in archive) {
      if (entry.isDirectory) continue;
      final decodedEntry = _ZipArchiveEntry(
        file: entry,
        displayPath: nameIndex.displayPathFor(entry.name),
      );
      _validateEntry(decodedEntry, seenPaths);
      totalUncompressedBytes += entry.size;
      if (totalUncompressedBytes > maxTotalUncompressedBytes) {
        throw const FC5CompendiumZipException(
          'zip_too_large',
          'FC5 compendium ZIP is too large.',
        );
      }

      if (!_isXmlPath(decodedEntry.displayPath)) {
        ignoredFileCount += 1;
        continue;
      }

      if (xmlEntries.length >= maxXmlFileCount) {
        throw const FC5CompendiumZipException(
          'too_many_xml_files',
          'FC5 compendium ZIP contains too many XML files.',
        );
      }

      xmlEntries.add(decodedEntry);
    }

    for (var index = 0; index < xmlEntries.length; index++) {
      final entry = xmlEntries[index];
      onProgress?.call(
        FC5CompendiumZipScanProgress(
          stage: FC5CompendiumZipScanStage.scanningXml,
          current: index + 1,
          total: xmlEntries.length,
          path: entry.displayPath,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final xmlContent = utf8.decode(entry.file.readBytes() ?? const []);
      final stats = _countXmlEntry(xmlContent);
      entries.add(
        FC5CompendiumZipEntryPreview(
          rawPath: entry.rawPath,
          displayPath: entry.displayPath,
          displayName: _basename(entry.displayPath),
          sizeBytes: entry.file.size,
          items: stats.items,
          spells: stats.spells,
          races: stats.races,
          classes: stats.classes,
          backgrounds: stats.backgrounds,
          feats: stats.feats,
          monsters: stats.monsters,
          warningCount: stats.warningCount,
          errorCount: stats.errorCount,
          isCombinedCandidate: _isCombinedCandidate(entry.displayPath),
        ),
      );
    }

    onProgress?.call(
      FC5CompendiumZipScanProgress(
        stage: FC5CompendiumZipScanStage.preparingModules,
        current: xmlEntries.length,
        total: xmlEntries.length,
      ),
    );

    entries.sort((a, b) {
      if (a.isCombinedCandidate != b.isCombinedCandidate) {
        return a.isCombinedCandidate ? -1 : 1;
      }
      return b.supportedCount.compareTo(a.supportedCount);
    });

    return FC5CompendiumZipPreview(
      archiveName: archiveName,
      entries: entries,
      ignoredFileCount: ignoredFileCount,
      totalUncompressedBytes: totalUncompressedBytes,
    );
  }

  static Future<String> readXmlEntry(File file, String entryPath) async {
    final bytes = await file.readAsBytes();
    final archive = _decodeArchive(bytes);
    final nameIndex = _ZipNameIndex.fromBytes(bytes);
    final seenPaths = <String>{};

    for (final entry in archive) {
      if (entry.isDirectory) continue;
      final decodedEntry = _ZipArchiveEntry(
        file: entry,
        displayPath: nameIndex.displayPathFor(entry.name),
      );
      _validateEntry(decodedEntry, seenPaths);
      if (decodedEntry.rawPath != entryPath &&
          decodedEntry.displayPath != entryPath) {
        continue;
      }
      if (!_isXmlPath(decodedEntry.displayPath)) {
        throw const FC5CompendiumZipException(
          'not_xml',
          'Selected ZIP entry is not an XML file.',
        );
      }
      return utf8.decode(entry.readBytes() ?? const []);
    }

    throw FC5CompendiumZipException(
      'missing_entry',
      'Selected XML was not found in the ZIP: $entryPath',
    );
  }

  static Archive _decodeArchive(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      if (archive.length > maxFileCount) {
        throw const FC5CompendiumZipException(
          'too_many_files',
          'FC5 compendium ZIP contains too many files.',
        );
      }
      return archive;
    } on FC5CompendiumZipException {
      rethrow;
    } catch (error) {
      throw FC5CompendiumZipException(
        'invalid_zip',
        'Failed to read FC5 compendium ZIP: $error',
      );
    }
  }

  static void _validateEntry(_ZipArchiveEntry entry, Set<String> seenPaths) {
    _validatePath(entry.rawPath);
    _validatePath(entry.displayPath);
    if (!seenPaths.add(entry.rawPath)) {
      throw FC5CompendiumZipException(
        'duplicate_path',
        'FC5 compendium ZIP contains duplicate path: ${entry.displayPath}',
      );
    }
    if (entry.file.size > maxSingleFileBytes) {
      throw FC5CompendiumZipException(
        'file_too_large',
        'ZIP entry is too large: ${entry.displayPath}',
      );
    }
  }

  static void _validatePath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.startsWith(r'\') ||
        path.contains(r'\') ||
        path.contains(':') ||
        path.split('/').any((segment) => segment == '..' || segment.isEmpty)) {
      throw FC5CompendiumZipException(
        'unsafe_path',
        'Unsafe path in FC5 compendium ZIP: $path',
      );
    }
  }

  static bool _isXmlPath(String path) {
    return path.toLowerCase().endsWith('.xml');
  }

  static bool _isCombinedCandidate(String path) {
    final name = _basename(path).toLowerCase();
    return name == 'fc5 compendium.xml' || name == 'compendium.xml';
  }

  static String _basename(String path) {
    return path.split('/').last;
  }

  static String _decodeLegacyPathFromArchiveKey(String rawPath) {
    final bytes = <int>[];
    for (final codeUnit in rawPath.codeUnits) {
      if (codeUnit > 0xff) return rawPath;
      bytes.add(codeUnit);
    }
    return _decodeLegacyPathBytes(bytes);
  }

  static String _decodeLegacyPathBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      final cp866 = _decodeCp866(bytes);
      final cp437 = _decodeCp437(bytes);
      return _cyrillicScore(cp866) >= _cyrillicScore(cp437) ? cp866 : cp437;
    }
  }

  static String _decodeCp866(List<int> bytes) {
    return String.fromCharCodes(bytes.map(_decodeCp866Byte));
  }

  static int _decodeCp866Byte(int byte) {
    if (byte < 0x80) return byte;
    if (byte >= 0x80 && byte <= 0xaf) return 0x0410 + (byte - 0x80);
    if (byte >= 0xe0 && byte <= 0xef) return 0x0440 + (byte - 0xe0);
    if (byte == 0xf0) return 0x0401;
    if (byte == 0xf1) return 0x0451;
    return _cp437CodePoint(byte);
  }

  static String _decodeCp437(List<int> bytes) {
    return String.fromCharCodes(bytes.map(_cp437CodePoint));
  }

  static int _cp437CodePoint(int byte) {
    if (byte < 0x80) return byte;
    return _cp437HighCodePoints[byte - 0x80];
  }

  static int _cyrillicScore(String value) {
    return value.runes
        .where((rune) =>
            (rune >= 0x0400 && rune <= 0x04ff) ||
            (rune >= 0x0500 && rune <= 0x052f))
        .length;
  }

  static const List<int> _cp437HighCodePoints = [
    0x00c7,
    0x00fc,
    0x00e9,
    0x00e2,
    0x00e4,
    0x00e0,
    0x00e5,
    0x00e7,
    0x00ea,
    0x00eb,
    0x00e8,
    0x00ef,
    0x00ee,
    0x00ec,
    0x00c4,
    0x00c5,
    0x00c9,
    0x00e6,
    0x00c6,
    0x00f4,
    0x00f6,
    0x00f2,
    0x00fb,
    0x00f9,
    0x00ff,
    0x00d6,
    0x00dc,
    0x00a2,
    0x00a3,
    0x00a5,
    0x20a7,
    0x0192,
    0x00e1,
    0x00ed,
    0x00f3,
    0x00fa,
    0x00f1,
    0x00d1,
    0x00aa,
    0x00ba,
    0x00bf,
    0x2310,
    0x00ac,
    0x00bd,
    0x00bc,
    0x00a1,
    0x00ab,
    0x00bb,
    0x2591,
    0x2592,
    0x2593,
    0x2502,
    0x2524,
    0x2561,
    0x2562,
    0x2556,
    0x2555,
    0x2563,
    0x2551,
    0x2557,
    0x255d,
    0x255c,
    0x255b,
    0x2510,
    0x2514,
    0x2534,
    0x252c,
    0x251c,
    0x2500,
    0x253c,
    0x255e,
    0x255f,
    0x255a,
    0x2554,
    0x2569,
    0x2566,
    0x2560,
    0x2550,
    0x256c,
    0x2567,
    0x2568,
    0x2564,
    0x2565,
    0x2559,
    0x2558,
    0x2552,
    0x2553,
    0x256b,
    0x256a,
    0x2518,
    0x250c,
    0x2588,
    0x2584,
    0x258c,
    0x2590,
    0x2580,
    0x03b1,
    0x00df,
    0x0393,
    0x03c0,
    0x03a3,
    0x03c3,
    0x00b5,
    0x03c4,
    0x03a6,
    0x0398,
    0x03a9,
    0x03b4,
    0x221e,
    0x03c6,
    0x03b5,
    0x2229,
    0x2261,
    0x00b1,
    0x2265,
    0x2264,
    0x2320,
    0x2321,
    0x00f7,
    0x2248,
    0x00b0,
    0x2219,
    0x00b7,
    0x221a,
    0x207f,
    0x00b2,
    0x25a0,
    0x00a0,
  ];

  static _ZipXmlStats _countXmlEntry(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;
      final stats = _ZipXmlStats();

      if (root.name.local == 'collection') {
        stats.errorCount = 1;
        return stats;
      }

      final nodes =
          root.name.local == 'compendium' ? root.childElements : [root];
      for (final node in nodes) {
        switch (node.name.local) {
          case 'item':
            stats.items += 1;
            break;
          case 'spell':
            stats.spells += 1;
            break;
          case 'race':
            stats.races += 1;
            break;
          case 'class':
            stats.classes += 1;
            break;
          case 'background':
            stats.backgrounds += 1;
            break;
          case 'feat':
            stats.feats += 1;
            break;
          case 'monster':
            stats.monsters += 1;
            break;
          case 'vehicle':
            stats.vehicles += 1;
            break;
          case 'imageData':
            break;
          default:
            if (node.innerText.trim().isNotEmpty ||
                node.childElements.isNotEmpty) {
              stats.warningCount += 1;
            }
            break;
        }
      }

      return stats;
    } catch (_) {
      return _ZipXmlStats()..errorCount = 1;
    }
  }
}

class _ZipArchiveEntry {
  const _ZipArchiveEntry({
    required this.file,
    required this.displayPath,
  });

  final ArchiveFile file;
  final String displayPath;

  String get rawPath => file.name;
}

class _ZipNameIndex {
  const _ZipNameIndex(this._displayPathsByRawPath);

  final Map<String, String> _displayPathsByRawPath;

  String displayPathFor(String rawPath) =>
      _displayPathsByRawPath[rawPath] ??
      FC5CompendiumZipService._decodeLegacyPathFromArchiveKey(rawPath);

  static _ZipNameIndex fromBytes(List<int> bytes) {
    final centralDirectory = _ZipCentralDirectory.tryRead(bytes);
    if (centralDirectory == null) return const _ZipNameIndex({});

    final displayPaths = <String, String>{};
    for (final entry in centralDirectory.entries) {
      displayPaths[entry.archiveKey] = entry.displayPath;
    }
    return _ZipNameIndex(displayPaths);
  }
}

class _ZipCentralDirectory {
  const _ZipCentralDirectory(this.entries);

  final List<_ZipCentralDirectoryEntry> entries;

  static _ZipCentralDirectory? tryRead(List<int> bytes) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final eocdOffset = _findEocd(data);
    if (eocdOffset < 0 || eocdOffset + 22 > data.length) return null;

    final totalEntries = _readUint16(data, eocdOffset + 10);
    final centralDirectorySize = _readUint32(data, eocdOffset + 12);
    final centralDirectoryOffset = _readUint32(data, eocdOffset + 16);
    if (centralDirectoryOffset < 0 ||
        centralDirectorySize < 0 ||
        centralDirectoryOffset + centralDirectorySize > data.length) {
      return null;
    }

    final entries = <_ZipCentralDirectoryEntry>[];
    var offset = centralDirectoryOffset;
    for (var i = 0; i < totalEntries && offset + 46 <= data.length; i++) {
      if (_readUint32(data, offset) != 0x02014b50) break;

      final flags = _readUint16(data, offset + 8);
      final fileNameLength = _readUint16(data, offset + 28);
      final extraLength = _readUint16(data, offset + 30);
      final commentLength = _readUint16(data, offset + 32);
      final nameStart = offset + 46;
      final extraStart = nameStart + fileNameLength;
      final nextOffset = extraStart + extraLength + commentLength;
      if (nextOffset > data.length) break;

      final fileNameBytes = data.sublist(nameStart, extraStart);
      final extraBytes = data.sublist(extraStart, extraStart + extraLength);
      entries.add(
        _ZipCentralDirectoryEntry.fromRaw(
          fileNameBytes: fileNameBytes,
          extraBytes: extraBytes,
          flags: flags,
        ),
      );
      offset = nextOffset;
    }

    return _ZipCentralDirectory(entries);
  }

  static int _findEocd(Uint8List data) {
    final minOffset = math.max(0, data.length - 0xffff - 22);
    for (var offset = data.length - 22; offset >= minOffset; offset--) {
      if (_readUint32(data, offset) == 0x06054b50) {
        return offset;
      }
    }
    return -1;
  }
}

class _ZipCentralDirectoryEntry {
  const _ZipCentralDirectoryEntry({
    required this.archiveKey,
    required this.displayPath,
  });

  final String archiveKey;
  final String displayPath;

  factory _ZipCentralDirectoryEntry.fromRaw({
    required List<int> fileNameBytes,
    required List<int> extraBytes,
    required int flags,
  }) {
    final archiveKey = _archiveKeyFromFileNameBytes(fileNameBytes);
    final unicodePath = _unicodePathExtraField(extraBytes);
    final displayPath = unicodePath ??
        ((flags & 0x0800) != 0
            ? utf8.decode(fileNameBytes, allowMalformed: false)
            : FC5CompendiumZipService._decodeLegacyPathBytes(fileNameBytes));

    return _ZipCentralDirectoryEntry(
      archiveKey: archiveKey,
      displayPath: displayPath,
    );
  }

  static String _archiveKeyFromFileNameBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return String.fromCharCodes(bytes);
    }
  }

  static String? _unicodePathExtraField(List<int> bytes) {
    var offset = 0;
    while (offset + 4 <= bytes.length) {
      final id = _readUint16(bytes, offset);
      final size = _readUint16(bytes, offset + 2);
      final dataStart = offset + 4;
      final dataEnd = dataStart + size;
      if (dataEnd > bytes.length) return null;

      if (id == 0x7075 && size >= 6 && bytes[dataStart] == 1) {
        try {
          return utf8.decode(bytes.sublist(dataStart + 5, dataEnd));
        } on FormatException {
          return null;
        }
      }

      offset = dataEnd;
    }
    return null;
  }
}

int _readUint16(List<int> bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _readUint32(List<int> bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

class _ZipXmlStats {
  int items = 0;
  int spells = 0;
  int races = 0;
  int classes = 0;
  int backgrounds = 0;
  int feats = 0;
  int monsters = 0;
  int vehicles = 0;
  int warningCount = 0;
  int errorCount = 0;
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/fc5_compendium_zip_service.dart';

void main() {
  test('FC5CompendiumZipService previews supported XML entries', () async {
    final bytes = _zipBytes({
      'Compendium/FC5 Compendium.xml': '''
<compendium>
  <item><name>Rope</name><type>G</type><text>Adventuring gear.</text></item>
  <spell><name>Light</name><level>0</level><school>Evocation</school><time>1 action</time><range>Touch</range><components>V, M</components><duration>1 hour</duration><classes>Wizard</classes><text>Light.</text></spell>
  <monster><name>Unsupported</name></monster>
</compendium>
''',
      'Compendium/ReadMe.docx': 'ignored',
    });

    final preview = await FC5CompendiumZipService.previewBytes(bytes);

    expect(preview.entries, hasLength(1));
    expect(preview.ignoredFileCount, 1);
    expect(preview.suggestedEntry?.isCombinedCandidate, isTrue);
    expect(preview.suggestedEntry?.items, 1);
    expect(preview.suggestedEntry?.spells, 1);
    expect(preview.suggestedEntry?.monsters, 1);
  });

  test('FC5CompendiumZipService disables monster-only XML entries', () async {
    final bytes = _zipBytes({
      'Compendium/FC5 Compendium.xml': '''
<compendium>
  <item><name>Rope</name><type>G</type><text>Adventuring gear.</text></item>
</compendium>
''',
      'Compendium/Beastiary.xml': '''
<compendium>
  <monster><name>Unsupported</name></monster>
  <monster><name>Also Unsupported</name></monster>
</compendium>
''',
    });

    final preview = await FC5CompendiumZipService.previewBytes(bytes);
    final monsterOnly = preview.entries.firstWhere(
      (entry) => entry.displayName == 'Beastiary.xml',
    );

    expect(monsterOnly.canImport, isFalse);
    expect(monsterOnly.supportedCount, 0);
    expect(monsterOnly.monsters, 2);
    expect(preview.suggestedEntry?.displayName, 'FC5 Compendium.xml');
  });

  test('FC5CompendiumZipService rejects zip-slip paths', () async {
    final bytes = _zipBytes({
      '../evil.xml': '<compendium></compendium>',
    });

    expect(
      () => FC5CompendiumZipService.previewBytes(bytes),
      throwsA(isA<FC5CompendiumZipException>()),
    );
  });

  test('FC5CompendiumZipService decodes Unicode Path extra field names',
      () async {
    const displayPath = 'Компендиум/Общие файлы/Заклинания Таша.xml';
    const xml = '''
<compendium>
  <spell><name>Mind Sliver</name><level>0</level><school>Enchantment</school><time>1 action</time><range>60 feet</range><components>V</components><duration>1 round</duration><classes>Wizard</classes><text>Psychic static.</text></spell>
</compendium>
''';
    final bytes = _zipBytesWithUnicodePathExtra(
      displayPath: displayPath,
      content: xml,
    );
    final tempDir = await Directory.systemTemp.createTemp('fc5_zip_test_');
    final zipFile = File('${tempDir.path}/compendium.zip');
    await zipFile.writeAsBytes(bytes);

    try {
      final preview = await FC5CompendiumZipService.previewBytes(bytes);
      final entry = preview.entries.single;

      expect(entry.displayPath, displayPath);
      expect(entry.displayName, 'Заклинания Таша.xml');
      expect(entry.rawPath, isNot(displayPath));
      expect(entry.spells, 1);

      final readXml =
          await FC5CompendiumZipService.readXmlEntry(zipFile, entry.rawPath);
      expect(readXml, contains('Mind Sliver'));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  final fixtureZip = File('/home/alexgrig/Downloads/Компендиум.zip');
  test(
    'FC5CompendiumZipService previews supplied Russian ZIP with decoded names',
    () async {
      final preview = await FC5CompendiumZipService.previewFile(fixtureZip);
      final paths = preview.entries.map((entry) => entry.displayPath).toSet();

      expect(preview.entries, hasLength(34));
      expect(preview.ignoredFileCount, 1);
      expect(preview.suggestedEntry?.displayPath,
          'Компендиум/Общие файлы/FC5 Compendium.xml');
      expect(
        paths,
        containsAll({
          'Компендиум/Tasha\'s Cauldron of Everything/Заклинания Таша.xml',
          'Компендиум/Player\'s handbook/Классы книги игрока.xml',
          'Компендиум/Общие файлы/Classes.xml',
        }),
      );
    },
    skip: fixtureZip.existsSync()
        ? false
        : 'Local supplied compendium ZIP is not available.',
  );
}

List<int> _zipBytes(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(
      ArchiveFile.bytes(entry.key, utf8.encode(entry.value)),
    );
  }
  return ZipEncoder().encode(archive);
}

List<int> _zipBytesWithUnicodePathExtra({
  required String displayPath,
  required String content,
}) {
  final nameBytes = _encodeCp866(displayPath);
  final contentBytes = utf8.encode(content);
  final nameCrc = getCrc32(nameBytes);
  final fileCrc = getCrc32(contentBytes);
  final unicodeBytes = utf8.encode(displayPath);
  final extra = <int>[
    0x75,
    0x70,
    ..._uint16(1 + 4 + unicodeBytes.length),
    1,
    ..._uint32(nameCrc),
    ...unicodeBytes,
  ];

  final localHeader = <int>[
    ..._uint32(0x04034b50),
    ..._uint16(20),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint32(fileCrc),
    ..._uint32(contentBytes.length),
    ..._uint32(contentBytes.length),
    ..._uint16(nameBytes.length),
    ..._uint16(extra.length),
    ...nameBytes,
    ...extra,
    ...contentBytes,
  ];
  final centralDirectoryOffset = localHeader.length;
  final centralDirectory = <int>[
    ..._uint32(0x02014b50),
    ..._uint16(20),
    ..._uint16(20),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint32(fileCrc),
    ..._uint32(contentBytes.length),
    ..._uint32(contentBytes.length),
    ..._uint16(nameBytes.length),
    ..._uint16(extra.length),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint32(0),
    ..._uint32(0),
    ...nameBytes,
    ...extra,
  ];
  final eocd = <int>[
    ..._uint32(0x06054b50),
    ..._uint16(0),
    ..._uint16(0),
    ..._uint16(1),
    ..._uint16(1),
    ..._uint32(centralDirectory.length),
    ..._uint32(centralDirectoryOffset),
    ..._uint16(0),
  ];

  return [...localHeader, ...centralDirectory, ...eocd];
}

List<int> _uint16(int value) => [value & 0xff, (value >> 8) & 0xff];

List<int> _uint32(int value) => [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];

List<int> _encodeCp866(String value) {
  return value.runes.map(_cp866ByteFor).toList(growable: false);
}

int _cp866ByteFor(int rune) {
  if (rune < 0x80) return rune;
  if (rune >= 0x0410 && rune <= 0x043f) return 0x80 + (rune - 0x0410);
  if (rune >= 0x0440 && rune <= 0x044f) return 0xe0 + (rune - 0x0440);
  if (rune == 0x0401) return 0xf0;
  if (rune == 0x0451) return 0xf1;
  throw ArgumentError('Unsupported CP866 rune: $rune');
}

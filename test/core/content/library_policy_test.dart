import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/content/library_policy.dart';
import 'package:qd_and_d/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd_library_policy_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  setUp(() async => StorageService.clearAll());

  const builtIn = ['Fireball', 'Shield', 'Cure Wounds'];
  const mine = ['Fireball (homebrew)', 'Shield', 'Eldritch Lance'];
  List<String> shelf() => LibraryPolicy.listed(builtIn, mine, (x) => x);

  test('by default the built-in entry stays and mine only add', () {
    expect(LibraryPolicy.srdEnabled, isTrue);
    expect(shelf(), ['Fireball', 'Shield', 'Cure Wounds', 'Eldritch Lance']);
    expect(LibraryPolicy.overlapping(builtIn, mine, (x) => x), 2);
  });

  test('keeping mine replaces the built-in entries they overlap', () async {
    await LibraryPolicy.setOverlap(LibraryOverlap.mine);
    expect(shelf(), ['Cure Wounds', ...mine]);
  });

  test('a put-away built-in book leaves only the player\'s books', () async {
    final before = LibraryPolicy.revision.value;
    await LibraryPolicy.setSrdEnabled(false);
    expect(LibraryPolicy.revision.value, before + 1);
    expect(shelf(), mine);
    await LibraryPolicy.setSrdEnabled(true);
    expect(shelf(), hasLength(4));
  });
}

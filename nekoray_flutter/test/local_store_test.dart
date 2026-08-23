import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekoray/core/models/profile.dart';
import 'package:nekoray/core/storage/local_store.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('nekoray_store_test');
    LocalStore.overrideRoot = tmp;
  });

  tearDown(() async {
    LocalStore.overrideRoot = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('allocateProfileIds never collides with existing files', () async {
    await LocalStore.saveProfile(
        ProxyEntity(id: 1, type: 'trojan', bean: {'addr': 'a', 'port': 1}).toJson());
    await LocalStore.saveProfile(
        ProxyEntity(id: 9, type: 'trojan', bean: {'addr': 'b', 'port': 1}).toJson());

    final ids = await LocalStore.allocateProfileIds(3);
    expect(ids, [10, 11, 12]);
    expect(ids.toSet().length, 3);
  });

  test('a batch import writes every node without overwriting', () async {
    final ids = await LocalStore.allocateProfileIds(20);
    final profiles = [
      for (final id in ids)
        ProxyEntity(id: id, type: 'trojan', bean: {'addr': 'host', 'port': 443})
            .toJson()
    ];
    await LocalStore.saveProfiles(profiles);

    final loaded = await LocalStore.loadProfiles();
    expect(loaded.length, 20, reason: 'ids must not collide within one batch');
  });

  test('a failing batch leaves no partial import behind', () async {
    final good = ProxyEntity(id: 100, type: 'trojan', bean: {'addr': 'a', 'port': 1})
        .toJson();
    final bad = {'id': 'not-an-int', 'type': 'trojan', 'bean': {}};

    await expectLater(
      LocalStore.saveProfiles([good, bad]),
      throwsA(isA<ArgumentError>()),
    );

    final loaded = await LocalStore.loadProfiles();
    expect(loaded, isEmpty, reason: 'the successful write must be rolled back');
  });

  test('corrupt files are reported rather than silently dropped', () async {
    await LocalStore.saveProfile(
        ProxyEntity(id: 1, type: 'trojan', bean: {'addr': 'a', 'port': 1}).toJson());
    await File('${tmp.path}/profiles/2.json').writeAsString('{ truncated');

    final corrupt = <String>[];
    final loaded = await LocalStore.loadProfiles(corrupt: corrupt);

    expect(loaded.length, 1);
    expect(corrupt.length, 1);
    expect(corrupt.single, endsWith('2.json'));
  });

  test('settings round-trip', () async {
    await LocalStore.saveSettings({'mixed_port': 3080, 'system_proxy': true});
    final read = await LocalStore.loadSettings();
    expect(read['mixed_port'], 3080);
    expect(read['system_proxy'], true);
  });

  test('routing file names are sanitised', () async {
    await LocalStore.saveRouting('../escape', {'rules': []});
    // The traversing name must not create a file outside the data directory.
    expect(await File('${tmp.path}/../routing_../escape.json').exists(), isFalse);
    final entries = tmp.listSync().map((e) => e.path.split('/').last).toList();
    expect(entries.any((n) => n.startsWith('routing_') && !n.contains('/')), isTrue);
  });

  test('no temp files survive a successful write', () async {
    await LocalStore.saveProfile(
        ProxyEntity(id: 1, type: 'trojan', bean: {'addr': 'a', 'port': 1}).toJson());
    final leftovers = Directory('${tmp.path}/profiles')
        .listSync()
        .where((e) => e.path.endsWith('.tmp'))
        .toList();
    expect(leftovers, isEmpty);
  });
}

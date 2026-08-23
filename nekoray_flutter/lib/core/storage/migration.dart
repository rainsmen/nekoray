// Data migration from an older nekoray configuration directory.
//
// All I/O is asynchronous: the previous implementation used listSync /
// readAsStringSync on the UI isolate, which froze the app for the duration of
// the scan.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/profile.dart';
import 'local_store.dart';

class DataMigration {
  /// Scans [oldDir] for nekoray config files and imports them.
  ///
  /// Profiles are written as one batch so a failure cannot leave a partial
  /// import behind. Ids are reallocated to avoid colliding with profiles that
  /// already exist in the destination.
  static Future<MigrationReport> migrateFrom(
    String oldDir, {
    bool dryRun = false,
  }) async {
    final report = MigrationReport();
    final oldRoot = Directory(oldDir);
    if (!await oldRoot.exists()) {
      report.errors.add('Source directory does not exist: $oldDir');
      return report;
    }

    // Parse all source objects before writing anything. This lets us allocate
    // fresh profile/group IDs up front and keep every cross-reference valid.
    final profileMaps = <Map<String, dynamic>>[];
    final oldProfiles = Directory('$oldDir/profiles');
    if (await oldProfiles.exists()) {
      await for (final f in oldProfiles.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await f.readAsString());
          if (json is Map<String, dynamic>) {
            profileMaps.add(json);
          } else {
            report.errors.add('profile ${f.path}: not a JSON object');
          }
        } catch (e) {
          report.errors.add('profile ${f.path}: $e');
        }
      }
    }

    final groups = <ProfileGroup>[];
    final oldGroups = Directory('$oldDir/groups');
    if (await oldGroups.exists()) {
      await for (final f in oldGroups.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await f.readAsString());
          if (json is Map<String, dynamic>) {
            groups.add(ProfileGroup.fromJson(json));
          } else {
            report.errors.add('group ${f.path}: not a JSON object');
          }
        } catch (e) {
          report.errors.add('group ${f.path}: $e');
        }
      }
    }

    final profileIdMap = <int, int>{};
    final groupIdMap = <int, int>{};
    if (!dryRun && groups.isNotEmpty) {
      final ids = await LocalStore.allocateGroupIds(groups.length);
      for (var i = 0; i < groups.length; i++) {
        groupIdMap[groups[i].id] = ids[i];
      }
    }

    var profilesReady = dryRun || profileMaps.isEmpty;
    if (!dryRun && profileMaps.isNotEmpty) {
      try {
        final ids = await LocalStore.allocateProfileIds(profileMaps.length);
        final entities = <Map<String, dynamic>>[];
        for (var i = 0; i < profileMaps.length; i++) {
          final e = ProxyEntity.fromJson(profileMaps[i]);
          profileIdMap[e.id] = ids[i];
          entities.add(ProxyEntity(
            id: ids[i],
            gid: groupIdMap[e.gid] ?? e.gid,
            type: e.type,
            bean: e.bean,
            latency: e.latency,
          ).toJson());
        }
        await LocalStore.saveProfiles(entities);
        report.profiles = entities.length;
      } catch (e) {
        profilesReady = false;
        report.errors.add('writing profiles: $e');
      }
    } else {
      report.profiles = profileMaps.length;
    }

    // Do not write groups if the profile batch failed: otherwise their order
    // and front-proxy references would point at files that were not imported.
    if (profilesReady) {
      for (final group in groups) {
        try {
          final remappedOrder = group.order
              .map((id) => profileIdMap[id])
              .whereType<int>()
              .toList();
          final migrated = ProfileGroup(
            id: groupIdMap[group.id] ?? group.id,
            archive: group.archive,
            name: group.name,
            url: group.url,
            info: group.info,
            subLastUpdate: group.subLastUpdate,
            frontProxyId: profileIdMap[group.frontProxyId] ?? 0,
            skipAutoUpdate: group.skipAutoUpdate,
            order: remappedOrder,
          );
          if (!dryRun) await LocalStore.saveGroup(migrated.toJson());
          report.groups++;
        } catch (e) {
          report.errors.add('group ${group.id}: $e');
        }
      }
    }

    // --- routing ---
    await for (final entry in oldRoot.list()) {
      if (entry is! File) continue;
      final name = entry.path.replaceAll('\\', '/').split('/').last;
      if (!name.startsWith('routing_') || !name.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entry.readAsString());
        if (json is Map<String, dynamic>) {
          final routingName =
              name.substring('routing_'.length, name.length - '.json'.length);
          if (!dryRun) await LocalStore.saveRouting(routingName, json);
          report.routing++;
        }
      } catch (e) {
        report.errors.add('routing $name: $e');
      }
    }

    return report;
  }

  /// Detects an older nekoray config directory for the current platform.
  static Future<String?> detectOldConfigDir() async {
    final candidates = <String>[];

    final support = await getApplicationSupportDirectory();
    candidates.add('${support.path}/nekoray_old');

    final home = Platform.environment['HOME'];
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) candidates.add('$appData/nekoray');
    } else if (Platform.isLinux && home != null) {
      candidates.add('$home/.config/nekoray');
    } else if (Platform.isMacOS && home != null) {
      candidates.add('$home/Library/Application Support/nekoray');
    }

    final current = await LocalStore.rootPath();
    for (final path in candidates) {
      if (path == current) continue; // never "migrate" onto ourselves
      if (!await Directory(path).exists()) continue;
      if (await Directory('$path/profiles').exists() ||
          await Directory('$path/groups').exists()) {
        return path;
      }
    }
    return null;
  }
}

class MigrationReport {
  int profiles = 0;
  int groups = 0;
  int routing = 0;
  final List<String> errors = [];

  bool get hasErrors => errors.isNotEmpty;

  @override
  String toString() =>
      'Migration complete: profiles=$profiles groups=$groups routing=$routing'
      '${errors.isEmpty ? '' : ' errors=${errors.length}'}';
}

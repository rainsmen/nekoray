// Data migration from old C++ nekoray config (task 16).
//
// Reads profiles/*.json, groups/*.json, routing_*.json from the old config
// directory and imports them into the new Flutter LocalStore.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../storage/local_store.dart';

class DataMigration {
  /// Scans [oldDir] for old nekoray config files and imports them.
  ///
  /// Returns a summary of what was migrated.
  static Future<MigrationReport> migrateFromCppVersion(
    String oldDir, {
    bool dryRun = false,
  }) async {
    final report = MigrationReport();

    final oldRoot = Directory(oldDir);
    if (!oldRoot.existsSync()) {
      report.errors.add('Source directory does not exist: $oldDir');
      return report;
    }

    // migrate profiles
    final oldProfiles = Directory('$oldDir/profiles');
    if (oldProfiles.existsSync()) {
      for (final f in oldProfiles.listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(f.readAsStringSync());
          if (json is Map<String, dynamic>) {
            if (!dryRun) await LocalStore.saveProfile(json);
            report.profiles++;
          }
        } catch (e) {
          report.errors.add('profile ${f.path}: $e');
        }
      }
    }

    // migrate groups
    final oldGroups = Directory('$oldDir/groups');
    if (oldGroups.existsSync()) {
      for (final f in oldGroups.listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(f.readAsStringSync());
          if (json is Map<String, dynamic>) {
            if (!dryRun) await LocalStore.saveGroup(json);
            report.groups++;
          }
        } catch (e) {
          report.errors.add('group ${f.path}: $e');
        }
      }
    }

    // migrate routing files
    for (final entry in oldRoot.listSync()) {
      if (entry is! File) continue;
      final name = entry.path.split('/').last;
      if (!name.startsWith('routing_') || !name.endsWith('.json')) continue;
      try {
        final json = jsonDecode(entry.readAsStringSync());
        if (json is Map<String, dynamic>) {
          final routingName = name.replaceAll('routing_', '').replaceAll('.json', '');
          if (!dryRun) await LocalStore.saveRouting(routingName, json);
          report.routing++;
        }
      } catch (e) {
        report.errors.add('routing $name: $e');
      }
    }

    return report;
  }

  /// Detects the old nekoray config directory based on platform.
  static Future<String?> detectOldConfigDir() async {
    // Common locations for old nekoray config
    final candidates = <String>[];

    final support = await getApplicationSupportDirectory();
    candidates.add('${support.path}/nekoray_old');

    // Platform-specific paths
    if (Platform.isWindows) {
      candidates.add('${Platform.environment['APPDATA']}/nekoray');
    } else if (Platform.isLinux) {
      candidates.add('${Platform.environment['HOME']}/.config/nekoray');
    } else if (Platform.isMacOS) {
      candidates.add('${Platform.environment['HOME']}/Library/Application Support/nekoray');
    }

    for (final path in candidates) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        // Check for profiles or groups dir to confirm it's a nekoray config
        if (Directory('$path/profiles').existsSync() ||
            Directory('$path/groups').existsSync()) {
          return path;
        }
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

  @override
  String toString() =>
      'Migration complete: profiles=$profiles groups=$groups routing=$routing'
      '${errors.isEmpty ? '' : ' errors=${errors.length}'}';
}

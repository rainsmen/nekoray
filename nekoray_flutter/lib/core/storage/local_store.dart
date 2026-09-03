// JSON file-backed storage.
//
// Layout (portable-first):
//   <appDir>/profiles/<id>.json
//   <appDir>/groups/<id>.json
//   <appDir>/routing_<name>.json
//   <appDir>/settings.json
//
// <appDir> is `<exeDir>/data` on Windows/Linux (so configs travel with the
// program folder), `NEKORAY_DATA_DIR` when set, and the OS app-support dir
// otherwise (read-only installs, macOS bundles, unit tests via overrideRoot).
// First run migrates legacy app-support data into an empty portable dir.
//
// All writes go through [_writeAtomic]: content is written to a temporary file
// in the same directory and renamed into place. A non-atomic write left
// truncated JSON behind on crash, and the loader silently discarded it —
// losing the profile without telling anyone.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  LocalStore._();

  static const _encoder = JsonEncoder.withIndent('  ');

  // Serialize ID scans and reservations within this process. Without this,
  // concurrent imports can observe the same max ID and overwrite each other.
  static Future<void> _idLock = Future<void>.value();
  static int? _nextProfileId;
  static int? _nextGroupId;

  /// Overridable for tests.
  static Directory? overrideRoot;

  static Future<Directory> _root() async {
    final override = overrideRoot;
    if (override != null) {
      if (!await override.exists()) await override.create(recursive: true);
      return override;
    }
    // Portable first: user data lives next to the program so configs can be
    // shared/carried with the folder. Falls back to the OS app-support dir
    // when portable storage is unavailable (read-only install, macOS bundle).
    final portable = await _portableDir();
    if (portable != null) return portable;
    return _appSupportDir();
  }

  static Future<Directory> _appSupportDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/nekoray');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _restrictPermissions(dir.path);
    }
    return dir;
  }

  /// Resolves `<exeDir>/data`, or null when portable storage must not be
  /// used. `NEKORAY_DATA_DIR` overrides the location everywhere (useful for
  /// tests and custom layouts). macOS `.app` bundles are excluded: the
  /// bundle is replaced wholesale on update (wiping anything inside) and
  /// writing into it breaks code signatures.
  static Future<Directory?> _portableDir() async {
    try {
      final env = Platform.environment['NEKORAY_DATA_DIR'];
      if (env != null && env.isNotEmpty) {
        final d = Directory(env);
        await d.create(recursive: true);
        if (await _writable(d)) return d;
        return null;
      }
      if (Platform.isMacOS &&
          Platform.resolvedExecutable.contains('.app/')) {
        return null;
      }
      final exeDir = File(Platform.resolvedExecutable).parent;
      final d =
          Directory('${exeDir.path}${Platform.pathSeparator}data');
      await d.create(recursive: true);
      if (!await _writable(d)) return null;
      await _restrictPermissions(d.path);
      // One-time move from the legacy location. Only into an empty dir, and
      // only when the move actually lands — otherwise stay on the legacy dir
      // so existing configs never disappear (e.g. cross-volume installs).
      if (!await _hasProfiles(d) && await _hasProfiles(await _appSupportDir())) {
        await _moveLegacy(await _appSupportDir(), d);
      }
      if (!await _hasProfiles(d) && await _hasProfiles(await _appSupportDir())) {
        return null;
      }
      return d;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _writable(Directory d) async {
    try {
      final probe = File(
          '${d.path}${Platform.pathSeparator}.writetest');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasProfiles(Directory d) async {
    try {
      final pd = Directory('${d.path}${Platform.pathSeparator}profiles');
      if (!await pd.exists()) return false;
      await for (final f in pd.list()) {
        if (f is File && f.path.endsWith('.json')) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Moves legacy data (profiles/groups/routing/settings) into [dst].
  /// Transient dirs (logs, diagnostics, backups) are left behind; failures
  /// are swallowed and detected by the caller via [_hasProfiles].
  static Future<void> _moveLegacy(Directory src, Directory dst) async {
    try {
      for (final name in ['profiles', 'groups', 'backups']) {
        final s = Directory('${src.path}${Platform.pathSeparator}$name');
        if (!await s.exists()) continue;
        try {
          await s.rename('${dst.path}${Platform.pathSeparator}$name');
        } catch (_) {}
      }
      for (final name in ['settings.json']) {
        final s = File('${src.path}${Platform.pathSeparator}$name');
        if (!await s.exists()) continue;
        try {
          await s.rename('${dst.path}${Platform.pathSeparator}$name');
        } catch (_) {}
      }
      await for (final e in src.list()) {
        if (e is! File) continue;
        final name = _baseName(e.path);
        if (!name.startsWith('routing_') || !name.endsWith('.json')) continue;
        try {
          await e.rename('${dst.path}${Platform.pathSeparator}$name');
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<Directory> _subDir(String name) async {
    final d = Directory('${(await _root()).path}/$name');
    if (!await d.exists()) {
      await d.create(recursive: true);
      await _restrictPermissions(d.path);
    }
    return d;
  }

  static Future<Directory> _profilesDir() => _subDir('profiles');
  static Future<Directory> _groupsDir() => _subDir('groups');

  /// Restricts a path to the current user on POSIX systems. Profiles hold
  /// passwords and private keys, so world-readable defaults are not acceptable.
  static Future<void> _restrictPermissions(String path) async {
    if (Platform.isWindows) return; // ACLs inherited from the user profile dir
    try {
      final isDir = await FileSystemEntity.isDirectory(path);
      await Process.run('chmod', [isDir ? '700' : '600', path]);
    } catch (_) {
      // Best effort — a missing chmod must not prevent saving.
    }
  }

  /// Writes [content] to [file] atomically.
  static Future<void> _writeAtomic(File file, String content) async {
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);

    final tmp = File(
        '${dir.path}/.${_baseName(file.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      final handle = await tmp.open(mode: FileMode.write);
      try {
        await handle.writeString(content);
        await handle.flush();
      } finally {
        await handle.close();
      }
      await _restrictPermissions(tmp.path);
      await tmp.rename(file.path);
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> _writeAtomicBytes(File file, List<int> content) async {
    final dir = file.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    final tmp = File(
        '${dir.path}/.${_baseName(file.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsBytes(content, flush: true);
      await _restrictPermissions(tmp.path);
      await tmp.rename(file.path);
    } catch (e) {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  static String _baseName(String path) =>
      path.replaceAll('\\', '/').split('/').last;

  /// Reads every `*.json` in [dir]. Files that fail to parse are reported in
  /// [corrupt] instead of being silently dropped.
  static Future<List<Map<String, dynamic>>> _loadDir(
    Directory dir, {
    List<String>? corrupt,
  }) async {
    final out = <Map<String, dynamic>>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      if (_baseName(f.path).startsWith('.')) continue; // stale temp file
      try {
        final j = jsonDecode(await f.readAsString());
        if (j is Map<String, dynamic>) {
          out.add(j);
        } else {
          corrupt?.add(f.path);
        }
      } catch (_) {
        corrupt?.add(f.path);
      }
    }
    return out;
  }

  // --- Profiles ---------------------------------------------------------

  static Future<List<Map<String, dynamic>>> loadProfiles({
    List<String>? corrupt,
  }) async =>
      _loadDir(await _profilesDir(), corrupt: corrupt);

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final id = profile['id'];
    if (id is! int) {
      throw ArgumentError('profile id must be an int, got ${id.runtimeType}');
    }
    final f = File('${(await _profilesDir()).path}/$id.json');
    await _writeAtomic(f, _encoder.convert(profile));
  }

  /// Saves several profiles, rolling back everything on failure so a partial
  /// subscription import cannot leave orphaned nodes behind.
  static Future<void> saveProfiles(List<Map<String, dynamic>> profiles) async {
    final previous = <String, List<int>?>{};
    final dir = await _profilesDir();
    try {
      for (final p in profiles) {
        final id = p['id'];
        if (id is! int) {
          throw ArgumentError('profile id must be an int, got ${id.runtimeType}');
        }
        final f = File('${dir.path}/$id.json');
        final path = f.path;
        if (!previous.containsKey(path)) {
          previous[path] = await f.exists() ? await f.readAsBytes() : null;
        }
        await _writeAtomic(f, _encoder.convert(p));
      }
    } catch (_) {
      // Restore both newly created files and files that were overwritten. A
      // batch import must be all-or-nothing even when an ID is reused.
      for (final entry in previous.entries) {
        try {
          final old = entry.value;
          final file = File(entry.key);
          if (old == null) {
            if (await file.exists()) await file.delete();
          } else {
            await _writeAtomicBytes(file, old);
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> deleteProfile(int id) async {
    final f = File('${(await _profilesDir()).path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  // --- Groups -----------------------------------------------------------

  static Future<List<Map<String, dynamic>>> loadGroups({
    List<String>? corrupt,
  }) async =>
      _loadDir(await _groupsDir(), corrupt: corrupt);

  static Future<void> saveGroup(Map<String, dynamic> group) async {
    final id = group['id'];
    if (id is! int) {
      throw ArgumentError('group id must be an int, got ${id.runtimeType}');
    }
    final f = File('${(await _groupsDir()).path}/$id.json');
    await _writeAtomic(f, _encoder.convert(group));
  }

  static Future<void> deleteGroup(int id) async {
    final f = File('${(await _groupsDir()).path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  // --- Routing ----------------------------------------------------------

  static Future<Map<String, dynamic>?> loadRouting(String name) async {
    final f = File('${(await _root()).path}/routing_${_safeName(name)}.json');
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRouting(String name, Map<String, dynamic> data) async {
    final f = File('${(await _root()).path}/routing_${_safeName(name)}.json');
    await _writeAtomic(f, _encoder.convert(data));
  }

  // --- Settings ---------------------------------------------------------

  static Future<Map<String, dynamic>> loadSettings() async {
    final f = File('${(await _root()).path}/settings.json');
    if (!await f.exists()) return <String, dynamic>{};
    try {
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> ? j : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final f = File('${(await _root()).path}/settings.json');
    await _writeAtomic(f, _encoder.convert(settings));
  }

  // --- Backup & Restore --------------------------------------------------

  /// Creates a unified backup map containing all profiles, groups, routing, and settings.
  static Future<Map<String, dynamic>> exportBackup() async {
    final profiles = await loadProfiles();
    final groups = await loadGroups();
    final routing = await loadRouting('default') ?? {};
    final settings = await loadSettings();
    return {
      'app': 'nekoray',
      'version': '5.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'profiles': profiles,
      'groups': groups,
      'routing': routing,
      'settings': settings,
    };
  }

  /// Restores a unified backup map.
  static Future<void> importBackup(
    Map<String, dynamic> backup, {
    bool clearExisting = true,
  }) async {
    if (clearExisting) {
      final profiles = await loadProfiles();
      for (final p in profiles) {
        if (p['id'] is int) await deleteProfile(p['id']);
      }
      final groups = await loadGroups();
      for (final g in groups) {
        if (g['id'] is int) await deleteGroup(g['id']);
      }
    }

    final rawProfiles = backup['profiles'];
    if (rawProfiles is List) {
      for (final p in rawProfiles) {
        if (p is Map<String, dynamic> && p['id'] is int) {
          await saveProfile(p);
        }
      }
    }

    final rawGroups = backup['groups'];
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is Map<String, dynamic> && g['id'] is int) {
          await saveGroup(g);
        }
      }
    }

    final routing = backup['routing'];
    if (routing is Map<String, dynamic> && routing.isNotEmpty) {
      await saveRouting('default', routing);
    }

    final settings = backup['settings'];
    if (settings is Map<String, dynamic> && settings.isNotEmpty) {
      await saveSettings(settings);
    }
  }

  /// Creates a local timestamped snapshot in <appDir>/backups/
  static Future<String> createLocalBackup() async {
    final data = await exportBackup();
    final dir = await _subDir('backups');
    final now = DateTime.now();
    final timestamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final filename = 'backup_$timestamp.json';
    final file = File('${dir.path}/$filename');
    await _writeAtomic(file, _encoder.convert(data));
    return filename;
  }

  /// Lists all local backup files sorted by creation time descending.
  static Future<List<File>> listLocalBackups() async {
    final dir = await _subDir('backups');
    final list = <File>[];
    if (await dir.exists()) {
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.json')) {
          list.add(f);
        }
      }
    }
    list.sort((a, b) => b.path.compareTo(a.path));
    return list;
  }

  /// Restores a specific local backup file.
  static Future<void> restoreLocalBackup(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('Backup file not found', file.path);
    }
    final content = await file.readAsString();
    final json = jsonDecode(content);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format: root must be a JSON object');
    }
    await importBackup(json, clearExisting: true);
  }

  // --- ID allocation ----------------------------------------------------

  /// Returns [count] ids that do not collide with anything already on disk.
  ///
  /// The previous scheme (`millisecondsSinceEpoch % 1e6 + len % 1000`) produced
  /// duplicates whenever several nodes were imported in the same millisecond,
  /// and each duplicate silently overwrote the previous file.
  static Future<List<int>> allocateProfileIds(int count) async =>
      _allocateIds(await _profilesDir(), count);

  static Future<List<int>> allocateGroupIds(int count) async =>
      _allocateIds(await _groupsDir(), count);

  static Future<List<int>> _allocateIds(Directory dir, int count) async {
    final previous = _idLock;
    final gate = Completer<void>();
    _idLock = gate.future;
    await previous;
    try {
      var maxId = 0;
      await for (final f in dir.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final stem = _baseName(f.path);
        final id = int.tryParse(stem.substring(0, stem.length - 5));
        if (id != null && id > maxId) maxId = id;
      }
      final isProfiles = _baseName(dir.path) == 'profiles';
      final reserved = isProfiles ? _nextProfileId : _nextGroupId;
      final first = (reserved ?? (maxId + 1)).clamp(maxId + 1, 0x7fffffff).toInt();
      final next = first + count;
      if (isProfiles) {
        _nextProfileId = next;
      } else {
        _nextGroupId = next;
      }
      return List<int>.generate(count, (i) => first + i);
    } finally {
      gate.complete();
    }
  }

  /// Absolute path of the data directory (exposed for diagnostics).
  static Future<String> rootPath() async => (await _root()).path;

  /// File holding the running core's pid, used to reap orphans after a crash.
  static Future<File> corePidFile() async =>
      File('${(await _root()).path}/core.pid');

  /// Writes a diagnostics bundle (environment, storage stats, the in-memory
  /// log tail plus the tail of today's persisted core log) and returns its
  /// path. Secrets are never included: profiles hold passwords/private keys,
  /// so only counts are recorded.
  static Future<String> exportDiagnostics(List<String> memoryLogs) async {
    final dir = await _subDir('diagnostics');
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final buf = StringBuffer()
      ..writeln('NekoRay diagnostics $stamp')
      ..writeln('platform: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}')
      ..writeln('root: ${(await _root()).path}');

    Future<int> countJson(Directory d) async {
      var n = 0;
      try {
        if (await d.exists()) {
          await for (final f in d.list()) {
            if (f is File && f.path.endsWith('.json')) n++;
          }
        }
      } catch (_) {}
      return n;
    }

    buf
      ..writeln('profiles: ${await countJson(await _profilesDir())}')
      ..writeln('groups: ${await countJson(await _groupsDir())}');

    final tail = memoryLogs.length > 500
        ? memoryLogs.sublist(memoryLogs.length - 500)
        : memoryLogs;
    buf.writeln('--- memory log (${tail.length} lines) ---');
    for (final line in tail) {
      buf.writeln(line);
    }

    try {
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final persisted =
          File('${(await _root()).path}/logs/core-$day.log');
      if (await persisted.exists()) {
        final lines = await persisted.readAsLines();
        final persistedTail = lines.length > 200
            ? lines.sublist(lines.length - 200)
            : lines;
        buf.writeln('--- persisted log (${persistedTail.length} lines) ---');
        for (final line in persistedTail) {
          buf.writeln(line);
        }
      }
    } catch (_) {}

    final file = File('${dir.path}/diag-$stamp.txt');
    await _writeAtomic(file, buf.toString());
    return file.path;
  }

  // --- Core log persistence ----------------------------------------------

  /// Maximum size of a daily core log file before it is rotated (2 MiB).
  static const maxCoreLogBytes = 2 << 20;

  /// Appends one line to `<root>/logs/core-YYYY-MM-DD.log`, rotating the
  /// previous day-file aside when it exceeds [maxCoreLogBytes].
  ///
  /// Fire-and-forget safe: every failure is swallowed so logging can never
  /// crash the app it is trying to diagnose. Respects [overrideRoot], so
  /// unit tests stay hermetic.
  static Future<void> appendCoreLog(String line) async {
    try {
      final dir = await _subDir('logs');
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/core-$day.log');
      if (await file.exists() &&
          await file.length() > maxCoreLogBytes) {
        final rotated = File('${dir.path}/core-$day.log.1');
        if (await rotated.exists()) await rotated.delete();
        await file.rename(rotated.path);
      }
      final stamp = now.toIso8601String();
      await file.writeAsString('$stamp $line\n',
          mode: FileMode.append, flush: false);
    } catch (_) {
      // Logging must never break the caller.
    }
  }
}

String _safeName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

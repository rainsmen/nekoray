// JSON file-backed storage.
//
// Layout (compatible with the C++ nekoray on-disk layout):
//   <appDir>/profiles/<id>.json
//   <appDir>/groups/<id>.json
//   <appDir>/routing_<name>.json
//   <appDir>/settings.json
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
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/nekoray');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      await _restrictPermissions(dir.path);
    }
    return dir;
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
}

String _safeName(String name) =>
    name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

// JSON file-backed storage — replaces the legacy hive-based store.
//
// Layout (same as old C++ nekoray, so existing files are read as-is):
//   <appDir>/profiles/<id>.json
//   <appDir>/groups/<id>.json
//   <appDir>/routing_<name>.json

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalStore {
  LocalStore._();

  static Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/nekoray');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> _profilesDir() async {
    final d = Directory('${(await _root()).path}/profiles');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<Directory> _groupsDir() async {
    final d = Directory('${(await _root()).path}/groups');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  // --- Profiles ---------------------------------------------------------

  static Future<List<Map<String, dynamic>>> loadProfiles() async {
    final dir = await _profilesDir();
    final out = <Map<String, dynamic>>[];
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(f.readAsStringSync());
        if (j is Map<String, dynamic>) out.add(j);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    final id = profile['id'];
    if (id == null) throw ArgumentError('profile missing id');
    final f = File('${(await _profilesDir()).path}/$id.json');
    f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(profile));
  }

  static Future<void> deleteProfile(int id) async {
    final f = File('${(await _profilesDir()).path}/$id.json');
    if (f.existsSync()) f.deleteSync();
  }

  // --- Groups -----------------------------------------------------------

  static Future<List<Map<String, dynamic>>> loadGroups() async {
    final dir = await _groupsDir();
    final out = <Map<String, dynamic>>[];
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(f.readAsStringSync());
        if (j is Map<String, dynamic>) out.add(j);
      } catch (_) {}
    }
    return out;
  }

  static Future<void> saveGroup(Map<String, dynamic> group) async {
    final id = group['id'];
    if (id == null) throw ArgumentError('group missing id');
    final f = File('${(await _groupsDir()).path}/$id.json');
    f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(group));
  }

  // --- Routing ----------------------------------------------------------

  static Future<Map<String, dynamic>?> loadRouting(String name) async {
    final f = File('${(await _root()).path}/routing_$name.json');
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRouting(String name, Map<String, dynamic> data) async {
    final f = File('${(await _root()).path}/routing_$name.json');
    f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }
}

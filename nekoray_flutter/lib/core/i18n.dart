// Simple i18n loader — reads JSON string maps bundled as assets.
//
// The files must be declared under `flutter: assets:` in pubspec.yaml.
// They previously were not, so `rootBundle.loadString` failed in release
// builds and every lookup silently fell back to the raw key.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

const supportedLocales = ['zh', 'en'];

final localeProvider = StateProvider<String>((ref) => 'zh');

final i18nProvider = FutureProvider<Map<String, String>>((ref) async {
  return I18n.load(ref.watch(localeProvider));
});

class I18n {
  static Map<String, String> _strings = {};
  static String _currentLocale = 'zh';

  /// Set when the bundle could not be read, so the UI can say so rather than
  /// rendering raw keys with no explanation.
  static String? loadError;

  static String get currentLocale => _currentLocale;

  static Future<Map<String, String>> load(String locale) async {
    final target = supportedLocales.contains(locale) ? locale : 'zh';
    _currentLocale = target;
    try {
      final raw = await rootBundle.loadString('assets/l10n/app_$target.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _strings = map.map((k, v) => MapEntry(k, v.toString()));
      loadError = null;
    } catch (e) {
      _strings = {};
      loadError = 'Failed to load translations for "$target": $e';
    }
    return _strings;
  }

  /// Looks up [key], substituting `{name}` placeholders from [args].
  static String t(String key, [Map<String, String>? args]) {
    var s = _strings[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }
}

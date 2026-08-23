// Simple i18n loader — reads JSON string maps.
//
// Task 15: internationalization. Uses simple JSON files instead of ARB/gen-l10n
// to keep the build simple (no codegen step). Supports zh (default) and en.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateProvider<String>((ref) => 'zh');

final i18nProvider = FutureProvider<Map<String, String>>((ref) async {
  final locale = ref.watch(localeProvider);
  return I18n.load(locale);
});

class I18n {
  static Map<String, String> _strings = {};
  static String _currentLocale = 'zh';

  static String get currentLocale => _currentLocale;

  static Future<Map<String, String>> load(String locale) async {
    _currentLocale = locale;
    try {
      final raw =
          await rootBundle.loadString('lib/l10n/app_$locale.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _strings = map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      _strings = {};
    }
    return _strings;
  }

  static String t(String key, [Map<String, String>? args]) {
    var s = _strings[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        s = s.replaceAll('{$k}', v);
      });
    }
    return s;
  }
}

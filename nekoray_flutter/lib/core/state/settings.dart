// Application settings: persisted to <appDir>/settings.json.
//
// These were previously plain in-memory StateProviders — every value was lost
// on restart and none of the toggles did anything. They are now backed by
// [LocalStore] and the ones that can be honoured on the current platform are
// applied by [SystemIntegration].

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';
import '../i18n.dart';
import '../system/system_integration.dart';

class AppSettings {
  final bool systemProxy;
  final bool tunMode;
  final bool autoStart;
  final bool minimizeToTray;
  final int corePort; // 0 = let the core pick an ephemeral port
  final int mixedPort;
  final String listenAddress;
  final String logLevel;
  final String locale;
  final String themeMode;
  final bool checkPreRelease;

  /// TUN / VPN advanced options. They always ship to the core (see
  /// `datastoreJson`) so the Go side never falls back to zero-values.
  final int vpnMtu;
  final int vpnStack; // 0 gvisor, 1 system, 2 mixed
  final bool vpnIpv6;
  final bool vpnStrictRoute;
  final bool fakeDns;

  /// 0 indigo, 1 teal, 2 purple, 3 orange. Only changes the seed color.
  final int accent;

  /// Subscription auto-refresh interval in hours (0 = off) + last run stamp.
  final int subAutoUpdateHours;
  final int subAutoUpdatedAt;

  const AppSettings({
    this.systemProxy = false,
    this.tunMode = false,
    this.autoStart = false,
    // Default OFF: with prevent-close + hide-to-tray as default, clicking X
    // never actually quit the app — the live tray process (and its core
    // child holding the install dir) made the folder undeletable, which
    // users reasonably report as "cannot delete after closing".
    this.minimizeToTray = false,
    this.corePort = 0,
    this.mixedPort = 2080,
    this.listenAddress = '127.0.0.1',
    this.logLevel = 'info',
    this.locale = 'zh',
    this.themeMode = 'system',
    this.checkPreRelease = false,
    this.vpnMtu = 1500,
    this.vpnStack = 0,
    this.vpnIpv6 = false,
    this.vpnStrictRoute = false,
    this.fakeDns = false,
    this.accent = 0,
    this.subAutoUpdateHours = 0,
    this.subAutoUpdatedAt = 0,
  });

  AppSettings copyWith({
    bool? systemProxy,
    bool? tunMode,
    bool? autoStart,
    bool? minimizeToTray,
    int? corePort,
    int? mixedPort,
    String? listenAddress,
    String? logLevel,
    String? locale,
    String? themeMode,
    bool? checkPreRelease,
    int? vpnMtu,
    int? vpnStack,
    bool? vpnIpv6,
    bool? vpnStrictRoute,
    bool? fakeDns,
    int? accent,
    int? subAutoUpdateHours,
    int? subAutoUpdatedAt,
  }) =>
      AppSettings(
        systemProxy: systemProxy ?? this.systemProxy,
        tunMode: tunMode ?? this.tunMode,
        autoStart: autoStart ?? this.autoStart,
        minimizeToTray: minimizeToTray ?? this.minimizeToTray,
        corePort: corePort ?? this.corePort,
        mixedPort: mixedPort ?? this.mixedPort,
        listenAddress: listenAddress ?? this.listenAddress,
        logLevel: logLevel ?? this.logLevel,
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        checkPreRelease: checkPreRelease ?? this.checkPreRelease,
        vpnMtu: vpnMtu ?? this.vpnMtu,
        vpnStack: vpnStack ?? this.vpnStack,
        vpnIpv6: vpnIpv6 ?? this.vpnIpv6,
        vpnStrictRoute: vpnStrictRoute ?? this.vpnStrictRoute,
        fakeDns: fakeDns ?? this.fakeDns,
        accent: accent ?? this.accent,
        subAutoUpdateHours: subAutoUpdateHours ?? this.subAutoUpdateHours,
        subAutoUpdatedAt: subAutoUpdatedAt ?? this.subAutoUpdatedAt,
      );

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        systemProxy: j['system_proxy'] == true,
        tunMode: j['tun_mode'] == true,
        autoStart: j['auto_start'] == true,
        minimizeToTray: j['minimize_to_tray'] == true,
        corePort: _int(j['core_port'], 0),
        mixedPort: _int(j['mixed_port'], 2080),
        listenAddress: (j['listen_address'] as String?) ?? '127.0.0.1',
        logLevel: (j['log_level'] as String?) ?? 'info',
        locale: (j['locale'] as String?) ?? 'zh',
        themeMode: (j['theme_mode'] as String?) ?? 'system',
        checkPreRelease: j['check_pre_release'] == true,
        vpnMtu: _int(j['vpn_mtu'], 1500),
        vpnStack: _int(j['vpn_stack'], 0),
        vpnIpv6: j['vpn_ipv6'] == true,
        vpnStrictRoute: j['vpn_strict_route'] == true,
        fakeDns: j['fake_dns'] == true,
        accent: _int(j['accent'], 0),
        subAutoUpdateHours: _int(j['sub_auto_update_hours'], 0),
        subAutoUpdatedAt: _int(j['sub_auto_updated_at'], 0),
      );

  Map<String, dynamic> toJson() => {
        'system_proxy': systemProxy,
        'tun_mode': tunMode,
        'auto_start': autoStart,
        'minimize_to_tray': minimizeToTray,
        'core_port': corePort,
        'mixed_port': mixedPort,
        'listen_address': listenAddress,
        'log_level': logLevel,
        'locale': locale,
        'theme_mode': themeMode,
        'check_pre_release': checkPreRelease,
        'vpn_mtu': vpnMtu,
        'vpn_stack': vpnStack,
        'vpn_ipv6': vpnIpv6,
        'vpn_strict_route': vpnStrictRoute,
        'fake_dns': fakeDns,
        'accent': accent,
        'sub_auto_update_hours': subAutoUpdateHours,
        'sub_auto_updated_at': subAutoUpdatedAt,
      };

  static int _int(Object? v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier(ref));

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AppSettings());

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final loaded = AppSettings.fromJson(await LocalStore.loadSettings());
      final locale = supportedLocales.contains(loaded.locale) ? loaded.locale : 'zh';
      state = loaded.copyWith(locale: locale);
      _ref.read(localeProvider.notifier).state = locale;
      await I18n.load(locale);
    } catch (_) {
      state = const AppSettings();
      _ref.read(localeProvider.notifier).state = 'zh';
      await I18n.load('zh');
    } finally {
      _loaded = true;
    }
  }

  Future<void> _persist(AppSettings next) async {
    await LocalStore.saveSettings(next.toJson());
    state = next;
  }

  Future<void> setMinimizeToTray(bool v) =>
      _persist(state.copyWith(minimizeToTray: v));

  Future<void> setMixedPort(int v) async {
    if (v < 1 || v > 65535) {
      throw ArgumentError('Port must be between 1 and 65535');
    }
    await _persist(state.copyWith(mixedPort: v));
  }

  Future<void> setCorePort(int v) async {
    if (v != 0 && (v < 1024 || v > 65535)) {
      throw ArgumentError('Core port must be 0 (auto) or between 1024 and 65535');
    }
    await _persist(state.copyWith(corePort: v));
  }

  Future<void> setListenAddress(String v) =>
      _persist(state.copyWith(listenAddress: v.trim()));

  Future<void> setLogLevel(String v) => _persist(state.copyWith(logLevel: v));

  Future<void> setLocale(String v) async {
    final locale = supportedLocales.contains(v) ? v : 'zh';
    await I18n.load(locale);
    _ref.read(localeProvider.notifier).state = locale;
    await _persist(state.copyWith(locale: locale));
  }

  Future<void> setThemeMode(String v) =>
      _persist(state.copyWith(themeMode: v));

  Future<void> setCheckPreRelease(bool v) =>
      _persist(state.copyWith(checkPreRelease: v));

  Future<void> setTunMode(bool v) => _persist(state.copyWith(tunMode: v));

  Future<void> setVpnMtu(int v) async {
    if (v < 576 || v > 9000) {
      throw ArgumentError('MTU must be between 576 and 9000');
    }
    await _persist(state.copyWith(vpnMtu: v));
  }

  Future<void> setVpnStack(int v) async {
    if (v < 0 || v > 2) {
      throw ArgumentError('Unknown TUN stack $v');
    }
    await _persist(state.copyWith(vpnStack: v));
  }

  Future<void> setVpnIpv6(bool v) => _persist(state.copyWith(vpnIpv6: v));

  Future<void> setVpnStrictRoute(bool v) =>
      _persist(state.copyWith(vpnStrictRoute: v));

  Future<void> setFakeDns(bool v) => _persist(state.copyWith(fakeDns: v));

  Future<void> setAccent(int v) async {
    if (v < 0 || v > 3) {
      throw ArgumentError('Unknown accent $v');
    }
    await _persist(state.copyWith(accent: v));
  }

  Future<void> setSubAutoUpdate(int hours) async {
    if (![0, 6, 12, 24].contains(hours)) {
      throw ArgumentError('Unsupported interval $hours');
    }
    await _persist(state.copyWith(subAutoUpdateHours: hours));
  }

  Future<void> markSubsAutoUpdated() async {
    await _persist(state.copyWith(
        subAutoUpdatedAt:
            DateTime.now().millisecondsSinceEpoch ~/ 1000));
  }

  /// Applies the OS-level auto-start entry, then records the outcome.
  Future<void> setAutoStart(bool v) async {
    await SystemIntegration.setAutoStart(v);
    await _persist(state.copyWith(autoStart: v));
  }

  /// Applies the OS-level proxy setting. Only stored if it actually took.
  Future<void> setSystemProxy(bool v) async {
    if (v) {
      await SystemIntegration.enableSystemProxy(
        host: state.listenAddress,
        port: state.mixedPort,
      );
    } else {
      await SystemIntegration.disableSystemProxy();
    }
    await _persist(state.copyWith(systemProxy: v));
  }
}

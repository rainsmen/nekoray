import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/grpc/grpc_provider.dart';
import 'core/i18n.dart';
import 'core/state/providers.dart';
import 'core/state/settings.dart';
import 'core/system/system_integration.dart';
import 'ui/pages/home/home_page.dart';
import 'ui/theme/app_theme.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class NekoRayApp extends ConsumerStatefulWidget {
  const NekoRayApp({super.key});

  @override
  ConsumerState<NekoRayApp> createState() => _NekoRayAppState();
}

class _NekoRayAppState extends ConsumerState<NekoRayApp>
    with WindowListener, TrayListener {
  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
    }
    // Settings must be loaded before anything reads them.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(settingsProvider.notifier).load();
      final locale = ref.read(settingsProvider).locale;
      await I18n.load(locale);
      if (mounted) setState(() {});
      if (_isDesktop) await _initTray();
    });
  }

  Future<void> _initTray() async {
    await _syncTrayMenu();
  }

  /// Rebuilds the tray menu + tooltip from live state: node name, running
  /// state, proxy/TUN switches, all localized. Called on init and whenever
  /// settings, connection, profiles or locale change.
  Future<void> _syncTrayMenu() async {
    if (!_isDesktop) return;
    try {
      final settings = ref.read(settingsProvider);
      final runningId = ref.read(connectedProfileProvider);
      final running = runningId > 0;
      final profiles =
          ref.read(profileListProvider).valueOrNull ?? const [];
      var nodeName = I18n.t('noActiveNode');
      for (final p in profiles) {
        if (p.id == runningId) {
          nodeName = p.name.isEmpty ? p.address : p.name;
          break;
        }
      }
      final on = I18n.t('enabled');
      final off = I18n.t('disabled');
      await trayManager.setToolTip(
          'NekoRay · $nodeName · ${running ? I18n.t('connected') : I18n.t('disconnected')}');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: I18n.t('trayShow')),
        MenuItem(key: 'show-node', label: nodeName),
        MenuItem.separator(),
        MenuItem(
            key: 'toggle-proxy',
            label:
                '${I18n.t('trayProxy')}: ${settings.systemProxy ? on : off}'),
        MenuItem(
            key: 'toggle-tun',
            label: '${I18n.t('trayTun')}: ${settings.tunMode ? on : off}'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: I18n.t('trayQuit')),
      ]));
    } catch (_) {
      // A missing tray (headless session, no appindicator) is not fatal.
    }
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Always stop the core: leaving an orphaned proxy running after the window
    // closes would keep the user's traffic redirected with no visible owner.
    if (ref.read(settingsProvider).minimizeToTray) {
      await windowManager.hide();
      return;
    }
    await _quit();
  }

  @override
  void onTrayIconMouseDown() => windowManager.show();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final notifier = ref.read(settingsProvider.notifier);
    switch (menuItem.key) {
      case 'show':
      case 'show-node':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'toggle-proxy':
        try {
          await notifier.setSystemProxy(!ref.read(settingsProvider).systemProxy);
        } catch (_) {}
        await _syncTrayMenu();
        break;
      case 'toggle-tun':
        try {
          await notifier.setTunMode(!ref.read(settingsProvider).tunMode);
        } catch (_) {}
        await _syncTrayMenu();
        break;
      case 'quit':
        await _quit();
        break;
    }
  }

  Future<void> _quit() async {
    // Every step is time-boxed: a hung core stop used to leave the GUI
    // half-dead (window gone, core orphaned, install folder locked) with no
    // way for the user to recover except Task Manager.
    try {
      if (ref.read(settingsProvider).systemProxy) {
        await SystemIntegration.disableSystemProxy()
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Ignore cleanup error on exit
    }
    try {
      await disconnectFromCore(ref).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Shutting down anyway; make one last attempt to reap the core so it
      // does not linger with handles inside the install folder.
      try {
        await ref
            .read(coreProcessProvider)
            .stop()
            .timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
    if (_isDesktop) {
      try {
        await trayManager.destroy();
      } catch (_) {}
      try {
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      } catch (_) {}
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the tray in sync without polling: any relevant change rebuilds it.
    ref.listen(settingsProvider, (_, __) => _syncTrayMenu());
    ref.listen(connectedProfileProvider, (_, __) => _syncTrayMenu());
    ref.listen(profileListProvider, (_, __) => _syncTrayMenu());
    ref.listen(localeProvider, (_, __) => _syncTrayMenu());
    final settings = ref.watch(settingsProvider);
    final themeMode = switch (settings.themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'NekoRay',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.locale),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(accent: settings.accent),
      darkTheme: AppTheme.dark(accent: settings.accent),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}

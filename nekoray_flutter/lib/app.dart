import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/grpc/grpc_provider.dart';
import 'core/i18n.dart';
import 'core/state/settings.dart';
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
    try {
      await trayManager.setToolTip('NekoRay');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Show'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
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
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'quit':
        await _quit();
        break;
    }
  }

  Future<void> _quit() async {
    try {
      await disconnectFromCore(ref);
    } catch (_) {
      // Shutting down anyway.
    }
    if (_isDesktop) {
      try {
        await trayManager.destroy();
      } catch (_) {}
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = switch (settings.themeMode) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'NekoRay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}

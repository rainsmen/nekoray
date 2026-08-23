// NekoRay Flutter client entry point.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  // Required before touching any platform channel (path_provider, window
  // manager, clipboard). Its absence previously made desktop features fail in
  // ways that only showed up at runtime.
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(820, 560),
      center: true,
      title: 'NekoRay',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Intercept close so the app can hide to the tray instead of quitting,
    // and so the core child process is always stopped on a real exit.
    await windowManager.setPreventClose(true);
  }

  runApp(const ProviderScope(child: NekoRayApp()));
}

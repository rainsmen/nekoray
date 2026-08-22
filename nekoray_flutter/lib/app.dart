import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/pages/home/home_page.dart';
import 'ui/theme/app_theme.dart';

class NekoRayApp extends ConsumerWidget {
  const NekoRayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NekoRay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomePage(),
    );
  }
}

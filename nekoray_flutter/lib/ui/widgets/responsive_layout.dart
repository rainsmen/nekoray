// Responsive layout helper for mobile vs desktop.
//
// Phase 3 task 22: adapts the UI for phone screens. On mobile, the
// NavigationRail becomes a bottom NavigationBar; the profile list becomes
// a single-column layout.

import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget desktop;
  final Widget mobile;

  const ResponsiveLayout({
    super.key,
    required this.desktop,
    required this.mobile,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 700;

  @override
  Widget build(BuildContext context) {
    return isMobile(context) ? mobile : desktop;
  }
}

/// Mobile bottom navigation bar as an alternative to the desktop NavigationRail.
class MobileNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MobileNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const items = [
    (Icons.list, 'Profiles'),
    (Icons.route, 'Routing'),
    (Icons.dns, 'DNS'),
    (Icons.device_hub, 'Connections'),
    (Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: items
          .map((e) => NavigationDestination(
                icon: Icon(e.$1),
                label: e.$2,
              ))
          .toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/proxy_card.dart';
import 'widgets/status_bar.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase-2 MVP scaffold: node list + status bar.
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          // Left navigation rail
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (i) {},
            labelType: NavigationRailLabelType.selected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.public, size: 32),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.list), label: Text('Profiles')),
              NavigationRailDestination(icon: Icon(Icons.route), label: Text('Routing')),
              NavigationRailDestination(icon: Icon(Icons.dns), label: Text('DNS')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Search bar + actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search profiles...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    ],
                  ),
                ),
                // Profile list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: const [
                      ProxyCard(name: 'Example Node', type: 'VMess', address: '1.2.3.4:443', latency: 120),
                      ProxyCard(name: 'Example Node 2', type: 'Trojan', address: '5.6.7.8:443', latency: 200),
                    ],
                  ),
                ),
                const StatusBar(connected: false, up: 0, down: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

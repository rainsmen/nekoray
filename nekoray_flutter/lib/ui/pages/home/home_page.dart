// Home page — main UI with navigation rail, profile list, and status bar.
//
// Task 10: node list with real data from LocalStore
// Task 12: navigation to routing/DNS/settings pages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/providers.dart';
import '../../pages/connections/connections_page.dart';
import '../../pages/dns/dns_page.dart';
import '../../pages/profile/profile_edit_dialog.dart';
import '../../pages/routing/routing_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../widgets/proxy_card.dart';
import '../../widgets/status_bar.dart';

enum HomePageTab { profiles, routing, dns, connections, settings }

final homeTabProvider = StateProvider<HomePageTab>((ref) => HomePageTab.profiles);

/// Currently connected profile ID (0 = disconnected).
final connectedProfileProvider = StateProvider<int>((ref) => 0);

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Load data on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileListProvider.notifier).load();
      ref.read(groupListProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(homeTabProvider);
    return Scaffold(
      body: Row(
        children: [
          // Navigation rail
          NavigationRail(
            selectedIndex: tab.index,
            onDestinationSelected: (i) =>
                ref.read(homeTabProvider.notifier).state = HomePageTab.values[i],
            labelType: NavigationRailLabelType.selected,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.public, size: 32),
            ),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.list_outlined), label: Text('Profiles')),
              NavigationRailDestination(
                  icon: Icon(Icons.route_outlined), label: Text('Routing')),
              NavigationRailDestination(
                  icon: Icon(Icons.dns_outlined), label: Text('DNS')),
              NavigationRailDestination(
                  icon: Icon(Icons.device_hub_outlined),
                  label: Text('Connections')),
              NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: Text('Settings')),
            ],
          ),
          VerticalDivider(
              width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          // Main content
          Expanded(child: _buildContent(tab)),
        ],
      ),
    );
  }

  Widget _buildContent(HomePageTab tab) {
    switch (tab) {
      case HomePageTab.profiles:
        return const _ProfilesTab();
      case HomePageTab.routing:
        return const RoutingPage();
      case HomePageTab.dns:
        return const DnsPage();
      case HomePageTab.connections:
        return const ConnectionsPage();
      case HomePageTab.settings:
        return const SettingsPage();
    }
  }
}

class _ProfilesTab extends ConsumerWidget {
  const _ProfilesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(filteredProfilesProvider);
    final connectedId = ref.watch(connectedProfileProvider);

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search profiles...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      ref.read(searchQueryProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Profile',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const ProfileEditDialog(),
                ),
              ),
            ],
          ),
        ),
        // Profile list
        Expanded(
          child: profiles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 48),
                      SizedBox(height: 8),
                      Text('No profiles yet. Click + to add one.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: profiles.length,
                  itemBuilder: (context, i) {
                    final p = profiles[i];
                    return ProxyCard(
                      name: p.name.isEmpty ? p.address : p.name,
                      type: p.type,
                      address: p.address,
                      latency: p.latency,
                      connected: connectedId == p.id,
                      onTap: () => _showProfileActions(context, ref, p),
                    );
                  },
                ),
        ),
        StatusBar(
          connected: connectedId != 0,
          up: 0,
          down: 0,
        ),
      ],
    );
  }

  void _showProfileActions(
      BuildContext context, WidgetRef ref, dynamic profile) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Start'),
              onTap: () {
                ref.read(connectedProfileProvider.notifier).state = profile.id;
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => ProfileEditDialog(existing: profile),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(profileListProvider.notifier).delete(profile.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

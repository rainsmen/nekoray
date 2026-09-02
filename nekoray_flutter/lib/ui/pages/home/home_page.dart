// Home page — navigation rail, dashboard, profile list, status bar.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/generated/libcore.pb.dart';
import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';
import '../../../core/models/profile.dart';
import '../../../core/state/providers.dart';
import '../../../core/state/settings.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/system/system_integration.dart';
import '../../pages/connections/connections_page.dart';
import '../../pages/dns/dns_page.dart';
import '../../pages/logs/logs_page.dart';
import '../../pages/profile/profile_edit_dialog.dart';
import '../../pages/routing/routing_page.dart';
import '../../pages/settings/settings_page.dart';
import '../../widgets/proxy_card.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/status_bar.dart';

enum HomePageTab { dashboard, profiles, routing, dns, logs, settings }

final homeTabProvider = StateProvider<HomePageTab>((ref) => HomePageTab.dashboard);

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(profileListProvider.notifier).load();
    await ref.read(groupListProvider.notifier).load();

    if (!ref.read(settingsProvider.notifier).isLoaded) {
      await ref.read(settingsProvider.notifier).load();
    }

    final error = await connectToCore(
      ref,
      requestedPort: ref.read(settingsProvider).corePort,
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not start the proxy core: $error'),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 8),
      ));
    }

    final corrupt = ref.read(profileListProvider.notifier).corruptFiles;
    if (corrupt.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${corrupt.length} profile file(s) could not be read and were skipped'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    final tab = ref.watch(homeTabProvider);
    void select(int i) =>
        ref.read(homeTabProvider.notifier).state = HomePageTab.values[i];

    if (ResponsiveLayout.isMobile(context)) {
      return Scaffold(
        body: _buildContent(tab),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: select,
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined), label: I18n.t('dashboard')),
            NavigationDestination(
                icon: const Icon(Icons.list_outlined), label: I18n.t('profiles')),
            NavigationDestination(
                icon: const Icon(Icons.alt_route), label: I18n.t('routing')),
            NavigationDestination(
                icon: const Icon(Icons.dns_outlined), label: I18n.t('dns')),
            NavigationDestination(
                icon: const Icon(Icons.article_outlined), label: I18n.t('logs')),
            NavigationDestination(
                icon: const Icon(Icons.settings_outlined), label: I18n.t('settings')),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: tab.index,
            onDestinationSelected: select,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.public, size: 32),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: Text(I18n.t('dashboard')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.list_outlined),
                selectedIcon: const Icon(Icons.list),
                label: Text(I18n.t('profiles')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.alt_route),
                selectedIcon: const Icon(Icons.alt_route),
                label: Text(I18n.t('routing')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.dns_outlined),
                selectedIcon: const Icon(Icons.dns),
                label: Text(I18n.t('dns')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.article_outlined),
                selectedIcon: const Icon(Icons.article),
                label: Text(I18n.t('logs')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(I18n.t('settings')),
              ),
            ],
          ),
          VerticalDivider(
              width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(child: _buildContent(tab)),
        ],
      ),
    );
  }

  Widget _buildContent(HomePageTab tab) {
    switch (tab) {
      case HomePageTab.dashboard:
        return const ConnectionsPage();
      case HomePageTab.profiles:
        return const _ProfilesTab();
      case HomePageTab.routing:
        return const RoutingPage();
      case HomePageTab.dns:
        return const DnsPage();
      case HomePageTab.logs:
        return const LogsPage();
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
    final connection = ref.watch(coreConnectionProvider);
    final traffic = ref.watch(trafficHistoryProvider);
    final latest = traffic.isEmpty ? null : traffic.last;

    return Column(
      children: [
        if (connection.state == CoreConnectionState.failed)
          _CoreBanner(error: connection.error ?? 'unknown error'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: I18n.t('searchProfiles'),
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
                tooltip: I18n.t('addProfile'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ProfileEditDialog(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.content_paste_go),
                tooltip: I18n.t('import'),
                onPressed: () => _importFromClipboard(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.rss_feed),
                tooltip: 'Add Subscription',
                onPressed: () => _addSubscription(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 48),
                      const SizedBox(height: 8),
                      Text(I18n.t('noProfiles')),
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
          up: latest?.up ?? 0,
          down: latest?.down ?? 0,
        ),
      ],
    );
  }

  Future<void> _importFromClipboard(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final connectError = await ensureConnected(ref);
    if (connectError != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Core unavailable: $connectError'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final client = ref.read(grpcClientProvider);
    final err =
        await ref.read(profileListProvider.notifier).importFromClipboard(client);
    messenger.showSnackBar(err == null
        ? const SnackBar(content: Text('Imported nodes from clipboard'))
        : SnackBar(
            content: Text('Import failed: $err'), backgroundColor: Colors.red));
  }

  Future<void> _addSubscription(BuildContext context, WidgetRef ref) async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Subscription Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                  labelText: 'Subscription URL', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(I18n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(I18n.t('import'))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final connectError = await ensureConnected(ref);
    if (connectError != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('Core unavailable: $connectError'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final client = ref.read(grpcClientProvider);
    final err = await ref.read(profileListProvider.notifier).importSubscription(
          urlCtrl.text.trim(),
          nameCtrl.text.trim(),
          client,
        );
    messenger.showSnackBar(err == null
        ? const SnackBar(content: Text('Subscription imported'))
        : SnackBar(content: Text(err), backgroundColor: Colors.red));
  }

  void _showProfileActions(
      BuildContext context, WidgetRef ref, ProxyEntity profile) {
    final connectedId = ref.read(connectedProfileProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (connectedId == profile.id)
              ListTile(
                leading: const Icon(Icons.stop, color: Colors.red),
                title: Text(I18n.t('stop'), style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _stop(context, ref);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: Text(I18n.t('start')),
                onTap: () {
                  Navigator.pop(ctx);
                  _start(context, ref, profile);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(I18n.t('edit')),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: context,
                  builder: (_) => ProfileEditDialog(existing: profile),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(I18n.t('delete'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, profile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ProxyEntity profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('confirmDelete')),
        content: Text(profile.name.isEmpty ? profile.address : profile.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(I18n.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t('delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(profileListProvider.notifier).delete(profile.id);
    }
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (ref.read(settingsProvider).systemProxy) {
        try {
          await SystemIntegration.disableSystemProxy();
        } catch (_) {}
      }
      await ref.read(grpcClientProvider).stopCore();
      ref.read(connectedProfileProvider.notifier).state = 0;
      ref.read(coreLogProvider.notifier).add('[INFO] Proxy stopped');
      messenger.showSnackBar(SnackBar(content: Text(I18n.t('stop'))));
    } catch (e) {
      ref.read(coreLogProvider.notifier).add('[ERROR] Failed to stop proxy: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('${I18n.t("stop")} failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _start(
      BuildContext context, WidgetRef ref, ProxyEntity profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);
    final profileName = profile.name.isEmpty ? profile.address : profile.name;

    try {
      ref.read(coreLogProvider.notifier).add('[INFO] Starting proxy for node: $profileName (${profile.type})');
      final connectError =
          await ensureConnected(ref, requestedPort: settings.corePort);
      if (connectError != null) {
        throw Exception(connectError);
      }
      final client = ref.read(grpcClientProvider);

      await client.stopCore();
      ref.read(connectedProfileProvider.notifier).state = 0;

      final routingRaw = await LocalStore.loadRouting('default') ?? {};
      final routing = RoutingConfig.fromJson(routingRaw);
      final grpcRouting = toGrpcRouting(routing);

      final datastore = {
        'inbound_socks_port': settings.mixedPort,
        'inbound_address': settings.listenAddress,
        'spmode_vpn': settings.tunMode,
        'vpn_internal_tun': settings.tunMode,
        'spmode_system_proxy': settings.systemProxy,
        'log_level': settings.logLevel,
      };

      final groups = ref.read(groupListProvider).valueOrNull ?? const [];
      final activeGroup = groups.firstWhere(
        (g) => g.id == profile.gid,
        orElse: () => ProfileGroup(id: 0),
      );

      final resp = await client.buildConfig(BuildConfigReq(
        profileJson: utf8.encode(jsonEncode(profile.toJson())),
        groupJson: utf8.encode(jsonEncode(activeGroup.toJson())),
        routingJson: utf8.encode(jsonEncode(grpcRouting)),
        datastoreJson: utf8.encode(jsonEncode(datastore)),
        forTest: false,
        forExport: false,
      ));
      if (resp.error.isNotEmpty) throw Exception(resp.error);

      final startResp =
          await client.startCore(resp.coreConfig, enableConnections: true);
      if (startResp.error.isNotEmpty) throw Exception(startResp.error);

      if (settings.systemProxy) {
        try {
          await SystemIntegration.enableSystemProxy(
            host: settings.listenAddress,
            port: settings.mixedPort,
          );
        } catch (e) {
          ref.read(coreLogProvider.notifier).add(
              '[WARN] Could not enable system proxy: $e');
        }
      }

      ref.read(connectedProfileProvider.notifier).state = profile.id;
      ref.read(coreLogProvider.notifier).add('[INFO] Proxy successfully started for $profileName');
      messenger.showSnackBar(SnackBar(
          content: Text('${I18n.t("connected")}: $profileName')));
    } catch (e) {
      ref.read(connectedProfileProvider.notifier).state = 0;
      ref.read(coreLogProvider.notifier).add('[ERROR] Failed to start $profileName: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('${I18n.t("start")} failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

class _CoreBanner extends ConsumerWidget {
  final String error;
  const _CoreBanner({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: scheme.errorContainer,
      leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
      content: Text(
        'Proxy core is not running: $error',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
      actions: [
        TextButton(
          onPressed: () => connectToCore(
            ref,
            requestedPort: ref.read(settingsProvider).corePort,
          ),
          child: Text(I18n.t('retry')),
        ),
      ],
    );
  }
}

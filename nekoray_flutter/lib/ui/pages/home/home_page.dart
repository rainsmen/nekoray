// Home page — navigation rail, dashboard, profile list, status bar.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Dashboard-selected profile ID (0 = none yet).
///
/// Selection and running state are deliberately separate: picking another
/// node while stopped must NOT start it — it only changes what the power
/// button will start next. While running, picking another node hot-switches.
final selectedProfileProvider = StateProvider<int>((ref) => 0);

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
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.public,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
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

class _ProfilesTab extends ConsumerStatefulWidget {
  const _ProfilesTab();

  @override
  ConsumerState<_ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends ConsumerState<_ProfilesTab> {
  /// Profile ids currently being latency-tested (drives per-row spinners).
  final Set<int> _testing = {};
  bool _testingAll = false;
  bool _sortByLatency = false;

  /// Multi-select state for batch delete / move / test.
  bool _selecting = false;
  final Set<int> _selected = {};
  bool _refreshingSubs = false;

  @override
  Widget build(BuildContext context) {
    final allProfiles = ref.watch(filteredProfilesProvider);
    // Untested nodes (latency <= 0) sink to the bottom when sorting.
    final profiles = _sortByLatency
        ? (List.of(allProfiles)
          ..sort((a, b) {
            if (a.latency <= 0 && b.latency <= 0) return 0;
            if (a.latency <= 0) return 1;
            if (b.latency <= 0) return -1;
            return a.latency.compareTo(b.latency);
          }))
        : allProfiles;
    final groups = ref.watch(groupListProvider).valueOrNull ?? const [];
    final groupNames = {for (final g in groups) g.id: g.name};
    final selectedGroup = ref.watch(selectedGroupProvider);
    final connectedId = ref.watch(connectedProfileProvider);
    final connection = ref.watch(coreConnectionProvider);
    final traffic = ref.watch(trafficHistoryProvider);
    final latest = traffic.isEmpty ? null : traffic.last;

    return Column(
      children: [
        if (connection.state == CoreConnectionState.failed)
          _CoreBanner(error: connection.error ?? 'unknown error'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                tooltip: I18n.t('addSubscription'),
                onPressed: () => _addSubscription(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: I18n.t('refreshAllSubs'),
                onPressed:
                    _refreshingSubs ? null : () => _refreshAllSubs(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedGroup,
                  decoration: InputDecoration(
                    labelText: I18n.t('group'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 0, child: Text(I18n.t('allGroups'))),
                    for (final g in groups)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text(
                          g.name.isEmpty ? '#${g.id}' : g.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => ref
                      .read(selectedGroupProvider.notifier)
                      .state = v ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                    _selecting ? Icons.deselect_outlined : Icons.select_all),
                tooltip: I18n.t('selectNodes'),
                color: _selecting
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: () => setState(() {
                  _selecting = !_selecting;
                  _selected.clear();
                }),
              ),
              IconButton(
                icon: Icon(_sortByLatency
                    ? Icons.sort_by_alpha
                    : Icons.speed_outlined),
                tooltip: I18n.t('sortByLatency'),
                color: _sortByLatency
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: () =>
                    setState(() => _sortByLatency = !_sortByLatency),
              ),
              FilledButton.tonalIcon(
                icon: _testingAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_outlined, size: 18),
                label: Text(_testingAll
                    ? '${I18n.t('testing')} ${_testing.length}/${profiles.length}'
                    : I18n.t('testAllNodes')),
                onPressed: (_testingAll || profiles.isEmpty)
                    ? null
                    : () => _testAll(profiles),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                    final isSelected = _selected.contains(p.id);
                    return ProxyCard(
                      name: p.name,
                      type: p.type,
                      address: p.address,
                      latency: p.latency,
                      connected: connectedId == p.id,
                      testing: _testing.contains(p.id),
                      groupName: groupNames[p.gid],
                      selected: isSelected,
                      onTap: _selecting
                          ? () => _toggleSelect(p.id)
                          : () => _showProfileActions(context, ref, p),
                      onLongPress: _selecting
                          ? null
                          : () => setState(() {
                                _selecting = true;
                                _selected.add(p.id);
                              }),
                      onTest: (_selecting ||
                              _testing.contains(p.id) ||
                              _testingAll)
                          ? null
                          : () => _testOne(p),
                    );
                  },
                ),
        ),
        if (_selecting)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.secondaryContainer,
              border: Border(
                  top: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant)),
            ),
            child: Row(
              children: [
                Text(
                    '${I18n.t('selectedCount')}: ${_selected.length}'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bolt_outlined),
                  tooltip: I18n.t('testSelected'),
                  onPressed: _selected.isEmpty ? null : _testSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outlined),
                  tooltip: I18n.t('moveGroup'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _moveSelected(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  tooltip: I18n.t('deleteSelected'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => _deleteSelected(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: I18n.t('cancel'),
                  onPressed: () => setState(() {
                    _selecting = false;
                    _selected.clear();
                  }),
                ),
              ],
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
              leading: const Icon(Icons.speed_outlined),
              title: Text(I18n.t('testLatency')),
              onTap: () {
                Navigator.pop(ctx);
                _testOne(profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: Text(I18n.t('shareLink')),
              onTap: () {
                Navigator.pop(ctx);
                _shareLink(context, ref, profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(I18n.t('rename')),
              subtitle: Text(
                profile.name.isEmpty ? profile.address : profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref, profile);
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

  /// Renames a node remark without touching any other bean field.
  Future<void> _rename(
      BuildContext context, WidgetRef ref, ProxyEntity profile) async {
    final ctrl = TextEditingController(text: profile.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('rename')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(
            labelText: I18n.t('nodeName'),
            hintText: profile.address,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(I18n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(I18n.t('save'))),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty || name == profile.name) return;
    final bean = Map<String, dynamic>.from(profile.bean)..['name'] = name;
    await ref
        .read(profileListProvider.notifier)
        .update(profile.copyWith(bean: bean));
  }

  /// Tests one node and persists its latency. Failures keep the previous
  /// value and are reported via snackbar + core log.
  Future<void> _testOne(ProxyEntity profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _testOneSilent(profile);
    if (!mounted) return;
    final label =
        profile.name.isEmpty ? profile.address : profile.name;
    messenger.showSnackBar(ok
        ? SnackBar(
            content: Text(
                '$label: ${ref.read(profileListProvider).valueOrNull?.firstWhere((e) => e.id == profile.id, orElse: () => profile).latency ?? 0}ms'))
        : SnackBar(
            content: Text('${I18n.t("testLatency")} $label: ${I18n.t("testFailed")}'),
            backgroundColor: Colors.red,
          ));
  }

  /// Returns true when the probe succeeded and the latency was persisted.
  Future<bool> _testOneSilent(ProxyEntity profile) async {
    if (_testing.contains(profile.id)) return false;
    setState(() => _testing.add(profile.id));
    try {
      final ms = await probeNodeLatency(ref, profile);
      await ref
          .read(profileListProvider.notifier)
          .update(profile.copyWith(latency: ms));
      return true;
    } catch (e) {
      ref.read(coreLogProvider.notifier).add(
          '[WARN] Latency test failed for ${profile.name.isEmpty ? profile.address : profile.name}: $e');
      return false;
    } finally {
      if (mounted) setState(() => _testing.remove(profile.id));
    }
  }

  /// Tests every listed node in small parallel batches so a large
  /// subscription does not take one timeout per node serially.
  Future<void> _testAll(List<ProxyEntity> profiles) async {
    if (_testingAll || profiles.isEmpty) return;
    setState(() => _testingAll = true);
    var ok = 0;
    try {
      for (var i = 0; i < profiles.length; i += 5) {
        final chunk = profiles.skip(i).take(5);
        final results =
            await Future.wait(chunk.map(_testOneSilent));
        ok += results.where((r) => r).length;
      }
    } finally {
      if (mounted) setState(() => _testingAll = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${I18n.t("testAllNodes")}: $ok/${profiles.length} ${I18n.t("testSuccess")}'),
    ));
  }

  void _toggleSelect(int id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  /// Copies a share link for [profile] to the clipboard.
  Future<void> _shareLink(
      BuildContext context, WidgetRef ref, ProxyEntity profile) async {
    final messenger = ScaffoldMessenger.of(context);
    final connectError = await ensureConnected(ref);
    if (connectError != null) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Core unavailable: $connectError'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    try {
      final resp = await ref.read(grpcClientProvider).generateShareLink(
            ShareLinkReq(
              profileJson: utf8.encode(jsonEncode(profile.toJson())),
              format: '',
            ),
          );
      if (resp.error.isNotEmpty) throw Exception(resp.error);
      await Clipboard.setData(ClipboardData(text: resp.link));
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(I18n.t('linkCopied'))));
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('Share failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Refreshes every group that has a subscription URL.
  Future<void> _refreshAllSubs() async {
    if (_refreshingSubs) return;
    final messenger = ScaffoldMessenger.of(context);
    final groups = (ref.read(groupListProvider).valueOrNull ?? const [])
        .where((g) => g.url.isNotEmpty)
        .toList();
    if (groups.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(I18n.t('noSubscriptions'))));
      return;
    }
    setState(() => _refreshingSubs = true);
    try {
      final connectError = await ensureConnected(ref);
      if (connectError != null) throw Exception(connectError);
      final client = ref.read(grpcClientProvider);
      final notifier = ref.read(profileListProvider.notifier);
      var ok = 0;
      final failed = <String>[];
      for (final g in groups) {
        final err = await notifier.refreshSubscription(g, client);
        if (err == null) {
          ok++;
        } else {
          failed.add('${g.name}: $err');
          ref
              .read(coreLogProvider.notifier)
              .add('[WARN] Subscription refresh failed for ${g.name}: $err');
        }
      }
      await ref.read(groupListProvider.notifier).load();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${I18n.t('subsRefreshed')}: $ok/${groups.length}'
            '${failed.isEmpty ? '' : ', ${failed.length} ${I18n.t('testFailed')}'}'),
        backgroundColor: failed.isEmpty ? null : Colors.orange,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _refreshingSubs = false);
    }
  }

  /// Tests every selected node sequentially to bound core pressure.
  Future<void> _testSelected() async {
    for (final id in _selected.toList()) {
      final list = ref.read(profileListProvider).valueOrNull ?? const [];
      final found = list.where((e) => e.id == id);
      if (found.isEmpty) continue;
      await _testOneSilent(found.first);
    }
  }

  /// Moves every selected node into the picked group.
  Future<void> _moveSelected(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupListProvider).valueOrNull ?? const [];
    final target = await showDialog<ProfileGroup>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(I18n.t('moveGroup')),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, ProfileGroup(id: 0)),
            child: Text(I18n.t('defaultGroup')),
          ),
          for (final g in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text(g.name.isEmpty ? '#${g.id}' : g.name),
            ),
        ],
      ),
    );
    if (target == null) return;
    final notifier = ref.read(profileListProvider.notifier);
    for (final id in _selected.toList()) {
      final list = ref.read(profileListProvider).valueOrNull ?? const [];
      final found = list.where((e) => e.id == id);
      if (found.isEmpty) continue;
      await notifier.update(found.first.copyWith(gid: target.id));
    }
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  /// Deletes every selected node after confirmation.
  Future<void> _deleteSelected(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('deleteSelected')),
        content: Text(
            '${I18n.t('selectedCount')}: ${_selected.length}'),
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
    if (ok != true) return;
    final notifier = ref.read(profileListProvider.notifier);
    for (final id in _selected.toList()) {
      await notifier.delete(id);
    }
    setState(() {
      _selecting = false;
      _selected.clear();
    });
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

      final datastore = datastoreJson(settings);

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
      ref.read(selectedProfileProvider.notifier).state = profile.id;
      ref.read(coreLogProvider.notifier).add('[INFO] Proxy successfully started for $profileName');
      messenger.showSnackBar(SnackBar(
          content: Text('${I18n.t("connected")}: $profileName')));
    } catch (e) {
      ref.read(connectedProfileProvider.notifier).state = 0;
      ref.read(coreLogProvider.notifier).add('[ERROR] Failed to start $profileName: $e');
      var detail = '$e';
      if (settings.tunMode) {
        // TUN failures are almost always privilege or stack/MTU issues.
        // Surface the raw core error plus an actionable hint instead of a
        // bare "start failed".
        final elevated = await SystemIntegration.isElevated();
        final hint = elevated
            ? I18n.t('tunStartHintConfig')
            : I18n.t('tunStartHintPrivilege');
        ref.read(coreLogProvider.notifier).add('[HINT] TUN: $hint');
        detail = '$detail\n$hint';
      }
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${I18n.t("start")} failed: $detail'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}

/// Datastore payload shared by the start and latency-test paths.
///
/// The TUN keys must always be present: omitting them leaves Go zero-values
/// (notably MTU 0) in the core, which breaks TUN inbound creation.
Map<String, dynamic> datastoreJson(AppSettings settings) => {
      'inbound_socks_port': settings.mixedPort,
      'inbound_address': settings.listenAddress,
      'spmode_vpn': settings.tunMode,
      'vpn_internal_tun': settings.tunMode,
      'vpn_mtu': settings.vpnMtu,
      'vpn_implementation': settings.vpnStack,
      'vpn_strict_route': settings.vpnStrictRoute,
      'vpn_ipv6': settings.vpnIpv6,
      'fake_dns': settings.fakeDns,
      'spmode_system_proxy': settings.systemProxy,
      'log_level': settings.logLevel,
    };

/// Builds a throwaway sing-box config for [profile] and measures HTTP
/// latency through it with a core-side UrlTest. Returns milliseconds.
///
/// The probe never disturbs the running instance: [forTest] configs skip
/// inbound binding, and the UrlTest box is closed immediately afterwards.
Future<int> probeNodeLatency(WidgetRef ref, ProxyEntity profile) async {
  final connectError = await ensureConnected(ref);
  if (connectError != null) {
    throw Exception('Core unavailable: $connectError');
  }
  final client = ref.read(grpcClientProvider);
  final settings = ref.read(settingsProvider);

  final routingRaw = await LocalStore.loadRouting('default') ?? {};
  final grpcRouting =
      toGrpcRouting(RoutingConfig.fromJson(routingRaw));

  final groups = ref.read(groupListProvider).valueOrNull ?? const [];
  final group = groups.firstWhere(
    (g) => g.id == profile.gid,
    orElse: () => ProfileGroup(id: 0),
  );

  final buildResp = await client.buildConfig(BuildConfigReq(
    profileJson: utf8.encode(jsonEncode(profile.toJson())),
    groupJson: utf8.encode(jsonEncode(group.toJson())),
    routingJson: utf8.encode(jsonEncode(grpcRouting)),
    datastoreJson: utf8.encode(jsonEncode(datastoreJson(settings))),
    forTest: true,
    forExport: false,
  ));
  if (buildResp.error.isNotEmpty) throw Exception(buildResp.error);

  final testResp = await client.test(TestReq(
    mode: TestMode.UrlTest,
    config: LoadConfigReq(coreConfig: buildResp.coreConfig),
    url: 'https://www.gstatic.com/generate_204',
    timeout: 8000,
  ));
  if (testResp.error.isNotEmpty) throw Exception(testResp.error);
  return testResp.ms;
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

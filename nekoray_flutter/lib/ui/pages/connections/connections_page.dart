// Connections page — Dashboard (armwall style)
// Features: Service Start/Stop control, Active Node Selector & Quick Switching,
// Real-time Traffic Graph & Speeds, Website Connectivity & Latency Testing.

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
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
import '../home/home_page.dart';
import '../routing/routing_page.dart';

/// One sample of throughput, in bytes per second.
class TrafficPoint {
  final DateTime time;
  final int up;
  final int down;
  TrafficPoint(this.time, this.up, this.down);
}

/// Rolling traffic history (last 60 samples ≈ 60 seconds).
final trafficHistoryProvider =
    StateNotifierProvider.autoDispose<TrafficHistoryNotifier, List<TrafficPoint>>(
  (ref) => TrafficHistoryNotifier(ref),
);

class TrafficHistoryNotifier extends StateNotifier<List<TrafficPoint>> {
  final Ref _ref;
  Timer? _timer;

  int? _lastUp;
  int? _lastDown;
  int _totalUp = 0;
  int _totalDown = 0;
  bool _polling = false;

  int get totalUp => _totalUp;
  int get totalDown => _totalDown;

  TrafficHistoryNotifier(this._ref) : super(const []) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling) return;
    final client = _ref.read(grpcClientProvider);
    if (!client.isConnected) {
      _lastUp = null;
      _lastDown = null;
      return;
    }

    _polling = true;
    try {
      final upResp = await client.queryStats('proxy', 'uplink');
      final downResp = await client.queryStats('proxy', 'downlink');
      final up = upResp.traffic.toInt();
      final down = downResp.traffic.toInt();

      _totalUp = up;
      _totalDown = down;

      final prevUp = _lastUp;
      final prevDown = _lastDown;
      _lastUp = up;
      _lastDown = down;
      if (prevUp == null || prevDown == null) return;

      final point = TrafficPoint(
        DateTime.now(),
        (up - prevUp).clamp(0, 1 << 62),
        (down - prevDown).clamp(0, 1 << 62),
      );
      final next = [...state, point];
      state = next.length > 60 ? next.sublist(next.length - 60) : next;
    } catch (_) {
      // Ignore transient query failures
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum SiteCategory { global, domestic }
enum TestStatus { untested, testing, success, failed }

class SiteTarget {
  final String id;
  final String name;
  final String url;
  final SiteCategory category;
  final IconData icon;

  const SiteTarget({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.icon,
  });
}

class SiteTestResult {
  final TestStatus status;
  final int? httpCode;
  final int? latencyMs;
  final String? error;

  const SiteTestResult({
    this.status = TestStatus.untested,
    this.httpCode,
    this.latencyMs,
    this.error,
  });

  SiteTestResult copyWith({
    TestStatus? status,
    int? httpCode,
    int? latencyMs,
    String? error,
  }) =>
      SiteTestResult(
        status: status ?? this.status,
        httpCode: httpCode ?? this.httpCode,
        latencyMs: latencyMs ?? this.latencyMs,
        error: error ?? this.error,
      );
}

final defaultSites = <SiteTarget>[
  const SiteTarget(
    id: 'google',
    name: 'Google',
    url: 'https://www.google.com/generate_204',
    category: SiteCategory.global,
    icon: Icons.search,
  ),
  const SiteTarget(
    id: 'youtube',
    name: 'YouTube',
    url: 'https://www.youtube.com',
    category: SiteCategory.global,
    icon: Icons.play_circle_outline,
  ),
  const SiteTarget(
    id: 'github',
    name: 'GitHub',
    url: 'https://github.com',
    category: SiteCategory.global,
    icon: Icons.code,
  ),
  const SiteTarget(
    id: 'cloudflare',
    name: 'Cloudflare',
    url: 'https://1.1.1.1',
    category: SiteCategory.global,
    icon: Icons.cloud_outlined,
  ),
  const SiteTarget(
    id: 'chatgpt',
    name: 'OpenAI / ChatGPT',
    url: 'https://chat.openai.com',
    category: SiteCategory.global,
    icon: Icons.smart_toy_outlined,
  ),
  const SiteTarget(
    id: 'telegram',
    name: 'Telegram',
    url: 'https://t.me',
    category: SiteCategory.global,
    icon: Icons.send_outlined,
  ),
  const SiteTarget(
    id: 'wikipedia',
    name: 'Wikipedia',
    url: 'https://www.wikipedia.org',
    category: SiteCategory.global,
    icon: Icons.menu_book_outlined,
  ),
  const SiteTarget(
    id: 'baidu',
    name: 'Baidu',
    url: 'https://www.baidu.com',
    category: SiteCategory.domestic,
    icon: Icons.language,
  ),
  const SiteTarget(
    id: 'bilibili',
    name: 'Bilibili',
    url: 'https://www.bilibili.com',
    category: SiteCategory.domestic,
    icon: Icons.tv,
  ),
  const SiteTarget(
    id: 'taobao',
    name: 'Taobao',
    url: 'https://www.taobao.com',
    category: SiteCategory.domestic,
    icon: Icons.shopping_bag_outlined,
  ),
  const SiteTarget(
    id: 'qq',
    name: 'Tencent / QQ',
    url: 'https://www.qq.com',
    category: SiteCategory.domestic,
    icon: Icons.chat_bubble_outline,
  ),
];

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final Map<String, SiteTestResult> _results = {};
  bool _isTestingAll = false;
  bool _isStartingOrStopping = false;

  SiteTestResult _getResult(String id) =>
      _results[id] ?? const SiteTestResult();

  Future<void> _testSite(SiteTarget site) async {
    setState(() {
      _results[site.id] =
          _getResult(site.id).copyWith(status: TestStatus.testing);
    });

    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        validateStatus: (_) => true,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ));

      final resp = await dio.get(site.url);
      stopwatch.stop();

      if (mounted) {
        setState(() {
          _results[site.id] = SiteTestResult(
            status: TestStatus.success,
            httpCode: resp.statusCode,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        });
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _results[site.id] = SiteTestResult(
            status: TestStatus.failed,
            latencyMs: stopwatch.elapsedMilliseconds,
            error: e.toString(),
          );
        });
      }
    }
  }

  Future<void> _testAllSites() async {
    if (_isTestingAll) return;
    setState(() => _isTestingAll = true);
    try {
      await Future.wait(defaultSites.map(_testSite));
    } finally {
      if (mounted) {
        setState(() => _isTestingAll = false);
      }
    }
  }

  Future<void> _toggleService(ProxyEntity? activeProfile) async {
    final connectedId = ref.read(connectedProfileProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (connectedId > 0) {
      // Stop service
      setState(() => _isStartingOrStopping = true);
      try {
        await ref.read(grpcClientProvider).stopCore();
        ref.read(connectedProfileProvider.notifier).state = 0;
        ref.read(coreLogProvider.notifier).add('[INFO] Proxy stopped via Dashboard');
        messenger.showSnackBar(SnackBar(content: Text(I18n.t('stop'))));
      } catch (e) {
        ref.read(coreLogProvider.notifier).add('[ERROR] Failed to stop proxy: $e');
        messenger.showSnackBar(SnackBar(
          content: Text('${I18n.t("stop")} failed: $e'),
          backgroundColor: Colors.red,
        ));
      } finally {
        if (mounted) setState(() => _isStartingOrStopping = false);
      }
    } else {
      // Start service
      if (activeProfile == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(I18n.t('noActiveNode')),
          backgroundColor: Colors.orange,
        ));
        _openNodeSelector(context);
        return;
      }

      setState(() => _isStartingOrStopping = true);
      final settings = ref.read(settingsProvider);
      final profileName =
          activeProfile.name.isEmpty ? activeProfile.address : activeProfile.name;

      try {
        ref.read(coreLogProvider.notifier).add(
            '[INFO] Starting proxy for node: $profileName (${activeProfile.type})');
        final connectError =
            await ensureConnected(ref, requestedPort: settings.corePort);
        if (connectError != null) throw Exception(connectError);

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
          (g) => g.id == activeProfile.gid,
          orElse: () => ProfileGroup(id: 0),
        );

        final resp = await client.buildConfig(BuildConfigReq(
          profileJson: utf8.encode(jsonEncode(activeProfile.toJson())),
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

        ref.read(connectedProfileProvider.notifier).state = activeProfile.id;
        ref.read(coreLogProvider.notifier).add(
            '[INFO] Proxy successfully started for $profileName');
        messenger.showSnackBar(SnackBar(
            content: Text('${I18n.t("connected")}: $profileName')));
      } catch (e) {
        ref.read(connectedProfileProvider.notifier).state = 0;
        ref.read(coreLogProvider.notifier).add(
            '[ERROR] Failed to start $profileName: $e');
        messenger.showSnackBar(SnackBar(
          content: Text('${I18n.t("start")} failed: $e'),
          backgroundColor: Colors.red,
        ));
      } finally {
        if (mounted) setState(() => _isStartingOrStopping = false);
      }
    }
  }

  void _openNodeSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NodeSelectorSheet(
        onSelect: (selected) async {
          Navigator.pop(ctx);
          final isRunning = ref.read(connectedProfileProvider) > 0;
          ref.read(connectedProfileProvider.notifier).state = selected.id;
          if (isRunning) {
            // Hot switch node
            await _toggleService(selected);
          }
        },
      ),
    );
  }

  String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final history = ref.watch(trafficHistoryProvider);
    final connectedId = ref.watch(connectedProfileProvider);
    final isConnected = connectedId > 0;

    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final activeProfile = profiles.firstWhere(
      (p) => p.id == connectedId,
      orElse: () => profiles.isNotEmpty ? profiles.first : ProxyEntity(id: 0, type: ''),
    );
    final hasActiveNode = activeProfile.id > 0;

    final latestUp = history.isNotEmpty ? history.last.up : 0;
    final latestDown = history.isNotEmpty ? history.last.down : 0;

    final globalSites =
        defaultSites.where((s) => s.category == SiteCategory.global).toList();
    final domesticSites =
        defaultSites.where((s) => s.category == SiteCategory.domestic).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? (isDark ? Colors.green.shade900.withOpacity(0.4) : Colors.green.shade50)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isConnected ? Colors.green.shade600 : scheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green.shade500 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? I18n.t('connected') : I18n.t('disconnected'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(I18n.t('dashboard'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: I18n.t('testAll'),
            onPressed: _testAllSites,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Hero Service Control & Active Node Card
          Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isConnected
                    ? (isDark ? scheme.primary.withOpacity(0.5) : scheme.primary.withOpacity(0.3))
                    : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1)),
                width: isConnected ? 1.5 : 1,
              ),
            ),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Status Circle Indicator / Power button
                      GestureDetector(
                        onTap: _isStartingOrStopping
                            ? null
                            : () => _toggleService(hasActiveNode ? activeProfile : null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isConnected
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : LinearGradient(
                                    colors: isDark
                                        ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                                        : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                                  ),
                            boxShadow: isConnected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: _isStartingOrStopping
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.power_settings_new,
                                    size: 28,
                                    color: isConnected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Service state and toggle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected ? I18n.t('connected') : I18n.t('disconnected'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isConnected
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                    : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConnected
                                  ? '${I18n.t("systemProxy")}: ${ref.watch(settingsProvider).systemProxy ? I18n.t("enabled") : I18n.t("disabled")}'
                                  : I18n.t('serviceStatus'),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Big Start/Stop button
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: isConnected
                              ? Colors.red.shade600
                              : scheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isStartingOrStopping
                            ? null
                            : () => _toggleService(hasActiveNode ? activeProfile : null),
                        icon: Icon(
                          isConnected ? Icons.stop : Icons.play_arrow,
                          size: 18,
                        ),
                        label: Text(
                          isConnected ? I18n.t('stop') : I18n.t('start'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Active Node Card with Quick Switch
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openNodeSelector(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dns_outlined, size: 24, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (hasActiveNode && activeProfile.type.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          activeProfile.type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: scheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        hasActiveNode
                                            ? (activeProfile.name.isNotEmpty
                                                ? activeProfile.name
                                                : activeProfile.address)
                                            : I18n.t('noActiveNode'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasActiveNode && activeProfile.address.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    activeProfile.address,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _openNodeSelector(context),
                            child: Text(
                              I18n.t('switchNode'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Switches: System Proxy & Tun Mode
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            backgroundColor: ref.watch(settingsProvider).systemProxy
                                ? scheme.primary.withOpacity(0.1)
                                : null,
                          ),
                          icon: Icon(
                            Icons.public,
                            size: 16,
                            color: ref.watch(settingsProvider).systemProxy
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          label: Text(
                            '${I18n.t("systemProxy")}: ${ref.watch(settingsProvider).systemProxy ? I18n.t("enabled") : I18n.t("disabled")}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ref.watch(settingsProvider).systemProxy
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          onPressed: () {
                            final current = ref.read(settingsProvider).systemProxy;
                            ref.read(settingsProvider.notifier).setSystemProxy(!current);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            backgroundColor: ref.watch(settingsProvider).tunMode
                                ? scheme.primary.withOpacity(0.1)
                                : null,
                          ),
                          icon: Icon(
                            Icons.vpn_lock,
                            size: 16,
                            color: ref.watch(settingsProvider).tunMode
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          label: Text(
                            '${I18n.t("tunMode")}: ${ref.watch(settingsProvider).tunMode ? I18n.t("enabled") : I18n.t("disabled")}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ref.watch(settingsProvider).tunMode
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          onPressed: () {
                            final current = ref.read(settingsProvider).tunMode;
                            ref.read(settingsProvider.notifier).setTunMode(!current);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Real-Time Speeds & Traffic Graph
          Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        I18n.t('uploadSpeed') + ' / ' + I18n.t('downloadSpeed'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Upload Counter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.2)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.arrow_upward,
                                      size: 14, color: scheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    I18n.t('uploadSpeed'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSpeed(latestUp),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Download Counter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.2)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.arrow_downward,
                                      size: 14, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    I18n.t('downloadSpeed'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSpeed(latestDown),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 130,
                    child: _TrafficChart(history: history),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Website Connectivity & Speed Test
          Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.network_check, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        I18n.t('websiteTest'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        icon: _isTestingAll
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bolt, size: 16),
                        label: Text(
                          _isTestingAll ? I18n.t('testing') : I18n.t('testAll'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: _isTestingAll ? null : _testAllSites,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Global Sites
                  Text(
                    I18n.t('globalSites'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: globalSites
                        .map((site) => _buildSiteChip(site, scheme, isDark))
                        .toList(),
                  ),

                  const SizedBox(height: 16),

                  // Domestic Sites
                  Text(
                    I18n.t('domesticSites'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: domesticSites
                        .map((site) => _buildSiteChip(site, scheme, isDark))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteChip(SiteTarget site, ColorScheme scheme, bool isDark) {
    final result = _getResult(site.id);
    final isUntested = result.status == TestStatus.untested;
    final isTesting = result.status == TestStatus.testing;
    final isSuccess = result.status == TestStatus.success;

    final Color badgeColor;
    final String badgeText;

    if (isUntested) {
      badgeColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      badgeText = I18n.t('untested');
    } else if (isTesting) {
      badgeColor = scheme.primary;
      badgeText = I18n.t('testing');
    } else if (isSuccess) {
      final lat = result.latencyMs ?? 0;
      if (lat < 150) {
        badgeColor = isDark ? Colors.green.shade400 : Colors.green.shade700;
      } else if (lat < 400) {
        badgeColor = isDark ? Colors.amber.shade400 : Colors.amber.shade800;
      } else {
        badgeColor = isDark ? Colors.orange.shade400 : Colors.orange.shade800;
      }
      badgeText = '${lat}ms';
    } else {
      badgeColor = isDark ? Colors.red.shade400 : Colors.red.shade700;
      badgeText = 'FAIL';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isTesting ? null : () => _testSite(site),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(site.icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              site.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            if (isTesting)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrafficChart extends StatelessWidget {
  final List<TrafficPoint> history;
  const _TrafficChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          I18n.t('waitingForData'),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final upSpots = <FlSpot>[];
    final downSpots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      upSpots.add(FlSpot(i.toDouble(), history[i].up / 1024));
      downSpots.add(FlSpot(i.toDouble(), history[i].down / 1024));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (history.length - 1).toDouble().clamp(10, 60),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: upSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
          LineChartBarData(
            spots: downSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: Colors.blue.shade600,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade600.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick node selector bottom sheet
class _NodeSelectorSheet extends ConsumerStatefulWidget {
  final ValueChanged<ProxyEntity> onSelect;
  const _NodeSelectorSheet({required this.onSelect});

  @override
  ConsumerState<_NodeSelectorSheet> createState() => _NodeSelectorSheetState();
}

class _NodeSelectorSheetState extends ConsumerState<_NodeSelectorSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profileListProvider).valueOrNull ?? const [];
    final connectedId = ref.watch(connectedProfileProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = profiles.where((p) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.address.toLowerCase().contains(q) ||
          p.type.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, size: 22),
                const SizedBox(width: 8),
                Text(
                  I18n.t('switchNode'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: I18n.t('searchProfiles'),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        I18n.t('noProfiles'),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        final isSelected = p.id == connectedId;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.green.shade900 : Colors.green.shade100)
                                  : scheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.green.shade700
                                    : scheme.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            p.name.isNotEmpty ? p.name : p.address,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            p.address,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20)
                              : null,
                          onTap: () => widget.onSelect(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

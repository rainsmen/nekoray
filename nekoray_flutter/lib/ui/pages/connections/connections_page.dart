// Connections page — Dashboard (armwall style)
// Features: Service Start/Stop control, Active Node Selector & Quick Switching,
// Real-time Traffic Graph & Speeds, Website Connectivity & Latency Testing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
  final String domain;
  final SiteCategory category;
  final IconData icon;

  const SiteTarget({
    required this.id,
    required this.name,
    required this.url,
    required this.domain,
    required this.category,
    required this.icon,
  });

  /// Favicon via Google's icon service, with graceful fallback to [icon].
  String get faviconUrl =>
      'https://www.google.com/s2/favicons?domain=$domain&sz=64';
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
    domain: 'www.google.com',
    name: 'Google',
    url: 'https://www.google.com/generate_204',
    category: SiteCategory.global,
    icon: Icons.search,
  ),
  const SiteTarget(
    id: 'youtube',
    domain: 'www.youtube.com',
    name: 'YouTube',
    url: 'https://www.youtube.com',
    category: SiteCategory.global,
    icon: Icons.play_circle_outline,
  ),
  const SiteTarget(
    id: 'github',
    domain: 'github.com',
    name: 'GitHub',
    url: 'https://github.com',
    category: SiteCategory.global,
    icon: Icons.code,
  ),
  const SiteTarget(
    id: 'cloudflare',
    domain: '1.1.1.1',
    name: 'Cloudflare',
    url: 'https://1.1.1.1',
    category: SiteCategory.global,
    icon: Icons.cloud_outlined,
  ),
  const SiteTarget(
    id: 'chatgpt',
    domain: 'chat.openai.com',
    name: 'OpenAI / ChatGPT',
    url: 'https://chat.openai.com',
    category: SiteCategory.global,
    icon: Icons.smart_toy_outlined,
  ),
  const SiteTarget(
    id: 'telegram',
    domain: 't.me',
    name: 'Telegram',
    url: 'https://t.me',
    category: SiteCategory.global,
    icon: Icons.send_outlined,
  ),
  const SiteTarget(
    id: 'wikipedia',
    domain: 'www.wikipedia.org',
    name: 'Wikipedia',
    url: 'https://www.wikipedia.org',
    category: SiteCategory.global,
    icon: Icons.menu_book_outlined,
  ),
  const SiteTarget(
    id: 'baidu',
    domain: 'www.baidu.com',
    name: 'Baidu',
    url: 'https://www.baidu.com',
    category: SiteCategory.domestic,
    icon: Icons.language,
  ),
  const SiteTarget(
    id: 'bilibili',
    domain: 'www.bilibili.com',
    name: 'Bilibili',
    url: 'https://www.bilibili.com',
    category: SiteCategory.domestic,
    icon: Icons.tv,
  ),
  const SiteTarget(
    id: 'taobao',
    domain: 'www.taobao.com',
    name: 'Taobao',
    url: 'https://www.taobao.com',
    category: SiteCategory.domestic,
    icon: Icons.shopping_bag_outlined,
  ),
  const SiteTarget(
    id: 'qq',
    domain: 'www.qq.com',
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

  // Egress IPs: direct (domestic) vs through the running proxy (overseas).
  String? _directIp;
  String? _directSrc;
  String? _proxyIp;
  String? _proxySrc;
  bool _ipLoading = false;
  bool _ipAutoFetched = false;

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

      final isRunning = ref.read(connectedProfileProvider) > 0;
      final settings = ref.read(settingsProvider);
      if (isRunning && settings.mixedPort > 0) {
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            final client = HttpClient();
            client.findProxy = (uri) => 'PROXY 127.0.0.1:${settings.mixedPort}';
            client.badCertificateCallback = (cert, host, port) => true;
            return client;
          },
        );
      }

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

  /// Queries egress IPs. Direct fetch shows the domestic exit; fetching
  /// through the local mixed inbound shows the overseas exit, so it only
  /// runs while the proxy is up. Multiple sources are tried in order.
  Future<void> _refreshIps() async {
    if (_ipLoading) return;
    setState(() => _ipLoading = true);
    try {
      final settings = ref.read(settingsProvider);
      final running =
          ref.read(connectedProfileProvider) > 0 && settings.mixedPort > 0;
      final direct = await _fetchIp(useProxy: false, port: 0);
      (String, String)? proxy;
      if (running) {
        proxy = await _fetchIp(useProxy: true, port: settings.mixedPort);
      }
      if (!mounted) return;
      setState(() {
        _directIp = direct?.$1;
        _directSrc = direct?.$2;
        _proxyIp = proxy?.$1;
        _proxySrc = proxy?.$2;
      });
    } finally {
      if (mounted) {
        setState(() => _ipLoading = false);
      }
    }
  }

  /// Returns (ip, sourceHost) or null when all sources fail.
  Future<(String, String)?> _fetchIp(
      {required bool useProxy, required int port}) async {
    const sources = [
      'https://api.ip.sb/ip',
      'https://ipinfo.io/ip',
      'https://ifconfig.me/ip',
    ];
    for (final url in sources) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          headers: {'User-Agent': 'nekoray'},
        ));
        if (useProxy) {
          dio.httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () {
              final client = HttpClient();
              client.findProxy = (uri) => 'PROXY 127.0.0.1:$port';
              client.badCertificateCallback =
                  (cert, host, port) => true;
              return client;
            },
          );
        }
        final resp = await dio.get(url);
        if (resp.statusCode == 200) {
          final ip = _extractIp(resp.data?.toString() ?? '');
          if (ip != null) return (ip, Uri.parse(url).host);
        }
      } catch (_) {}
    }
    return null;
  }

  String? _extractIp(String s) {
    final t = s.trim().split(RegExp(r'\s+')).firstWhere(
          (e) => e.isNotEmpty,
          orElse: () => '',
        );
    if (t.isEmpty) return null;
    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(t)) return t;
    if (t.contains(':') && !t.contains(' ')) return t; // IPv6 literal
    return null;
  }

  Future<void> _stopService() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isStartingOrStopping = true);
    try {
      if (ref.read(settingsProvider).systemProxy) {
        try {
          await SystemIntegration.disableSystemProxy();
        } catch (_) {}
      }
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
  }

  Future<void> _startService(ProxyEntity? activeProfile) async {
    final messenger = ScaffoldMessenger.of(context);
    if (activeProfile == null || activeProfile.id == 0) {
      messenger.showSnackBar(SnackBar(
        content: Text(I18n.t('noActiveNode')),
        backgroundColor: Colors.orange,
      ));
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

      final datastore = datastoreJson(settings);

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

      ref.read(connectedProfileProvider.notifier).state = activeProfile.id;
      ref.read(selectedProfileProvider.notifier).state = activeProfile.id;
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

  Future<void> _toggleService(ProxyEntity? activeProfile) async {
    final connectedId = ref.read(connectedProfileProvider);
    if (connectedId > 0) {
      await _stopService();
    } else {
      await _startService(activeProfile);
    }
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
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    final runningId = connectedId;
    // Selection is independent from running state: it defaults to the
    // running node, else the first node, and never auto-starts anything.
    final storedSelected = ref.watch(selectedProfileProvider);
    final selectedId = storedSelected > 0
        ? storedSelected
        : (runningId > 0
            ? runningId
            : (profiles.isNotEmpty ? profiles.first.id : 0));
    final selectedProfile = profiles.firstWhere(
      (p) => p.id == selectedId,
      orElse: () => profiles.isNotEmpty
          ? profiles.first
          : ProxyEntity(id: 0, type: ''),
    );
    final hasSelectedNode = selectedProfile.id > 0;

    final latestUp = history.isNotEmpty ? history.last.up : 0;
    final latestDown = history.isNotEmpty ? history.last.down : 0;
    final trafficNotifier = ref.watch(trafficHistoryProvider.notifier);

    final globalSites =
        defaultSites.where((s) => s.category == SiteCategory.global).toList();
    final domesticSites =
        defaultSites.where((s) => s.category == SiteCategory.domestic).toList();

    // Fetch egress IPs once the proxy is up (manual refresh anytime).
    if (!_ipAutoFetched && isConnected) {
      _ipAutoFetched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIps());
    }

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
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Status Circle Indicator / Power button
                      GestureDetector(
                        onTap: _isStartingOrStopping
                            ? null
                            : () => _toggleService(hasSelectedNode ? selectedProfile : null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 48,
                          height: 48,
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
                                    size: 24,
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
                                fontSize: 16,
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
                            : () => _toggleService(hasSelectedNode ? selectedProfile : null),
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

                  // Node selector dropdown. Switching only changes the
                  // selection while stopped; while running it hot-switches.
                  DropdownButtonFormField<int>(
                    value: hasSelectedNode ? selectedProfile.id : null,
                    hint: Text(I18n.t('noActiveNode')),
                    decoration: InputDecoration(
                      labelText: I18n.t('selectNode'),
                      prefixIcon:
                          const Icon(Icons.dns_outlined, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: [
                      for (final p in profiles)
                        DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  p.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${p.name.isNotEmpty ? p.name : p.address}'
                                  '${p.latency > 0 ? ' · ${p.latency}ms' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: p.id == runningId
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: p.id == runningId
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (id) async {
                      if (id == null) return;
                      ref
                          .read(selectedProfileProvider.notifier)
                          .state = id;
                      // Stopped stays stopped — selection only. Running
                      // hot-switches to the newly picked node.
                      if (!isConnected) return;
                      final picked = profiles.firstWhere(
                        (e) => e.id == id,
                        orElse: () => selectedProfile,
                      );
                      await _startService(picked);
                    },
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
                        "${I18n.t('uploadSpeed')} / ${I18n.t('downloadSpeed')}",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Compact inline rates: icon + live value, no bulky boxes.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward,
                            size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _formatSpeed(latestUp),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.arrow_downward,
                            size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatSpeed(latestDown),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isConnected
                              ? I18n.t('realtime')
                              : I18n.t('disconnected'),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Legend + session totals.
                  Row(
                    children: [
                      _LegendDot(
                          color: scheme.primary,
                          label: I18n.t('uploadSpeed')),
                      const SizedBox(width: 12),
                      _LegendDot(
                          color: Colors.blue.shade600,
                          label: I18n.t('downloadSpeed')),
                      const Spacer(),
                      Text(
                        '${I18n.t('totalUpload')}: ${_formatBytes(trafficNotifier.totalUp)}'
                        ' · ${I18n.t('totalDownload')}: ${_formatBytes(trafficNotifier.totalDown)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 100,
                    child: _TrafficChart(history: history),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2b. Egress IPs: domestic (direct) vs overseas (via proxy)
          Card(
            elevation: isDark ? 0 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        I18n.t('ipAddresses'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: _ipLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        tooltip: I18n.t('testAll'),
                        onPressed: _ipLoading ? null : _refreshIps,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _IpTile(
                          icon: Icons.home_outlined,
                          color: Colors.teal.shade700,
                          label: I18n.t('domesticIp'),
                          ip: _directIp,
                          source: _directSrc,
                          loading: _ipLoading,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IpTile(
                          icon: Icons.flight_outlined,
                          color: scheme.primary,
                          label: I18n.t('internationalIp'),
                          ip: _proxyIp,
                          source: _proxySrc,
                          loading: _ipLoading,
                          offlineHint:
                              isConnected ? null : I18n.t('disconnected'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

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
                  _siteGrid(globalSites, scheme, isDark),

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
                  _siteGrid(domesticSites, scheme, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Uniform fixed-size site tiles in an adaptive grid: every tile is
  /// 64px tall and columns share the width, so rows always line up.
  Widget _siteGrid(
      List<SiteTarget> sites, ColorScheme scheme, bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = (constraints.maxWidth / 230).floor().clamp(1, 4);
        return GridView.count(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 64,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: sites
              .map((site) => _buildSiteChip(site, scheme, isDark))
              .toList(),
        );
      },
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
      borderRadius: BorderRadius.circular(14),
      onTap: isTesting ? null : () => _testSite(site),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Site favicon: Google service first, site's own icon second,
            // material icon when offline.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _FaviconImage(
                urls: [
                  site.faviconUrl,
                  'https://${site.domain}/favicon.ico',
                ],
                fallbackIcon: site.icon,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    site.domain,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isTesting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              // Fixed-width badge so every tile — untested, latency or FAIL —
              // lines up on the right edge regardless of text length.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 64),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    badgeText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tries favicon URLs in order, falling back to a material icon.
class _FaviconImage extends StatefulWidget {
  final List<String> urls;
  final IconData fallbackIcon;
  const _FaviconImage({required this.urls, required this.fallbackIcon});

  @override
  State<_FaviconImage> createState() => _FaviconImageState();
}

class _FaviconImageState extends State<_FaviconImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.urls.length) {
      return Icon(
        widget.fallbackIcon,
        size: 26,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return Image.network(
      widget.urls[_index],
      width: 28,
      height: 28,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _index++);
        });
        return Icon(
          widget.fallbackIcon,
          size: 26,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
      },
    );
  }
}

/// One egress-IP tile with fixed layout: icon + label on top, mono IP
/// value, source subtitle. Stays the same size tested or not.
class _IpTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? ip;
  final String? source;
  final bool loading;
  final String? offlineHint;

  const _IpTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.ip,
    required this.source,
    required this.loading,
    this.offlineHint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = ip ??
        (loading
            ? '…'
            : (offlineHint ?? I18n.t('untested')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFFF8FAFC),
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
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: ip != null ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            source ?? '',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Legend dot + label for the traffic chart.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TrafficChart extends StatelessWidget {  final List<TrafficPoint> history;
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
        lineTouchData: LineTouchData(
          enabled: history.length > 1,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${s.barIndex == 0 ? '↑' : '↓'} '
                    '${s.y.toStringAsFixed(1)} KB/s',
                    TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
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

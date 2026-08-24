// Connections page — traffic chart driven by the core's stats counters
// and comprehensive website connectivity/speed test dashboard (armwall style).

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';

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
  bool _polling = false;

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
      // Transient failures during restart are ignored
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

  Future<void> _testBatch(List<SiteTarget> targets) async {
    if (_isTestingAll) return;
    setState(() => _isTestingAll = true);
    try {
      await Future.wait(targets.map(_testSite));
    } finally {
      if (mounted) {
        setState(() => _isTestingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(trafficHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    final globalSites =
        defaultSites.where((s) => s.category == SiteCategory.global).toList();
    final domesticSites =
        defaultSites.where((s) => s.category == SiteCategory.domestic).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('connections')),
        actions: [
          IconButton(
            icon: _isTestingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed_outlined),
            tooltip: I18n.t('testAll'),
            onPressed: _isTestingAll ? null : () => _testBatch(defaultSites),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Traffic Chart Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 170,
                    child: history.isEmpty
                        ? Center(child: Text(I18n.t('waitingForData')))
                        : _TrafficChart(history: history),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.arrow_upward,
                        label: 'Upload',
                        value: history.isEmpty ? '0 B/s' : _fmt(history.last.up),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.arrow_downward,
                        label: 'Download',
                        value: history.isEmpty ? '0 B/s' : _fmt(history.last.down),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(height: 24),
          ),

          // 2. Speed Test Header & Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.network_check_outlined, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    I18n.t('websiteTest'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        : const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      _isTestingAll ? I18n.t('testing') : I18n.t('testAll'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed:
                        _isTestingAll ? null : () => _testBatch(defaultSites),
                  ),
                ],
              ),
            ),
          ),

          // Global Sites Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    I18n.t('globalSites'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isTestingAll ? null : () => _testBatch(globalSites),
                    child: const Text('Test Global', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildSiteCard(globalSites[index], scheme),
                childCount: globalSites.length,
              ),
            ),
          ),

          // Domestic Sites Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Text(
                    I18n.t('domesticSites'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.secondary,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isTestingAll ? null : () => _testBatch(domesticSites),
                    child: const Text('Test Domestic', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 380,
                mainAxisExtent: 72,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildSiteCard(domesticSites[index], scheme),
                childCount: domesticSites.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(SiteTarget site, ColorScheme scheme) {
    final res = _getResult(site.id);

    Color badgeColor;
    String badgeText;
    switch (res.status) {
      case TestStatus.untested:
        badgeColor = scheme.outlineVariant;
        badgeText = I18n.t('untested');
        break;
      case TestStatus.testing:
        badgeColor = scheme.primary;
        badgeText = I18n.t('testing');
        break;
      case TestStatus.success:
        final ms = res.latencyMs ?? 0;
        if (ms < 250) {
          badgeColor = Colors.green;
        } else if (ms < 700) {
          badgeColor = Colors.orange;
        } else {
          badgeColor = Colors.redAccent;
        }
        badgeText = '${res.latencyMs} ms (${res.httpCode ?? 200})';
        break;
      case TestStatus.failed:
        badgeColor = scheme.error;
        badgeText = 'Failed (${res.latencyMs ?? 0}ms)';
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: res.status == TestStatus.testing ? null : () => _testSite(site),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(site.icon, size: 24, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      site.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      site.url.replaceFirst('https://', '').replaceFirst('www.', ''),
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
              const SizedBox(width: 8),
              if (res.status == TestStatus.testing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
}

class _TrafficChart extends StatelessWidget {
  final List<TrafficPoint> history;

  const _TrafficChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = history.fold<double>(
      0,
      (m, p) => p.up > m ? p.up.toDouble() : m,
    );
    final maxDown = history.fold<double>(
      0,
      (m, p) => p.down > m ? p.down.toDouble() : m,
    );
    final maxY = (maxVal > maxDown ? maxVal : maxDown) * 1.1;
    if (maxY == 0) return Center(child: Text(I18n.t('waitingForData')));

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: history
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.up.toDouble()))
                .toList(),
            isCurved: true,
            color: scheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: history
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.down.toDouble()))
                .toList(),
            isCurved: true,
            color: scheme.tertiary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

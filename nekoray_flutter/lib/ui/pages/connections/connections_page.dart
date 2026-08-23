// Connections page — traffic chart driven by the core's stats counters.
//
// ListConnections is still a stub in the Go core (it needs the Clash API), so
// this page shows throughput only and says so plainly rather than presenting an
// empty table as if it were "no connections".

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/grpc_provider.dart';

/// One sample of throughput, in bytes per second.
class TrafficPoint {
  final DateTime time;
  final int up;
  final int down;
  TrafficPoint(this.time, this.up, this.down);
}

/// Rolling traffic history (last 60 samples ≈ 60 seconds).
final trafficHistoryProvider =
    StateNotifierProvider<TrafficHistoryNotifier, List<TrafficPoint>>(
  (ref) => TrafficHistoryNotifier(ref),
);

class TrafficHistoryNotifier extends StateNotifier<List<TrafficPoint>> {
  final Ref _ref;
  Timer? _timer;

  // QueryStats returns cumulative byte counters. Plotting those directly drew
  // a monotonically rising line labelled "B/s"; rates are the deltas.
  int? _lastUp;
  int? _lastDown;
  bool _polling = false;

  TrafficHistoryNotifier(this._ref) : super(const []) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling) return; // don't queue polls behind a slow core
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
      if (prevUp == null || prevDown == null) return; // need two samples

      // Counters reset when the instance restarts; clamp to zero.
      final point = TrafficPoint(
        DateTime.now(),
        (up - prevUp).clamp(0, 1 << 62),
        (down - prevDown).clamp(0, 1 << 62),
      );
      final next = [...state, point];
      state = next.length > 60 ? next.sublist(next.length - 60) : next;
    } catch (_) {
      // Transient failures are expected while the core restarts.
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

class ConnectionsPage extends ConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(trafficHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Connections & Traffic')),
      body: Column(
        children: [
          // Traffic chart
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: history.isEmpty
                  ? const Center(child: Text('Waiting for data...'))
                  : _TrafficChart(history: history),
            ),
          ),
          const Divider(),
          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(
                  icon: Icons.arrow_upward,
                  label: 'Current Up',
                  value: history.isEmpty
                      ? '0 B/s'
                      : _fmt(history.last.up),
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.arrow_downward,
                  label: 'Current Down',
                  value: history.isEmpty
                      ? '0 B/s'
                      : _fmt(history.last.down),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.link_off, size: 48),
                    SizedBox(height: 12),
                    Text('Per-connection listing is not implemented',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text(
                      'The core returns an empty list: connection tracking '
                      'needs the Clash API, which is not wired up yet. '
                      'Throughput above is live.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    if (maxY == 0) return const Center(child: Text('No traffic'));

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
                  Text(label,
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(value,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

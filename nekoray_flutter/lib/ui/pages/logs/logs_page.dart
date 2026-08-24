import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';

enum LogLevelFilter { all, debug, info, warn, error }

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  LogLevelFilter _filter = LogLevelFilter.all;
  String _searchQuery = '';
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  bool _matchesFilter(String line) {
    if (_searchQuery.isNotEmpty &&
        !line.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return false;
    }

    final lower = line.toLowerCase();
    switch (_filter) {
      case LogLevelFilter.all:
        return true;
      case LogLevelFilter.debug:
        return lower.contains('debug') || lower.contains('trace');
      case LogLevelFilter.info:
        return lower.contains('info') || lower.contains('listening') || lower.contains('start');
      case LogLevelFilter.warn:
        return lower.contains('warn') || lower.contains('warning');
      case LogLevelFilter.error:
        return lower.contains('error') ||
            lower.contains('fatal') ||
            lower.contains('fail') ||
            lower.contains('panic');
    }
  }

  Color _getLineColor(String line, ColorScheme scheme) {
    final lower = line.toLowerCase();
    if (lower.contains('error') || lower.contains('fatal') || lower.contains('panic') || lower.contains('fail')) {
      return scheme.error;
    }
    if (lower.contains('warn') || lower.contains('warning')) {
      return Colors.amber.shade700;
    }
    if (lower.contains('info') || lower.contains('listening on')) {
      return scheme.primary;
    }
    if (lower.contains('debug') || lower.contains('trace')) {
      return scheme.onSurfaceVariant.withValues(alpha: 0.7);
    }
    return scheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(coreLogProvider);
    final conn = ref.watch(coreConnectionProvider);
    final scheme = Theme.of(context).colorScheme;

    final filteredLogs = allLogs.where(_matchesFilter).toList();

    // Auto-scroll when new logs arrive
    ref.listen(coreLogProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(I18n.t('logs')),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: conn.isConnected
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conn.isConnected
                    ? '${I18n.t("connected")} :${conn.port ?? ""}'
                    : I18n.t('disconnected'),
                style: TextStyle(
                  fontSize: 12,
                  color: conn.isConnected
                      ? scheme.onPrimaryContainer
                      : scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
            tooltip: I18n.t('autoScroll'),
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
              if (_autoScroll) _scrollToBottom();
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: I18n.t('copyLogs'),
            onPressed: allLogs.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: allLogs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${allLogs.length} lines copied')),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: I18n.t('clearLogs'),
            onPressed: allLogs.isEmpty
                ? null
                : () => ref.read(coreLogProvider.notifier).clear(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              children: [
                // Search TextField
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: I18n.t('searchLogs'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                // Level filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(LogLevelFilter.all, I18n.t('allLevels')),
                      const SizedBox(width: 6),
                      _buildFilterChip(LogLevelFilter.info, 'Info'),
                      const SizedBox(width: 6),
                      _buildFilterChip(LogLevelFilter.warn, 'Warn'),
                      const SizedBox(width: 6),
                      _buildFilterChip(LogLevelFilter.error, 'Error'),
                      const SizedBox(width: 6),
                      _buildFilterChip(LogLevelFilter.debug, 'Debug'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Log output terminal view
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Text(
                      allLogs.isEmpty
                          ? I18n.t('waitingForData')
                          : 'No logs match the current filter',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : Container(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    child: SelectionArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final line = filteredLogs[index];
                          final color = _getLineColor(line, scheme);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              line,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                                height: 1.4,
                                color: color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(LogLevelFilter filter, String label) {
    final isSelected = _filter == filter;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

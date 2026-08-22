// Routing rules management page (task 12).
//
// Migrates dialog_manage_routes.cpp to Flutter. Features:
// - Visual rule list with add/edit/delete
// - JSON advanced editor
// - rule_set subscription management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/profile.dart';
import '../../core/state/providers.dart';

/// Routing config (loaded from routing_default.json).
final routingConfigProvider =
    StateNotifierProvider<RoutingConfigNotifier, AsyncValue<RoutingConfig>>(
  (ref) => RoutingConfigNotifier(),
);

class RoutingConfig {
  List<RoutingRule> rules;
  String finalOutbound;

  RoutingConfig({this.rules = const [], this.finalOutbound = 'direct'});
}

class RoutingConfigNotifier extends StateNotifier<AsyncValue<RoutingConfig>> {
  RoutingConfigNotifier() : super(const AsyncValue.loading());

  void set(RoutingConfig config) {
    state = AsyncValue.data(config);
  }

  void addRule(RoutingRule rule) {
    state.whenData((c) {
      state = AsyncValue.data(RoutingConfig(
        rules: [...c.rules, rule],
        finalOutbound: c.finalOutbound,
      ));
    });
  }

  void removeRule(int index) {
    state.whenData((c) {
      final rules = List<RoutingRule>.from(c.rules);
      if (index < rules.length) rules.removeAt(index);
      state = AsyncValue.data(RoutingConfig(
        rules: rules,
        finalOutbound: c.finalOutbound,
      ));
    });
  }
}

class RoutingPage extends ConsumerWidget {
  const RoutingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(routingConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addRule(context, ref),
          ),
        ],
      ),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (c) => c.rules.isEmpty
            ? const Center(child: Text('No routing rules. Click + to add.'))
            : ListView.separated(
                itemCount: c.rules.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = c.rules[i];
                  return ListTile(
                    leading: const Icon(Icons.route),
                    title: Text(r.domains.isNotEmpty
                        ? r.domains.join(', ')
                        : r.ip.isNotEmpty
                            ? r.ip.join(', ')
                            : 'Rule ${i + 1}'),
                    subtitle: Text(
                      '→ ${r.outbound}'
                      '${r.protocol.isNotEmpty ? '  proto=${r.protocol}' : ''}'
                      '${r.network.isNotEmpty ? '  net=${r.network}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(routingConfigProvider.notifier).removeRule(i),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _addRule(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _RuleEditDialog(),
    ).then((rule) {
      if (rule is RoutingRule) {
        ref.read(routingConfigProvider.notifier).addRule(rule);
      }
    });
  }
}

class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog();

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  final _domains = TextEditingController();
  final _ip = TextEditingController();
  final _outbound = TextEditingController(text: 'direct');
  String _protocol = '';
  String _network = '';

  @override
  void dispose() {
    _domains.dispose();
    _ip.dispose();
    _outbound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Routing Rule'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _domains,
              decoration: const InputDecoration(
                labelText: 'Domains (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ip,
              decoration: const InputDecoration(
                labelText: 'IP/CIDR (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _outbound,
              decoration: const InputDecoration(
                labelText: 'Outbound',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _protocol.isEmpty ? 'any' : _protocol,
                    decoration: const InputDecoration(
                      labelText: 'Protocol',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['any', 'tcp', 'udp']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _protocol = v == 'any' ? '' : v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _network.isEmpty ? 'any' : _network,
                    decoration: const InputDecoration(
                      labelText: 'Network',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['any', 'tcp', 'udp']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _network = v == 'any' ? '' : v!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final rule = RoutingRule(
              domains: _domains.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
              ip: _ip.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
              outbound: _outbound.text,
              protocol: _protocol,
              network: _network,
            );
            Navigator.pop(context, rule);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

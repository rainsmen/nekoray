// DNS page — edits the DNS half of the persisted routing config.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n.dart';
import '../routing/routing_page.dart';

enum DnsPreset { bypassCn, global, custom }

final remoteDnsPresets = <String, String>{
  'Google DoH': 'https://dns.google/dns-query',
  'Cloudflare DoH': 'https://1.1.1.1/dns-query',
  'Quad9 DoH': 'https://dns.quad9.net/dns-query',
  'OpenDNS': 'https://doh.opendns.com/dns-query',
  'Google TCP': 'tcp://8.8.8.8',
};

final directDnsPresets = <String, String>{
  'AliDNS DoH': 'https://223.5.5.5/dns-query',
  'DNSPod DoH': 'https://doh.pub/dns-query',
  '114DNS': 'udp://114.114.114.114',
  'Local System': 'local',
};

final dnsStrategies = <String, String>{
  'ipv4_only': 'IPv4 Only (推荐)',
  'prefer_ipv4': 'Prefer IPv4',
  'prefer_ipv6': 'Prefer IPv6',
  'ipv6_only': 'IPv6 Only',
};

class DnsPage extends ConsumerWidget {
  const DnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(routingConfigProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(I18n.t('dns'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load DNS settings: $e')),
        data: (config) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Presets Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      I18n.t('preset'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: DnsPreset.values
                          .where((p) => p != DnsPreset.custom)
                          .map((p) => ActionChip(
                                label: Text(_presetLabel(p)),
                                avatar: Icon(
                                  p == DnsPreset.bypassCn
                                      ? Icons.alt_route
                                      : Icons.public,
                                  size: 16,
                                ),
                                onPressed: () => _applyPreset(ref, p),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. Remote DNS Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: scheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('remoteDns'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Proxied domain queries are routed to this server over the proxy tunnel',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _DnsInputRow(
                      value: config.remoteDns,
                      hint: 'https://dns.google/dns-query',
                      onSubmit: (v) => ref
                          .read(routingConfigProvider.notifier)
                          .updateDns(remoteDns: v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: remoteDnsPresets.entries.map((e) {
                        final isSelected = config.remoteDns == e.value;
                        return ChoiceChip(
                          label: Text(e.key, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => ref
                              .read(routingConfigProvider.notifier)
                              .updateDns(remoteDns: e.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: dnsStrategies.containsKey(config.remoteDnsStrategy)
                          ? config.remoteDnsStrategy
                          : 'ipv4_only',
                      decoration: const InputDecoration(
                        labelText: 'Remote DNS Strategy',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: dnsStrategies.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(routingConfigProvider.notifier)
                              .updateDnsStrategy(remote: val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Direct DNS Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flash_on, color: scheme.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          I18n.t('directDns'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Domestic and bypassed domains are resolved directly for minimal latency',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _DnsInputRow(
                      value: config.directDns,
                      hint: 'https://223.5.5.5/dns-query',
                      onSubmit: (v) => ref
                          .read(routingConfigProvider.notifier)
                          .updateDns(directDns: v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: directDnsPresets.entries.map((e) {
                        final isSelected = config.directDns == e.value;
                        return ChoiceChip(
                          label: Text(e.key, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          onSelected: (_) => ref
                              .read(routingConfigProvider.notifier)
                              .updateDns(directDns: e.value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: dnsStrategies.containsKey(config.directDnsStrategy)
                          ? config.directDnsStrategy
                          : 'ipv4_only',
                      decoration: const InputDecoration(
                        labelText: 'Direct DNS Strategy',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: dnsStrategies.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(routingConfigProvider.notifier)
                              .updateDnsStrategy(direct: val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Advanced Switches
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('DNS Routing (智能分流)'),
                    subtitle: const Text(
                        'Route DNS requests based on routing domain rules'),
                    value: config.dnsRouting,
                    onChanged: (v) => ref
                        .read(routingConfigProvider.notifier)
                        .updateDns(dnsRouting: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(I18n.t('fakeip')),
                    subtitle: const Text(
                        'Respond with synthetic IP pool (198.18.0.0/15) for TUN mode'),
                    value: config.fakeIp,
                    onChanged: (v) => ref
                        .read(routingConfigProvider.notifier)
                        .updateDns(fakeIp: v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _presetLabel(DnsPreset p) {
    switch (p) {
      case DnsPreset.bypassCn:
        return I18n.t('bypassCn');
      case DnsPreset.global:
        return I18n.t('global');
      case DnsPreset.custom:
        return I18n.t('custom');
    }
  }

  void _applyPreset(WidgetRef ref, DnsPreset p) {
    final notifier = ref.read(routingConfigProvider.notifier);
    switch (p) {
      case DnsPreset.bypassCn:
        notifier.updateDns(
          remoteDns: 'https://dns.google/dns-query',
          directDns: 'https://223.5.5.5/dns-query',
          dnsRouting: true,
        );
        break;
      case DnsPreset.global:
        notifier.updateDns(
          remoteDns: 'https://dns.google/dns-query',
          directDns: 'https://dns.google/dns-query',
          dnsRouting: false,
        );
        break;
      case DnsPreset.custom:
        break;
    }
  }
}

class _DnsInputRow extends StatefulWidget {
  final String value;
  final String hint;
  final void Function(String) onSubmit;

  const _DnsInputRow({
    required this.value,
    required this.hint,
    required this.onSubmit,
  });

  @override
  State<_DnsInputRow> createState() => _DnsInputRowState();
}

class _DnsInputRowState extends State<_DnsInputRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _DnsInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.hint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => widget.onSubmit(v.trim()),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          icon: const Icon(Icons.check, size: 18),
          tooltip: I18n.t('save'),
          onPressed: () => widget.onSubmit(_controller.text.trim()),
        ),
      ],
    );
  }
}

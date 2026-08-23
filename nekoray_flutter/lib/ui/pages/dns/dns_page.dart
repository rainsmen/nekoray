// DNS page — edits the DNS half of the persisted routing config.
//
// These fields were previously stand-alone in-memory providers that nothing
// read: `toGrpcRouting` hardcoded its DNS servers, so changing anything here
// had no effect and did not survive a restart. They now write straight into
// routing_default.json, which is what the config builder consumes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/routing_page.dart';

enum DnsPreset { bypassCn, global, custom }

class DnsPage extends ConsumerWidget {
  const DnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(routingConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DNS')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load DNS settings: $e')),
        data: (config) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preset',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: DnsPreset.values
                          .where((p) => p != DnsPreset.custom)
                          .map((p) => ActionChip(
                                label: Text(_presetLabel(p)),
                                onPressed: () => _applyPreset(ref, p),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DnsFieldCard(
              title: 'Remote DNS',
              value: config.remoteDns,
              hint: 'https://dns.google/dns-query',
              onSubmit: (v) => ref
                  .read(routingConfigProvider.notifier)
                  .updateDns(remoteDns: v),
            ),
            _DnsFieldCard(
              title: 'Direct DNS',
              value: config.directDns,
              hint: 'https://223.5.5.5/dns-query',
              onSubmit: (v) => ref
                  .read(routingConfigProvider.notifier)
                  .updateDns(directDns: v),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('DNS Routing'),
                    subtitle: const Text(
                        'Resolve proxied domains through the remote server'),
                    value: config.dnsRouting,
                    onChanged: (v) => ref
                        .read(routingConfigProvider.notifier)
                        .updateDns(dnsRouting: v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('FakeIP'),
                    subtitle: const Text(
                        'Answer with synthetic addresses; usually paired with TUN mode'),
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
        return 'Bypass CN';
      case DnsPreset.global:
        return 'Global';
      case DnsPreset.custom:
        return 'Custom';
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

class _DnsFieldCard extends StatefulWidget {
  final String title;
  final String value;
  final String hint;
  final void Function(String) onSubmit;

  const _DnsFieldCard({
    required this.title,
    required this.value,
    required this.hint,
    required this.onSubmit,
  });

  @override
  State<_DnsFieldCard> createState() => _DnsFieldCardState();
}

class _DnsFieldCardState extends State<_DnsFieldCard> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _DnsFieldCard old) {
    super.didUpdateWidget(old);
    // Reflect external changes (a preset being applied) without clobbering
    // whatever the user is currently typing.
    if (old.value != widget.value && _ctrl.text == old.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
              // Persist on commit rather than on every keystroke, so the file
              // is not rewritten once per typed character.
              onSubmitted: widget.onSubmit,
              onTapOutside: (_) => widget.onSubmit(_ctrl.text),
            ),
          ],
        ),
      ),
    );
  }
}

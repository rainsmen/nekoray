// DNS settings page (task 12).
//
// Migrates the DNS section of dialog_basic_settings.cpp.
// Preset schemes: bypass CN, global, custom.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DnsPreset { bypassCn, global, custom }

final dnsPresetProvider = StateProvider<DnsPreset>((ref) => DnsPreset.bypassCn);
final dnsRemoteProvider = StateProvider<String>(
    (ref) => 'https://dns.google/dns-query');
final dnsDirectProvider =
    StateProvider<String>((ref) => 'https://223.5.5.5/dns-query');
final dnsBlockProvider = StateProvider<String>((ref) => 'rcode://success');
final dnsFakeipProvider = StateProvider<bool>((ref) => true);

class DnsPage extends ConsumerWidget {
  const DnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(dnsPresetProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('DNS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preset selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preset', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: DnsPreset.values.map((p) {
                      return ChoiceChip(
                        label: Text(_presetLabel(p)),
                        selected: preset == p,
                        onSelected: (_) {
                          ref.read(dnsPresetProvider.notifier).state = p;
                          _applyPreset(ref, p);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Servers
          _DnsFieldCard(
            title: 'Remote DNS',
            provider: dnsRemoteProvider,
            hint: 'https://dns.google/dns-query',
          ),
          _DnsFieldCard(
            title: 'Direct DNS',
            provider: dnsDirectProvider,
            hint: 'https://223.5.5.5/dns-query',
          ),
          _DnsFieldCard(
            title: 'Block DNS',
            provider: dnsBlockProvider,
            hint: 'rcode://success',
          ),
          // FakeIP
          Card(
            child: SwitchListTile(
              title: const Text('FakeIP'),
              subtitle: const Text('Use fake IP for domain resolution'),
              value: ref.watch(dnsFakeipProvider),
              onChanged: (v) => ref.read(dnsFakeipProvider.notifier).state = v,
            ),
          ),
        ],
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
    switch (p) {
      case DnsPreset.bypassCn:
        ref.read(dnsRemoteProvider.notifier).state = 'https://dns.google/dns-query';
        ref.read(dnsDirectProvider.notifier).state = 'https://223.5.5.5/dns-query';
        ref.read(dnsFakeipProvider.notifier).state = true;
        break;
      case DnsPreset.global:
        ref.read(dnsRemoteProvider.notifier).state = 'https://dns.google/dns-query';
        ref.read(dnsDirectProvider.notifier).state = 'https://dns.google/dns-query';
        ref.read(dnsFakeipProvider.notifier).state = false;
        break;
      case DnsPreset.custom:
        // keep current
        break;
    }
  }
}

class _DnsFieldCard extends ConsumerWidget {
  final String title;
  final StateProvider<String> provider;
  final String hint;

  const _DnsFieldCard({
    required this.title,
    required this.provider,
    required this.hint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: value,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(provider.notifier).state = v,
            ),
          ],
        ),
      ),
    );
  }
}

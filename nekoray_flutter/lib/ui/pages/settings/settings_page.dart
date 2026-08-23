// Settings page (task 12/14) — basic settings + platform features.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global settings providers
final systemProxyProvider = StateProvider<bool>((ref) => false);
final tunModeProvider = StateProvider<bool>((ref) => false);
final autoStartProvider = StateProvider<bool>((ref) => false);
final minimizeToTrayProvider = StateProvider<bool>((ref) => true);
final corePortProvider = StateProvider<int>((ref) => 19821);
final listenAddrProvider = StateProvider<String>((ref) => '127.0.0.1');
final mixedPortProvider = StateProvider<int>((ref) => 2080);

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Proxy settings
          _SectionTitle('Proxy'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('System Proxy'),
                  subtitle: const Text('Set system-wide HTTP/SOCKS proxy'),
                  trailing: Switch(
                    value: ref.watch(systemProxyProvider),
                    onChanged: (v) =>
                        ref.read(systemProxyProvider.notifier).state = v,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vpn_lock),
                  title: const Text('TUN Mode'),
                  subtitle: const Text('Virtual network interface (requires admin)'),
                  trailing: Switch(
                    value: ref.watch(tunModeProvider),
                    onChanged: (v) =>
                        ref.read(tunModeProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Core settings
          _SectionTitle('Core'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: const Text('Mixed Port'),
                  subtitle: Text('${ref.watch(mixedPortProvider)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInt(
                      context,
                      ref,
                      'Mixed Port',
                      mixedPortProvider,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns),
                  title: const Text('Listen Address'),
                  subtitle: Text(ref.watch(listenAddrProvider)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editString(
                      context,
                      ref,
                      'Listen Address',
                      listenAddrProvider,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.hub),
                  title: const Text('Core gRPC Port'),
                  subtitle: Text('${ref.watch(corePortProvider)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInt(
                      context,
                      ref,
                      'Core Port',
                      corePortProvider,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // UI settings
          _SectionTitle('UI'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.minimize),
                  title: const Text('Minimize to Tray'),
                  subtitle: const Text('Hide to system tray on close'),
                  value: ref.watch(minimizeToTrayProvider),
                  onChanged: (v) =>
                      ref.read(minimizeToTrayProvider.notifier).state = v,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: const Text('Start with System'),
                  subtitle: const Text('Launch on system boot'),
                  value: ref.watch(autoStartProvider),
                  onChanged: (v) =>
                      ref.read(autoStartProvider.notifier).state = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About NekoRay'),
              subtitle: const Text('Version 5.0.0-beta1\nFlutter desktop client'),
            ),
          ),
        ],
      ),
    );
  }

  void _editInt(BuildContext context, WidgetRef ref, String title,
      StateProvider<int> provider) {
    final ctrl = TextEditingController(text: ref.read(provider).toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text);
              if (v != null) ref.read(provider.notifier).state = v;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editString(BuildContext context, WidgetRef ref, String title,
      StateProvider<String> provider) {
    final ctrl = TextEditingController(text: ref.read(provider));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(provider.notifier).state = ctrl.text;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

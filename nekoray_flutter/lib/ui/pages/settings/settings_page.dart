// Settings page — backed by persisted [AppSettings].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';
import '../../../core/state/providers.dart';
import '../../../core/state/settings.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/migration.dart';
import '../../../core/system/system_integration.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(i18nProvider);
    const t = I18n.t;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final connection = ref.watch(coreConnectionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(t('proxy')),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.public),
                  title: Text(t('systemProxy')),
                  subtitle: Text(SystemIntegration.supportsSystemProxy
                      ? 'Point the OS at ${settings.listenAddress}:${settings.mixedPort}'
                      : 'Not available on this desktop environment'),
                  value: settings.systemProxy,
                  onChanged: SystemIntegration.supportsSystemProxy
                      ? (v) => _guard(context, () => notifier.setSystemProxy(v))
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vpn_lock),
                  title: Text(t('tunMode')),
                  subtitle: const Text(
                      'Route all traffic through a virtual interface. '
                      'Requires the core to run with elevated privileges.'),
                  value: settings.tunMode,
                  onChanged: (v) => _guard(context, () => notifier.setTunMode(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle(t('core')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: Text(t('mixedPort')),
                  subtitle: Text('${settings.mixedPort}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInt(
                      context,
                      title: 'Mixed Port',
                      initial: settings.mixedPort,
                      onSave: notifier.setMixedPort,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns),
                  title: Text(t('listenAddress')),
                  subtitle: Text(settings.listenAddress),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editString(
                      context,
                      title: 'Listen Address',
                      initial: settings.listenAddress,
                      onSave: notifier.setListenAddress,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.hub),
                  title: Text(t('corePort')),
                  subtitle: Text(settings.corePort == 0
                      ? 'Automatic${connection.port != null ? ' (currently ${connection.port})' : ''}'
                      : '${settings.corePort}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInt(
                      context,
                      title: 'Core gRPC Port (0 = automatic)',
                      initial: settings.corePort,
                      onSave: notifier.setCorePort,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Log Level'),
                  subtitle: Text(settings.logLevel),
                  trailing: DropdownButton<String>(
                    value: settings.logLevel,
                    items: const ['trace', 'debug', 'info', 'warn', 'error']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => v == null
                        ? null
                        : _guard(context, () => notifier.setLogLevel(v)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('Application'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.minimize),
                  title: const Text('Minimize to Tray'),
                  subtitle: const Text('Hide to the system tray on close'),
                  value: settings.minimizeToTray,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setMinimizeToTray(v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: const Text('Start with System'),
                  subtitle: Text(SystemIntegration.supportsAutoStart
                      ? 'Launch NekoRay on login'
                      : 'Not available on this platform'),
                  value: settings.autoStart,
                  onChanged: SystemIntegration.supportsAutoStart
                      ? (v) => _guard(context, () => notifier.setAutoStart(v))
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  trailing: DropdownButton<String>(
                    value: settings.locale,
                    items: const [
                      DropdownMenuItem(value: 'zh', child: Text('中文')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : _guard(context, () => notifier.setLocale(v)),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.science_outlined),
                  title: const Text('Include Pre-releases'),
                  subtitle: const Text('Offer beta builds when checking for updates'),
                  value: settings.checkPreRelease,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setCheckPreRelease(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About NekoRay'),
                  subtitle: const Text('Flutter client for the sing-box core'),
                ),
                const Divider(height: 1),
                FutureBuilder<String>(
                  future: LocalStore.rootPath(),
                  builder: (context, snap) => ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Data Directory'),
                    subtitle: Text(snap.data ?? '…'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: const Text('Import Old Configuration'),
                  subtitle: const Text(
                      'Scan for a previous nekoray config directory and import it'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _runMigration(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Detects an older config directory and imports it after confirmation.
  static Future<void> _runMigration(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final oldDir = await DataMigration.detectOldConfigDir();
    if (!context.mounted) return;
    if (oldDir == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No previous nekoray configuration was found'),
      ));
      return;
    }

    // Dry run first, so the user sees what would happen before anything is
    // written.
    final preview = await DataMigration.migrateFrom(oldDir, dryRun: true);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import old configuration?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: $oldDir'),
            const SizedBox(height: 8),
            Text('Profiles: ${preview.profiles}\n'
                'Groups: ${preview.groups}\n'
                'Routing files: ${preview.routing}'),
            if (preview.hasErrors) ...[
              const SizedBox(height: 8),
              Text('${preview.errors.length} file(s) could not be read '
                  'and will be skipped.'),
            ],
            const SizedBox(height: 8),
            const Text('Existing profiles are kept; imported nodes get new ids.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(I18n.t('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(I18n.t('import'))),
        ],
      ),
    );
    if (confirmed != true) return;

    final report = await DataMigration.migrateFrom(oldDir);
    await ref.read(profileListProvider.notifier).load();
    await ref.read(groupListProvider.notifier).load();
    messenger.showSnackBar(SnackBar(content: Text(report.toString())));
  }

  /// Runs an action that touches the OS, reporting failures instead of leaving
  /// the switch in a state that does not match reality.
  static Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: errorColor,
      ));
    }
  }

  void _editInt(
    BuildContext context, {
    required String title,
    required int initial,
    required Future<void> Function(int) onSave,
  }) {
    final ctrl = TextEditingController(text: initial.toString());
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(I18n.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text.trim());
              final messenger = ScaffoldMessenger.of(context);
              if (v == null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a number')),
                );
                return;
              }
              Navigator.pop(dialogContext);
              try {
                await onSave(v);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editString(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) {
    final ctrl = TextEditingController(text: initial);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(I18n.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await onSave(ctrl.text);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('$e')));
              }
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

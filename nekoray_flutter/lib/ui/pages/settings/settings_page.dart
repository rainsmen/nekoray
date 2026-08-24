// Settings page — backed by persisted [AppSettings], with Data Backup & Restore.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';
import '../../../core/state/providers.dart';
import '../../../core/state/settings.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/storage/migration.dart';
import '../../../core/system/system_integration.dart';
import '../routing/routing_page.dart';

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
          // 1. Proxy
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
                      'Requires elevated privileges.'),
                  value: settings.tunMode,
                  onChanged: (v) => _guard(context, () => notifier.setTunMode(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Core
          _SectionTitle(t('corePort')),
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
                      title: t('mixedPort'),
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
                      title: t('listenAddress'),
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
                      title: t('corePort'),
                      initial: settings.corePort,
                      onSave: notifier.setCorePort,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(t('logs')),
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

          // 3. Application & Theme
          _SectionTitle(t('application')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(t('themeMode')),
                  subtitle: Text(_getThemeName(settings.themeMode)),
                  trailing: DropdownButton<String>(
                    value: settings.themeMode,
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Row(
                          children: [
                            const Icon(Icons.brightness_auto_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(t('themeSystem')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'dark',
                        child: Row(
                          children: [
                            const Icon(Icons.dark_mode_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(t('themeDark')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Row(
                          children: [
                            const Icon(Icons.light_mode_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(t('themeLight')),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        notifier.setThemeMode(val);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.open_in_new),
                  title: Text(t('startWithSystem')),
                  subtitle: Text(SystemIntegration.supportsAutostart
                      ? 'Launch minimized when you log in'
                      : 'Not supported on this platform'),
                  value: settings.startWithSystem,
                  onChanged: SystemIntegration.supportsAutostart
                      ? (v) => _guard(context, () => notifier.setStartWithSystem(v))
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.close_fullscreen),
                  title: Text(t('minimizeToTray')),
                  subtitle: const Text('Hide to system tray instead of exiting'),
                  value: settings.minimizeToTray,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setMinimizeToTray(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Data Backup & Restore (备份与恢复)
          _SectionTitle(t('backupAndRestore')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_as_outlined),
                  title: Text(t('backupCurrentConfig')),
                  subtitle: const Text('Create a timestamped local snapshot'),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      try {
                        final filename = await LocalStore.createLocalBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${t("backupSuccess")}: $filename')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: Text(t('save')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(t('exportBackup')),
                  subtitle: const Text('Export full configuration JSON'),
                  trailing: OutlinedButton(
                    onPressed: () => _exportBackup(context),
                    child: Text(t('exportLogs')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(t('importBackup')),
                  subtitle: const Text('Restore configuration from JSON'),
                  trailing: OutlinedButton(
                    onPressed: () => _importBackup(context, ref),
                    child: Text(t('import')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(t('restoreBackup')),
                  subtitle: const Text('Browse and restore local snapshots'),
                  trailing: OutlinedButton(
                    onPressed: () => _showSnapshotsDialog(context, ref),
                    child: Text(t('restoreBackup')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. System Migration & Updates
          _SectionTitle(t('dataManagement')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.move_to_inbox),
                  title: const Text('Migrate from C++ NekoRay'),
                  subtitle: const Text('Import old configs from nekoray.exe directory'),
                  trailing: OutlinedButton(
                    onPressed: () => _migrateFromOldNekoray(context, ref),
                    child: Text(t('import')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: Text(t('checkUpdates')),
                  subtitle: const Text('v5.0.0-beta.11 · sing-box 1.13.19'),
                  trailing: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Checking for updates...')),
                      );
                    },
                    child: Text(t('checkUpdates')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _getThemeName(String themeMode) {
    switch (themeMode) {
      case 'dark':
        return I18n.t('themeDark');
      case 'light':
        return I18n.t('themeLight');
      default:
        return I18n.t('themeSystem');
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final backup = await LocalStore.exportBackup();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);

      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(I18n.t('exportBackupJson')),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(I18n.t('copyBackupJson')),
                const SizedBox(height: 12),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonStr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(I18n.t('cancel')),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: Text(I18n.t('copyLogs')),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(I18n.t('copiedToClipboard'))),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('importBackup')),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(I18n.t('importBackupDesc')),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "app": "nekoray",\n  "profiles": [...]\n}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(I18n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(I18n.t('import')),
          ),
        ],
      ),
    );

    if (confirmed != true || ctrl.text.trim().isEmpty || !context.mounted) return;

    try {
      final json = jsonDecode(ctrl.text.trim());
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Root of backup must be a JSON object');
      }

      await LocalStore.importBackup(json, clearExisting: true);

      // Reload all providers
      await ref.read(profileListProvider.notifier).load();
      await ref.read(groupListProvider.notifier).load();
      await ref.read(routingConfigProvider.notifier).load();
      await ref.read(settingsProvider.notifier).load();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.t('restoreSuccess'))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t("restoreFailed")}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSnapshotsDialog(BuildContext context, WidgetRef ref) async {
    final backups = await LocalStore.listLocalBackups();

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(I18n.t('restoreBackup')),
        content: SizedBox(
          width: 450,
          height: 300,
          child: backups.isEmpty
              ? Center(
                  child: Text(
                    I18n.t('noBackups'),
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: backups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = backups[i];
                    final name = f.path.replaceAll('\\', '/').split('/').last;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.backup_outlined, size: 20),
                      title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (confirmCtx) => AlertDialog(
                              title: Text(I18n.t('restoreBackup')),
                              content: Text(I18n.t('confirmRestore')),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(confirmCtx, false),
                                  child: Text(I18n.t('cancel')),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(confirmCtx, true),
                                  child: Text(I18n.t('save')),
                                ),
                              ],
                            ),
                          );

                          if (ok == true && context.mounted) {
                            Navigator.pop(ctx);
                            try {
                              await LocalStore.restoreLocalBackup(f);
                              await ref.read(profileListProvider.notifier).load();
                              await ref.read(groupListProvider.notifier).load();
                              await ref.read(routingConfigProvider.notifier).load();
                              await ref.read(settingsProvider.notifier).load();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(I18n.t('restoreSuccess'))),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: Text(I18n.t('start')),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(I18n.t('cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _migrateFromOldNekoray(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final oldDir = Directory.current;

    final preview = await DataMigration.preview(oldDir);
    if (!context.mounted) return;

    if (preview.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text('No legacy profiles found in ${oldDir.path}'),
      ));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Migrate legacy profiles?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Found ${preview.profiles.length} profile(s) and '
                '${preview.groups.length} group(s) in:'),
            const SizedBox(height: 4),
            Text(oldDir.path,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (preview.hasErrors) ...[
              const SizedBox(height: 8),
              Text('${preview.errors.length} file(s) could not be read and will be skipped.'),
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
            child: Text(I18n.t('save')),
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
            child: Text(I18n.t('save')),
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

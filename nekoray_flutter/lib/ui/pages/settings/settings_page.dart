// Settings page — backed by persisted [AppSettings], with Data Backup & Restore.

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/grpc/grpc_provider.dart';
import '../../../core/i18n.dart';
import '../../../core/state/providers.dart';
import '../../../core/state/settings.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/system/system_integration.dart';
import '../../../core/version.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';
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
          SectionHeader(t('proxy'), icon: Icons.public),
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
                  onChanged: (v) =>
                      _guard(context, () => notifier.setTunMode(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1b. TUN advanced — pre-configurable so the first TUN start does
          // not fail on zero-value MTU/stack, plus a privilege banner that
          // explains the #1 TUN failure cause before it happens.
          SectionHeader(t('tunAdvanced'), icon: Icons.vpn_lock),
          Card(
            child: Column(
              children: [
                const _PrivilegeTile(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: Text(t('vpnMtu')),
                  subtitle: Text('${settings.vpnMtu}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editInt(
                      context,
                      title: t('vpnMtu'),
                      initial: settings.vpnMtu,
                      onSave: notifier.setVpnMtu,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: Text(t('vpnStack')),
                  subtitle: Text(_stackName(settings.vpnStack)),
                  trailing: DropdownButton<int>(
                    value: settings.vpnStack,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('gvisor')),
                      DropdownMenuItem(value: 1, child: Text('system')),
                      DropdownMenuItem(value: 2, child: Text('mixed')),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : _guard(context, () => notifier.setVpnStack(v)),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.network_check),
                  title: Text(t('vpnStrictRoute')),
                  value: settings.vpnStrictRoute,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setVpnStrictRoute(v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lan_outlined),
                  title: Text(t('vpnIpv6')),
                  value: settings.vpnIpv6,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setVpnIpv6(v)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dns_outlined),
                  title: Text(t('fakeDns')),
                  value: settings.fakeDns,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setFakeDns(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Core
          SectionHeader(t('corePort'), icon: Icons.settings_ethernet),
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
          SectionHeader(t('application'), icon: Icons.apps_outlined),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(t('language')),
                  trailing: DropdownButton<String>(
                    value: settings.locale,
                    items: const [
                      DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        notifier.setLocale(val);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
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
                            const Icon(Icons.brightness_auto_outlined,
                                size: 18),
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
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: Text(t('accentColor')),
                  trailing: DropdownButton<int>(
                    value: settings.accent.clamp(0, 3),
                    items: [
                      DropdownMenuItem(
                        value: 0,
                        child: Row(
                          children: [
                            _AccentDot(AppTheme.accentSeeds[0]),
                            const SizedBox(width: 8),
                            Text(t('accentIndigo')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            _AccentDot(AppTheme.accentSeeds[1]),
                            const SizedBox(width: 8),
                            Text(t('accentTeal')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            _AccentDot(AppTheme.accentSeeds[2]),
                            const SizedBox(width: 8),
                            Text(t('accentPurple')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Row(
                          children: [
                            _AccentDot(AppTheme.accentSeeds[3]),
                            const SizedBox(width: 8),
                            Text(t('accentOrange')),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _guard(context, () => notifier.setAccent(val));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_outlined),
                  title: Text(t('autoUpdateSubs')),
                  trailing: DropdownButton<int>(
                    value: settings.subAutoUpdateHours,
                    items: [
                      DropdownMenuItem(value: 0, child: Text(t('updateOff'))),
                      DropdownMenuItem(value: 6, child: Text(t('every6h'))),
                      DropdownMenuItem(value: 12, child: Text(t('every12h'))),
                      DropdownMenuItem(value: 24, child: Text(t('every24h'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _guard(context, () => notifier.setSubAutoUpdate(val));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.open_in_new),
                  title: Text(t('startWithSystem')),
                  subtitle: Text(SystemIntegration.supportsAutoStart
                      ? t('autoStartDesc')
                      : t('notSupported')),
                  value: settings.autoStart,
                  onChanged: SystemIntegration.supportsAutoStart
                      ? (v) => _guard(context, () => notifier.setAutoStart(v))
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.close_fullscreen),
                  title: Text(t('minimizeToTray')),
                  subtitle: Text(t('minimizeToTrayDesc')),
                  value: settings.minimizeToTray,
                  onChanged: (v) =>
                      _guard(context, () => notifier.setMinimizeToTray(v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Data Backup & Restore (备份与恢复)
          SectionHeader(t('backupAndRestore'), icon: Icons.backup_outlined),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save_as_outlined),
                  title: Text(t('backupCurrentConfig')),
                  subtitle: Text(t('backupSnapshotDesc')),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      try {
                        final filename = await LocalStore.createLocalBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('${t("backupSuccess")}: $filename')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Backup failed: $e'),
                                backgroundColor: Colors.red),
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
                  subtitle: Text(t('exportBackupDesc')),
                  trailing: FilledButton.tonal(
                    onPressed: () => _exportBackupToFile(context),
                    child: Text(t('exportFile')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(t('importBackup')),
                  subtitle: Text(t('importTileDesc')),
                  trailing: FilledButton.tonal(
                    onPressed: () => _importBackup(context, ref),
                    child: Text(t('import')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(t('restoreBackup')),
                  subtitle: Text(t('restoreTileDesc')),
                  trailing: FilledButton.tonal(
                    onPressed: () => _showSnapshotsDialog(context, ref),
                    child: Text(t('restoreBackup')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Updates
          SectionHeader(t('checkUpdates'), icon: Icons.system_update_alt),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.new_releases_outlined),
                  title: Text(t('preReleaseTitle')),
                  subtitle: Text(t('preReleaseDesc')),
                  value: settings.checkPreRelease,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setCheckPreRelease(v),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: Text(t('checkUpdates')),
                  subtitle: Text('$appVersion · sing-box $singBoxVersion'),
                  trailing: FilledButton.tonal(
                    onPressed: () => _checkUpdates(context, ref),
                    child: Text(t('checkUpdates')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. About
          SectionHeader(t('aboutNekoRay'), icon: Icons.info_outlined),
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icon/app_logo.png',
                  width: 36,
                  height: 36,
                ),
              ),
              title: const Text('NekoRay'),
              subtitle: Text('$appVersion · sing-box $singBoxVersion'),
              trailing: FilledButton.tonal(
                onPressed: () => _showAbout(context),
                child: Text(t('viewDetails')),
              ),
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

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );

    try {
      final client = ref.read(grpcClientProvider);
      final settings = ref.read(settingsProvider);
      final sessionId = client.newUpdateSessionId();
      final resp = await client.checkForUpdates(
        sessionId: sessionId,
        includePreRelease: settings.checkPreRelease,
      );

      if (!context.mounted) {
        return;
      }

      if (resp.error.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Update check error: ${resp.error}'),
              backgroundColor: Colors.red),
        );
        return;
      }

      if (resp.downloadUrl.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text('New Version Available: ${resp.assetsName}'),
            content: SingleChildScrollView(
              child: Text(resp.releaseNote.isNotEmpty
                  ? resp.releaseNote
                  : 'A newer version is available. Download update?'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(I18n.t('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _performDownloadUpdate(context, ref, sessionId);
                },
                child: const Text('Download Update'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('You are already using the latest version.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Failed to check updates: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performDownloadUpdate(
      BuildContext context, WidgetRef ref, String sessionId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Downloading update package in background...')),
    );
    try {
      final client = ref.read(grpcClientProvider);
      final resp = await client.downloadUpdate(sessionId: sessionId);
      if (!context.mounted) {
        return;
      }
      if (resp.error.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Download failed: ${resp.error}'),
              backgroundColor: Colors.red),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Update downloaded. Restart application or run updater to apply.'),
            duration: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Update download error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Exports the backup to a user-chosen file. Falls back to an internal
  /// timestamped snapshot when no native save dialog is available.
  Future<void> _exportBackupToFile(BuildContext context) async {
    try {
      final backup = await LocalStore.exportBackup();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
      final now = DateTime.now();
      final fileName = 'nekoray-backup-${now.year}'
          '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.json';

      String? savedPath;
      try {
        final uri = await FilePicker.saveFile(
          dialogTitle: I18n.t('exportBackup'),
          fileName: fileName,
          bytes: utf8.encode(jsonStr),
          mimeType: 'application/json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
        if (uri != null) {
          savedPath = uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
        } else {
          return; // user cancelled — not an error
        }
      } on Exception {
        savedPath = null; // e.g. missing zenity on Linux → fallback below
      }

      if (savedPath != null) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${I18n.t('fileSaved')}: $savedPath')),
        );
        return;
      }

      final filename = await LocalStore.createLocalBackup();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.t('backupSuccess')}: $filename')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'), backgroundColor: Colors.red),
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
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(I18n.t('importFromFile')),
                onPressed: () async {
                  try {
                    final picked = await FilePicker.pickFile(
                      dialogTitle: I18n.t('importBackup'),
                      type: FileType.custom,
                      allowedExtensions: ['json'],
                    );
                    if (picked == null) {
                      return;
                    }
                    ctrl.text = utf8.decode(await picked.readAsBytes());
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('${I18n.t('restoreFailed')}: $e'),
                          backgroundColor: Theme.of(ctx).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
              ),
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

    if (confirmed != true || ctrl.text.trim().isEmpty || !context.mounted) {
      return;
    }

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
          SnackBar(
              content: Text('${I18n.t("restoreFailed")}: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showSnapshotsDialog(BuildContext context, WidgetRef ref) async {
    final backups = await LocalStore.listLocalBackups();

    if (!context.mounted) {
      return;
    }

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
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
                                  onPressed: () =>
                                      Navigator.pop(confirmCtx, false),
                                  child: Text(I18n.t('cancel')),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  onPressed: () =>
                                      Navigator.pop(confirmCtx, true),
                                  child: Text(I18n.t('save')),
                                ),
                              ],
                            ),
                          );

                          if (ok == true && context.mounted) {
                            Navigator.pop(ctx);
                            try {
                              await LocalStore.restoreLocalBackup(f);
                              await ref
                                  .read(profileListProvider.notifier)
                                  .load();
                              await ref.read(groupListProvider.notifier).load();
                              await ref
                                  .read(routingConfigProvider.notifier)
                                  .load();
                              await ref.read(settingsProvider.notifier).load();

                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(I18n.t('restoreSuccess'))),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Restore failed: $e'),
                                    backgroundColor: Colors.red),
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

  Future<void> _showAbout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_logo.png',
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 12),
            const Text('NekoRay'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$appVersion · sing-box $singBoxVersion'),
            const SizedBox(height: 4),
            const Text('GPL-3.0 · Flutter + sing-box'),
            const SizedBox(height: 12),
            for (final link in const [
              'https://github.com/rainsmen/nekoray',
              'https://github.com/rainsmen/nekoray/issues',
              'https://github.com/rainsmen/nekoray/releases',
            ])
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  link,
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _openUrl(ctx, link),
              ),
          ],
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

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final ok =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(url)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(url)),
        );
      }
    }
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

String _stackName(int v) => switch (v) {
      1 => 'system',
      2 => 'mixed',
      _ => 'gvisor',
    };

/// Color dot preview for the accent picker.
class _AccentDot extends StatelessWidget {
  final Color color;
  const _AccentDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Privilege banner for TUN mode. Stateful so the (fast, side-effect free)
/// elevation probe runs once instead of on every settings rebuild.
class _PrivilegeTile extends StatefulWidget {
  const _PrivilegeTile();

  @override
  State<_PrivilegeTile> createState() => _PrivilegeTileState();
}

class _PrivilegeTileState extends State<_PrivilegeTile> {
  late final Future<bool> _elevated = SystemIntegration.isElevated();

  @override
  Widget build(BuildContext context) {
    const t = I18n.t;
    return FutureBuilder<bool>(
      future: _elevated,
      builder: (ctx, snap) {
        final elevated = snap.data ?? false;
        final scheme = Theme.of(ctx).colorScheme;
        return ListTile(
          leading: Icon(
            snap.hasData
                ? (elevated
                    ? Icons.verified_user_outlined
                    : Icons.warning_amber_outlined)
                : Icons.shield_outlined,
            color: snap.hasData && !elevated ? scheme.error : null,
          ),
          title: Text(t('privilegeStatus')),
          subtitle: Text(!snap.hasData
              ? t('checking')
              : (elevated ? t('elevatedOk') : t('elevatedMissing'))),
        );
      },
    );
  }
}

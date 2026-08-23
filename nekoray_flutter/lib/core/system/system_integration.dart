// OS-level integration: system proxy and auto-start.
//
// These settings used to be toggles that changed nothing. Each platform is
// implemented where a supported mechanism exists, and reports an explicit
// [UnsupportedIntegration] where none does — a switch that silently does
// nothing is worse than one that says why it cannot.

import 'dart:io';

class UnsupportedIntegration implements Exception {
  final String message;
  UnsupportedIntegration(this.message);
  @override
  String toString() => message;
}

class IntegrationFailure implements Exception {
  final String message;
  IntegrationFailure(this.message);
  @override
  String toString() => message;
}

class SystemIntegration {
  SystemIntegration._();

  /// True when the current platform has a system-proxy implementation.
  static bool get supportsSystemProxy =>
      Platform.isWindows || Platform.isMacOS || _hasGsettings;

  /// True when the current platform has an auto-start implementation.
  static bool get supportsAutoStart =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get _hasGsettings {
    if (!Platform.isLinux) return false;
    try {
      return Process.runSync('which', ['gsettings']).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // --- System proxy -----------------------------------------------------

  static Future<void> enableSystemProxy({
    required String host,
    required int port,
  }) async {
    final target = host.isEmpty ? '127.0.0.1' : host;
    if (Platform.isWindows) {
      await _run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f',
      ]);
      await _run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', '$target:$port', '/f',
      ]);
      return;
    }

    if (Platform.isMacOS) {
      for (final service in await _macNetworkServices()) {
        await _run('networksetup', ['-setwebproxy', service, target, '$port']);
        await _run('networksetup', ['-setsecurewebproxy', service, target, '$port']);
        await _run('networksetup', ['-setsocksfirewallproxy', service, target, '$port']);
      }
      return;
    }

    if (Platform.isLinux) {
      if (!_hasGsettings) {
        throw UnsupportedIntegration(
            'No supported system-proxy mechanism found (gsettings is missing). '
            'Configure your desktop environment or applications to use '
            '$target:$port manually.');
      }
      await _run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'manual']);
      for (final scheme in ['http', 'https', 'socks']) {
        await _run('gsettings',
            ['set', 'org.gnome.system.proxy.$scheme', 'host', target]);
        await _run('gsettings',
            ['set', 'org.gnome.system.proxy.$scheme', 'port', '$port']);
      }
      return;
    }

    throw UnsupportedIntegration(
        'System proxy is not supported on ${Platform.operatingSystem}');
  }

  static Future<void> disableSystemProxy() async {
    if (Platform.isWindows) {
      await _run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f',
      ]);
      return;
    }
    if (Platform.isMacOS) {
      for (final service in await _macNetworkServices()) {
        await _run('networksetup', ['-setwebproxystate', service, 'off']);
        await _run('networksetup', ['-setsecurewebproxystate', service, 'off']);
        await _run('networksetup', ['-setsocksfirewallproxystate', service, 'off']);
      }
      return;
    }
    if (Platform.isLinux && _hasGsettings) {
      await _run('gsettings', ['set', 'org.gnome.system.proxy', 'mode', 'none']);
      return;
    }
    // Nothing was enabled, so nothing to undo.
  }

  static Future<List<String>> _macNetworkServices() async {
    final r = await Process.run('networksetup', ['-listallnetworkservices']);
    if (r.exitCode != 0) return const [];
    return (r.stdout as String)
        .split('\n')
        .skip(1) // header line
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('*'))
        .toList();
  }

  // --- Auto-start -------------------------------------------------------

  static Future<void> setAutoStart(bool enabled) async {
    final exe = Platform.resolvedExecutable;

    if (Platform.isWindows) {
      const key = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
      if (enabled) {
        await _run('reg',
            ['add', key, '/v', 'NekoRay', '/t', 'REG_SZ', '/d', exe, '/f']);
      } else {
        // Absent value is not an error.
        await _run('reg', ['delete', key, '/v', 'NekoRay', '/f'],
            allowFailure: true);
      }
      return;
    }

    if (Platform.isLinux) {
      final dir = Directory(
          '${Platform.environment['HOME'] ?? '.'}/.config/autostart');
      final file = File('${dir.path}/nekoray.desktop');
      if (enabled) {
        await dir.create(recursive: true);
        await file.writeAsString('[Desktop Entry]\n'
            'Type=Application\n'
            'Name=NekoRay\n'
            'Exec=$exe\n'
            'Terminal=false\n'
            'X-GNOME-Autostart-enabled=true\n');
      } else if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    if (Platform.isMacOS) {
      final dir = Directory(
          '${Platform.environment['HOME'] ?? '.'}/Library/LaunchAgents');
      final file = File('${dir.path}/com.nekoray.client.plist');
      if (enabled) {
        await dir.create(recursive: true);
        await file.writeAsString('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
            '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0"><dict>\n'
            '  <key>Label</key><string>com.nekoray.client</string>\n'
            '  <key>ProgramArguments</key><array><string>$exe</string></array>\n'
            '  <key>RunAtLoad</key><true/>\n'
            '</dict></plist>\n');
      } else if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    throw UnsupportedIntegration(
        'Auto-start is not supported on ${Platform.operatingSystem}');
  }

  static Future<void> _run(
    String executable,
    List<String> args, {
    bool allowFailure = false,
  }) async {
    final ProcessResult r;
    try {
      r = await Process.run(executable, args);
    } catch (e) {
      throw IntegrationFailure('failed to run $executable: $e');
    }
    if (r.exitCode != 0 && !allowFailure) {
      final err = (r.stderr as String?)?.trim();
      throw IntegrationFailure(
          '$executable exited with ${r.exitCode}${err == null || err.isEmpty ? '' : ': $err'}');
    }
  }
}

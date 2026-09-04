import 'dart:io';
import 'package:flutter/services.dart';

/// Bridges Flutter with the native Android VpnService via MethodChannel.
class AndroidVpn {
  AndroidVpn._();

  static const MethodChannel _channel = MethodChannel('com.nekoray.client/vpn');

  /// True if the current runtime platform is Android.
  static bool get isSupported => Platform.isAndroid;

  /// Checks whether VPN permission is granted. If not, prompts the user with
  /// the system VPN consent dialog. Returns true if granted.
  static Future<bool> prepare() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('prepare');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the Android VpnService and returns the detached native TUN file descriptor.
  static Future<int?> start({
    int mtu = 1500,
    bool ipv6 = false,
  }) async {
    if (!isSupported) return null;
    try {
      final fd = await _channel.invokeMethod<int>('start', {
        'mtu': mtu,
        'ipv6': ipv6,
      });
      return fd;
    } catch (_) {
      return null;
    }
  }

  /// Stops the running Android VpnService.
  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Checks if the Android VpnService is currently running.
  static Future<bool> isRunning() async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

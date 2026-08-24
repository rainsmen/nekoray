import 'package:flutter/material.dart';
import '../../core/i18n.dart';

/// Bottom status bar showing connection state and traffic.
class StatusBar extends StatelessWidget {
  final bool connected;
  final int up; // bytes/s
  final int down; // bytes/s

  const StatusBar({super.key, required this.connected, required this.up, required this.down});

  String _fmt(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: connected ? Colors.green.shade600 : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            connected ? I18n.t('connected') : I18n.t('disconnected'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: connected ? Colors.green.shade700 : scheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Icon(Icons.arrow_upward, size: 14, color: scheme.primary),
          const SizedBox(width: 2),
          Text(
            _fmt(up),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 14),
          Icon(Icons.arrow_downward, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 2),
          Text(
            _fmt(down),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

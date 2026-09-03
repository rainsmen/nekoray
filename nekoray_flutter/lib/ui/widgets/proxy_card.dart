import 'package:flutter/material.dart';

/// A card representing a single proxy profile.
///
/// The node remark ([name]) is the primary line; the raw [address] and the
/// subscription [groupName] are secondary. An optional [onTest] wires the
/// per-node latency probe; while [testing] the latency badge spins instead
/// of showing a stale value.
class ProxyCard extends StatelessWidget {
  final String name;
  final String type;
  final String address;
  final int latency;
  final bool connected;
  final VoidCallback? onTap;
  final bool testing;
  final VoidCallback? onTest;
  final String? groupName;
  final bool selected;
  final VoidCallback? onLongPress;

  const ProxyCard({
    super.key,
    required this.name,
    required this.type,
    required this.address,
    required this.latency,
    this.connected = false,
    this.onTap,
    this.testing = false,
    this.onTest,
    this.groupName,
    this.selected = false,
    this.onLongPress,
  });

  Color _latencyColor(bool isDark) {
    if (latency <= 0) {
      return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
    if (latency < 150) {
      return isDark ? Colors.green.shade400 : Colors.green.shade700;
    }
    if (latency < 300) {
      return isDark ? Colors.amber.shade400 : Colors.amber.shade800;
    }
    return isDark ? Colors.red.shade400 : Colors.red.shade700;
  }

  /// Secondary line. Nodes with a remark show `address · group`; nodes
  /// without one already show the address as the primary line, so only the
  /// group is shown (possibly empty, in which case the line collapses).
  String get _subtitle {
    final g = groupName?.trim() ?? '';
    final hasRemark = name.isNotEmpty && name != address;
    if (!hasRemark) {
      return g;
    }
    if (g.isEmpty) {
      return address;
    }
    return '$address · $g';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latColor = _latencyColor(isDark);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDark ? 0 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? Colors.amber
              : connected
                  ? (isDark
                      ? scheme.primary
                      : scheme.primary.withOpacity(0.6))
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFCBD5E1)),
          width: (selected || connected) ? 1.5 : 1,
        ),
      ),
      color: connected
          ? (isDark ? scheme.primary.withOpacity(0.12) : const Color(0xFFEEF2FF))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: connected
                      ? scheme.primary
                      : (isDark ? scheme.primary.withOpacity(0.2) : const Color(0xFFE0E7FF)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: connected ? Colors.white : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? address : name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: connected ? FontWeight.bold : FontWeight.w600,
                        color: connected ? scheme.primary : scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onTest != null)
                IconButton(
                  icon: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed_outlined, size: 18),
                  tooltip: 'Test latency',
                  onPressed: testing ? null : onTest,
                  visualDensity: VisualDensity.compact,
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: latColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: latColor.withOpacity(0.4)),
                ),
                child: testing
                    ? SizedBox(
                        width: 16,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: latColor,
                        ),
                      )
                    : Text(
                        latency > 0
                            ? '${latency}ms'
                            : (latency == 0 ? 'timeout' : '-'),
                        style: TextStyle(
                          color: latColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

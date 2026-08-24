import 'package:flutter/material.dart';

/// A card representing a single proxy profile.
class ProxyCard extends StatelessWidget {
  final String name;
  final String type;
  final String address;
  final int latency;
  final bool connected;
  final VoidCallback? onTap;

  const ProxyCard({
    super.key,
    required this.name,
    required this.type,
    required this.address,
    required this.latency,
    this.connected = false,
    this.onTap,
  });

  Color _latencyColor() {
    if (latency <= 0) return Colors.grey;
    if (latency < 150) return Colors.green;
    if (latency < 300) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: connected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(connected ? Icons.bolt : Icons.dns_outlined,
                  color: connected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      '$type · $address',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _latencyColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  latency > 0 ? '${latency}ms' : 'timeout',
                  style: TextStyle(
                      color: _latencyColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

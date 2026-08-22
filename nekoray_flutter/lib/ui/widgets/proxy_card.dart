import 'package:flutter/material.dart';

/// A card representing a single proxy profile, styled after armwall.
class ProxyCard extends StatelessWidget {
  final String name;
  final String type;
  final String address;
  final int latency;

  const ProxyCard({
    super.key,
    required this.name,
    required this.type,
    required this.address,
    required this.latency,
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.dns_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$type · $address',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _latencyColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                latency > 0 ? '${latency}ms' : 'timeout',
                style: TextStyle(color: _latencyColor(), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

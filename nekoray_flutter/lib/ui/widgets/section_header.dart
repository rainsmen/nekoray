import 'package:flutter/material.dart';

/// Unified section header: small caps-style primary label with an optional
/// leading icon. Replaces the assorted ad-hoc title widgets so every settings
/// section (and future pages) share one visual language.
class SectionHeader extends StatelessWidget {
  final String text;
  final IconData? icon;

  const SectionHeader(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: scheme.primary.withOpacity(0.25),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/status_labels.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  ({Color bg, Color fg}) _colors(ColorScheme cs) {
    switch (status) {
      case 'resolved':
        return (bg: const Color(0xFFE0F4E8), fg: const Color(0xFF0F6B35));
      case 'rejected':
        return (bg: cs.errorContainer, fg: cs.onErrorContainer);
      case 'audit_pending':
        return (bg: const Color(0xFFFFF2DC), fg: const Color(0xFF8F5A00));
      case 'in_progress':
        return (bg: const Color(0xFFE6F0FF), fg: const Color(0xFF1B4E9B));
      case 'assigned':
      case 'verified':
      case 'open':
        return (
          bg: cs.primaryContainer.withValues(alpha: 0.14),
          fg: cs.primary,
        );
      default:
        return (bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = _colors(cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w700,
          color: c.fg,
        ),
      ),
    );
  }
}

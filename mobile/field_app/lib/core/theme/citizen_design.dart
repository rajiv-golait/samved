import 'package:flutter/material.dart';

/// Design system tokens for citizen flow (Stitch / SSR spec).
abstract final class CitizenDesign {
  static const Color primary = Color(0xFF000E24);
  static const Color primaryContainer = Color(0xFF022448);
  static const Color accent = Color(0xFFF97316);
  static const Color surface = Color(0xFFFAF9FD);
  static const Color surfaceContainerLow = Color(0xFFF4F3F7);
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color error = Color(0xFFBA1A1A);
  static const Color outlineVariant = Color(0xFFC4C6CF);
  static const Color tertiaryFixed = Color(0xFFFFDBCA);
  static const Color onTertiaryContainer = Color(0xFFE46500);

  static const Color severityCritical = Color(0xFFBA1A1A);
  static const Color severityHigh = Color(0xFFE46500);
  static const Color severityMedium = Color(0xFF455F87);
  static const Color severityLow = Color(0xFF22C55E);
  static const Color severityResolved = Color(0xFF22C55E);

  static Color severityColor(String? tier) {
    switch ((tier ?? '').toUpperCase()) {
      case 'CRITICAL':
        return severityCritical;
      case 'HIGH':
        return severityHigh;
      case 'MEDIUM':
        return severityMedium;
      case 'LOW':
        return severityLow;
      case 'RESOLVED':
        return severityResolved;
      default:
        return severityMedium;
    }
  }

  static LinearGradient navyGradient = const LinearGradient(
    colors: [Color(0xFF000E24), Color(0xFF022448)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient orangeCtaGradient = const LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

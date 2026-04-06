import 'package:flutter/material.dart';

/// रोड NIRMAN — JE flow design tokens (matches citizen system).
abstract final class JeDesign {
  static const Color background = Color(0xFFFAF9FD);
  static const Color primaryNavy = Color(0xFF000E24);
  static const Color primaryContainer = Color(0xFF022448);
  static const Color accent = Color(0xFFF97316);
  static const Color surfaceContainerLow = Color(0xFFF4F3F7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFE8E8EC);
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF43474E);
  static const Color error = Color(0xFFBA1A1A);
  static const Color tertiaryFixed = Color(0xFFFFDBCA);
  static const Color onTertiaryContainer = Color(0xFFE46500);
  static const Color secondaryContainer = Color(0xFFB5D0FD);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryNavy, primaryContainer],
  );

  static Color severityBarColor(String? tier) {
    switch ((tier ?? '').toUpperCase()) {
      case 'CRITICAL':
        return error;
      case 'HIGH':
        return onTertiaryContainer;
      case 'MEDIUM':
        return const Color(0xFF455F87);
      case 'LOW':
        return const Color(0xFF22C55E);
      default:
        return onSurfaceVariant;
    }
  }

  static Color severityBadgeBg(String? tier) {
    switch ((tier ?? '').toUpperCase()) {
      case 'CRITICAL':
        return error.withValues(alpha: 0.12);
      case 'HIGH':
        return tertiaryFixed;
      case 'MEDIUM':
        return secondaryContainer.withValues(alpha: 0.5);
      default:
        return surfaceContainerLow;
    }
  }

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

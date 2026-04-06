import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ticket_dimensions.dart';

String? embeddedZoneName(Map<String, dynamic> row) {
  final z = row['zones'];
  if (z is Map && z['name'] != null) return z['name'] as String;
  return null;
}

String? embeddedPrabhagName(Map<String, dynamic> row) {
  final p = row['prabhags'];
  if (p is Map && p['name'] != null) return p['name'] as String;
  return null;
}

TicketDimensions? dimsFromRow(Map<String, dynamic> row) =>
    TicketDimensions.fromJson(row['dimensions']);

String initialsFromName(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
  final list = p.toList();
  if (list.isEmpty) return '?';
  if (list.length == 1) {
    return list.first.length >= 2
        ? list.first.substring(0, 2).toUpperCase()
        : list.first.toUpperCase();
  }
  return ('${list.first[0]}${list.last[0]}').toUpperCase();
}

String severityLabel(String? tier) {
  switch ((tier ?? '').toUpperCase()) {
    case 'CRITICAL':
      return 'CRITICAL';
    case 'HIGH':
      return 'HIGH';
    case 'MEDIUM':
      return 'MEDIUM';
    case 'LOW':
      return 'LOW';
    default:
      return (tier ?? '—').toUpperCase();
  }
}

/// Monospace style for IDs / timestamps (JetBrains Mono).
TextStyle mukadamMono(
  double size, {
  FontWeight? weight,
  FontWeight? fontWeight,
  Color? color,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: fontWeight ?? weight,
      color: color,
    );

String formatSubmittedAt(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final am = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m $am';
}

String formatTimeHm(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final am = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $am';
}

String formatDurationHms(Duration d) {
  final t = d.inSeconds;
  final h = (t ~/ 3600).toString().padLeft(2, '0');
  final m = ((t % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (t % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

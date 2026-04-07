import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ticket_dimensions.dart';

String initialsFromText(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '--';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String? zoneName(Map<String, dynamic> row) {
  final z = row['zones'];
  if (z is Map && z['name'] != null) return z['name'] as String;
  return null;
}

String? prabhagName(Map<String, dynamic> row) {
  final p = row['prabhags'];
  if (p is Map && p['name'] != null) return p['name'] as String;
  return null;
}

TicketDimensions? dims(Map<String, dynamic> row) => TicketDimensions.fromJson(row['dimensions']);

TextStyle contractorMono(double size, {Color? color, FontWeight? weight}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

String inr(num? value) {
  final v = (value ?? 0).toDouble();
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts.first;
  final dec = parts.last;
  final b = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final idx = whole.length - i;
    b.write(whole[i]);
    if (idx > 1 && idx % 3 == 1) b.write(',');
  }
  return '₹${b.toString()}.$dec';
}

String formatTimeHm(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final am = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $am';
}

String formatSubmittedAt(DateTime dt) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${m[dt.month - 1]} ${dt.year} · ${formatTimeHm(dt)}';
}

String hms(Duration d) {
  final t = d.inSeconds;
  final h = (t ~/ 3600).toString().padLeft(2, '0');
  final m = ((t % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (t % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

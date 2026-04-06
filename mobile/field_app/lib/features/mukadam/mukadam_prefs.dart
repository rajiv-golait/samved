import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kLang = 'mukadam_lang';
const _kNotifAssignment = 'mukadam_notif_assignment';
const _kNotifJe = 'mukadam_notif_je';
const _kNotifCompletion = 'mukadam_notif_completion';

String mukadamChecklistKey(String ticketId) => 'mukadam_checklist_$ticketId';

Future<List<bool>> loadMukadamChecklist(String ticketId) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(mukadamChecklistKey(ticketId));
  if (raw == null || raw.isEmpty) return [false, false, false, false];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    final out = list.map((e) => e == true).toList();
    while (out.length < 4) {
      out.add(false);
    }
    return out.take(4).toList();
  } catch (_) {
    return [false, false, false, false];
  }
}

Future<void> saveMukadamChecklist(String ticketId, List<bool> items) async {
  final p = await SharedPreferences.getInstance();
  final fixed = items.take(4).toList();
  while (fixed.length < 4) {
    fixed.add(false);
  }
  await p.setString(mukadamChecklistKey(ticketId), jsonEncode(fixed));
}

Future<String> loadMukadamLanguage() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kLang) ?? 'en';
}

Future<void> saveMukadamLanguage(String code) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kLang, code);
}

Future<Map<String, bool>> loadMukadamNotificationPrefs() async {
  final p = await SharedPreferences.getInstance();
  return {
    'assignment': p.getBool(_kNotifAssignment) ?? true,
    'je': p.getBool(_kNotifJe) ?? true,
    'completion': p.getBool(_kNotifCompletion) ?? false,
  };
}

Future<void> saveMukadamNotificationPrefs({
  required bool assignment,
  required bool je,
  required bool completion,
}) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(_kNotifAssignment, assignment);
  await p.setBool(_kNotifJe, je);
  await p.setBool(_kNotifCompletion, completion);
}

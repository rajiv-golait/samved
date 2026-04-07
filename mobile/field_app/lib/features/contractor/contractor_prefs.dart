import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

String _checkKey(String ticketId) => 'contractor_check_$ticketId';

Future<List<bool>> loadContractorChecklist(String ticketId) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(_checkKey(ticketId));
  if (raw == null) return [false, false, false, false];
  try {
    final list = (jsonDecode(raw) as List).map((e) => e == true).toList();
    while (list.length < 4) {
      list.add(false);
    }
    return list.take(4).toList();
  } catch (_) {
    return [false, false, false, false];
  }
}

Future<void> saveContractorChecklist(String ticketId, List<bool> values) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_checkKey(ticketId), jsonEncode(values.take(4).toList()));
}

Future<String> loadContractorLanguage() async {
  final p = await SharedPreferences.getInstance();
  return p.getString('contractor_lang') ?? 'en';
}

Future<void> saveContractorLanguage(String lang) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('contractor_lang', lang);
}

Future<Map<String, bool>> loadContractorNotif() async {
  final p = await SharedPreferences.getInstance();
  return {
    'jobs': p.getBool('contractor_n_jobs') ?? true,
    'payment': p.getBool('contractor_n_payment') ?? true,
    'sla': p.getBool('contractor_n_sla') ?? true,
  };
}

Future<void> saveContractorNotif({
  required bool jobs,
  required bool payment,
  required bool sla,
}) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool('contractor_n_jobs', jobs);
  await p.setBool('contractor_n_payment', payment);
  await p.setBool('contractor_n_sla', sla);
}

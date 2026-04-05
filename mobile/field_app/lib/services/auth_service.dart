import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/zone.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithOtp({required String phoneE164}) async {
    await _client.auth.signInWithOtp(phone: phoneE164);
  }

  /// Whether [phoneE164] already has a Supabase auth user. Null if the RPC failed (e.g. migration not applied).
  Future<bool?> citizenPhoneRegistered(String phoneE164) async {
    try {
      final result = await _client.rpc<dynamic>(
        'citizen_phone_registered',
        params: {'p_phone': phoneE164.trim()},
      );
      if (result is bool) return result;
      return result == true;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResponse> verifyOtp({
    required String phoneE164,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      phone: phoneE164,
      token: token,
      type: OtpType.sms,
    );
  }

  Future<AuthResponse> signInOfficial({
    required String identifier,
    required String password,
  }) {
    final raw = identifier.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final isEmail = raw.contains('@');

    if (isEmail) {
      return _client.auth.signInWithPassword(email: raw, password: password);
    }

    final phone = digits.length == 10
        ? '+91$digits'
        : (digits.startsWith('91') ? '+$digits' : '+$digits');
    return _client.auth.signInWithPassword(phone: phone, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> fetchProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Zone?> fetchZone(int zoneId) async {
    final row = await _client.from('zones').select().eq('id', zoneId).maybeSingle();
    if (row == null) return null;
    return Zone.fromJson(Map<String, dynamic>.from(row));
  }
}

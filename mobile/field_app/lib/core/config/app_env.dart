import 'package:flutter/foundation.dart';

/// Supabase credentials for this app.
///
/// **Release / CI:** pass `--dart-define=SUPABASE_URL=...` and
/// `SUPABASE_ANON_KEY=...` (or `--dart-define-from-file=dart_define.json`).
///
/// **Debug / profile:** if those are omitted, the app falls back to the
/// embedded dev project below so `flutter run` from Android Studio / VS Code
/// works without extra flags. (Anon keys are public client keys; protect with
/// RLS in Supabase. Never ship `service_role` here.)
///
/// Optional: `WEB_DASHBOARD_URL=https://your-dashboard.example`
///
/// **Local file:** `dart_define.json` (gitignored) + `--dart-define-from-file=`
/// overrides the debug defaults when set.
///
/// Do not use placeholder hosts — they are rejected so you get a clear error
/// instead of DNS failures on "Send OTP".
class AppEnv {
  AppEnv._();

  /// Solapur SSR dev project — used only when not in release and env is empty.
  static const String _kDevSupabaseUrl =
      'https://ushkypdtxirrnuwpsign.supabase.co';
  static const String _kDevSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzaGt5cGR0eGlycm51d3BzaWduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUwNDc5NjUsImV4cCI6MjA5MDYyMzk2NX0.vY-pz1pJCvnvhL9niWKI6c5XsNkxPWWZYTkTIfyIGQI';

  static String get supabaseUrl {
    const env = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;
    if (kReleaseMode) return '';
    return _kDevSupabaseUrl;
  }

  static String get supabaseAnonKey {
    const env = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (env.isNotEmpty) return env;
    if (kReleaseMode) return '';
    return _kDevSupabaseAnonKey;
  }

  static const String webDashboardUrl = String.fromEnvironment(
    'WEB_DASHBOARD_URL',
    defaultValue: 'http://localhost:3000',
  );

  static bool _isPlaceholderSupabaseUrl(String url) {
    final u = url.toLowerCase().trim();
    if (u.isEmpty) return true;
    if (u.contains('example.supabase.co')) return true;
    if (u.contains('your_project.supabase.co')) return true;
    if (u.contains('placeholder')) return true;
    return false;
  }

  static bool _isPlaceholderAnonKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return true;
    final lower = k.toLowerCase();
    if (lower.contains('your_anon') || lower == 'anon' || lower == 'key') {
      return true;
    }
    // Real Supabase anon keys are JWT strings, almost always 150+ chars.
    if (k.length < 120) return true;
    return false;
  }

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !_isPlaceholderSupabaseUrl(supabaseUrl) &&
      !_isPlaceholderAnonKey(supabaseAnonKey);

  static String get configError {
    final urlBad = supabaseUrl.isNotEmpty &&
        (_isPlaceholderSupabaseUrl(supabaseUrl) ||
            !supabaseUrl.startsWith('https://'));
    final keyBad = supabaseAnonKey.isNotEmpty &&
        _isPlaceholderAnonKey(supabaseAnonKey);

    if (urlBad) {
      return 'Invalid Supabase URL. You are using a placeholder host (e.g. example.supabase.co), '
          'which does not exist.\n\n'
          'Use your real project URL from the Supabase dashboard (Settings → API), '
          'for example https://abcdefghij.supabase.co\n\n'
          'Rebuild the APK or run:\n'
          'flutter run --dart-define=SUPABASE_URL=https://YOUR_REAL_REF.supabase.co '
          '--dart-define=SUPABASE_ANON_KEY=...';
    }
    if (keyBad) {
      return 'Invalid Supabase anon key. Use the long "anon public" JWT from '
          'Supabase (Settings → API), not a short placeholder.\n\n'
          'flutter build apk --release '
          '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';
    }
    if (kReleaseMode) {
      return 'Missing build configuration. Rebuild with:\n'
          'flutter build apk --release '
          '--dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co '
          '--dart-define=SUPABASE_ANON_KEY=YOUR_LONG_ANON_JWT\n\n'
          'Or: --dart-define-from-file=dart_define.json';
    }
    return 'Missing Supabase config.\n\n'
        'Easiest: copy dart_define.example.json → dart_define.json (fill real URL + anon key), '
        'then from samved/mobile/field_app run:\n'
        'flutter run --dart-define-from-file=dart_define.json\n\n'
        'Or one-liner:\n'
        'flutter run '
        '--dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=YOUR_LONG_ANON_JWT';
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';

class DetectOutcome {
  const DetectOutcome({
    required this.success,
    this.detected = false,
    this.damageType = 'unknown',
    this.aiConfidence = 0.0,
    this.totalPotholes = 0,
    this.aiSeverityIndex = 0.0,
    this.aiSource = 'OFFLINE_ESTIMATE',
    this.errors = const [],
  });

  final bool success;
  final bool detected;
  final String damageType;
  final double aiConfidence;
  final int totalPotholes;
  final double aiSeverityIndex;
  final String aiSource;
  final List<String> errors;

  factory DetectOutcome.fromJson(Map<String, dynamic> j) {
    return DetectOutcome(
      success: j['success'] as bool? ?? false,
      detected: j['detected'] as bool? ?? false,
      damageType: j['damage_type'] as String? ?? 'unknown',
      aiConfidence: (j['ai_confidence'] as num?)?.toDouble() ?? 0,
      totalPotholes: (j['total_potholes'] as num?)?.toInt() ?? 0,
      aiSeverityIndex: (j['ai_severity_index'] as num?)?.toDouble() ?? 0,
      aiSource: j['ai_source'] as String? ?? 'OFFLINE_ESTIMATE',
      errors: (j['errors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class SeverityOutcome {
  const SeverityOutcome({
    required this.success,
    this.epdoScore = 0.0,
    this.severityTier = 'LOW',
    this.slaHours = 48,
    this.errors = const [],
  });

  final bool success;
  final double epdoScore;
  final String severityTier;
  final int slaHours;
  final List<String> errors;

  factory SeverityOutcome.fromJson(Map<String, dynamic> j) {
    return SeverityOutcome(
      success: j['success'] as bool? ?? false,
      epdoScore: (j['epdo_score'] as num?)?.toDouble() ?? 0,
      severityTier: j['severity_tier'] as String? ?? 'LOW',
      slaHours: (j['sla_hours'] as num?)?.toInt() ?? 48,
      errors: (j['errors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class CitizenAiService {
  CitizenAiService(this._client);

  final SupabaseClient _client;

  /// Cached result of last SSR AI health check (avoid duplicate GETs in one session).
  static String? _healthBase;
  static String? _healthCacheOk;
  static String? _healthCacheErr;

  String _base() => AppConstants.aiServiceUrl.replaceAll(RegExp(r'/$'), '');

  /// Our FastAPI `/health` returns JSON with `status` and `model_loaded`. Anything
  /// else (plain "OK", HTML, 404) means [AppConstants.aiServiceUrl] is not the
  /// deployed `samved/ai-service` — e.g. wrong Railway service on the hostname.
  Future<String?> validateSsrAiServiceHealth() async {
    final base = _base();
    if (_healthBase != base) {
      _healthBase = base;
      _healthCacheOk = null;
      _healthCacheErr = null;
    }
    if (_healthCacheOk != null) return null;
    if (_healthCacheErr != null) return _healthCacheErr;

    final uri = Uri.parse('$base/health');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        _healthCacheErr =
            'AI server health check failed (HTTP ${r.statusCode}). Check AI_SERVICE_URL.';
        return _healthCacheErr;
      }
      final raw = r.body.trim();
      if (raw.isEmpty) {
        _healthCacheErr = _misconfiguredHostMessage();
        return _healthCacheErr;
      }
      final Map<String, dynamic> j;
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is! Map<String, dynamic>) {
          _healthCacheErr = _misconfiguredHostMessage();
          return _healthCacheErr;
        }
        j = decoded;
      } catch (_) {
        _healthCacheErr = _misconfiguredHostMessage();
        return _healthCacheErr;
      }
      if (j['status']?.toString() != 'ok') {
        _healthCacheErr = _misconfiguredHostMessage();
        return _healthCacheErr;
      }
      _healthCacheOk = 'ok';
      return null;
    } catch (e) {
      _healthCacheErr = 'Cannot reach AI service at ${uri.origin}: $e';
      return _healthCacheErr;
    }
  }

  String _misconfiguredHostMessage() {
    return 'This URL does not run रोड NIRMAN FastAPI (expected JSON /health with '
        '"status":"ok"). The default host may be the wrong Railway deployment. '
        'Deploy samved/ai-service to Railway (or run it locally), then set '
        '--dart-define=AI_SERVICE_URL=<your-url>';
  }

  Future<http.Response> _postWithFallback({
    required List<String> paths,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required Duration timeout,
  }) async {
    http.Response? last;
    for (final p in paths) {
      final path = p.startsWith('/') ? p.substring(1) : p;
      final uri = Uri.parse('${_base()}/$path');
      final resp = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      last = resp;
      if (resp.statusCode != 404) return resp;
    }
    return last!;
  }

  Future<String> uploadScanImage(File imageFile) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    // Must match storage RLS: ticket-photos/before/{uid}_...
    final name = '${uid}_citizen_scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'before/$name';
    await _client.storage.from('ticket-photos').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('ticket-photos').getPublicUrl(path);
  }

  Future<DetectOutcome> detectRoadDamage(String imagePublicUrl) async {
    final healthErr = await validateSsrAiServiceHealth();
    if (healthErr != null) {
      return DetectOutcome(success: false, errors: [healthErr]);
    }

    final resp = await _postWithFallback(
      paths: const [
        'detect-road-damage',
        'api/detect-road-damage',
        'v1/detect-road-damage',
        'api/v1/detect-road-damage',
      ],
      headers: {
        'Content-Type': 'application/json',
        'X-SSR-Secret': AppConstants.aiServiceSecret,
      },
      body: {
        'image_url': imagePublicUrl,
        'source_channel': 'app',
      },
      timeout: const Duration(seconds: 45),
    );
    if (resp.statusCode != 200) {
      final detail = resp.body;
      final extra = resp.statusCode == 404
          ? ' (endpoint missing — if /health is JSON OK, open a GitHub issue with your deploy URL)'
          : '';
      return DetectOutcome(
        success: false,
        errors: ['HTTP ${resp.statusCode}$extra: $detail'],
      );
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return DetectOutcome.fromJson(j);
  }

  Future<SeverityOutcome> scoreSeverity({
    required String damageType,
    required double aiConfidence,
    required int totalPotholes,
    required double aiSeverityIndex,
    required double lat,
    required double lng,
  }) async {
    final healthErr = await validateSsrAiServiceHealth();
    if (healthErr != null) {
      return SeverityOutcome(success: false, errors: [healthErr]);
    }

    final resp = await _postWithFallback(
      paths: const [
        'score-severity',
        'api/score-severity',
        'v1/score-severity',
        'api/v1/score-severity',
      ],
      headers: {
        'Content-Type': 'application/json',
        'X-SSR-Secret': AppConstants.aiServiceSecret,
      },
      body: {
        'damage_type': damageType,
        'ai_confidence': aiConfidence,
        'total_potholes': totalPotholes,
        'ai_severity_index': aiSeverityIndex,
        'road_class': 'local',
        'proximity_score': 0.5,
        'lat': lat,
        'lng': lng,
      },
      timeout: const Duration(seconds: 30),
    );
    if (resp.statusCode != 200) {
      final extra = resp.statusCode == 404
          ? ' (score-severity path missing on this host)'
          : '';
      return SeverityOutcome(
        success: false,
        errors: ['HTTP ${resp.statusCode}$extra: ${resp.body}'],
      );
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return SeverityOutcome.fromJson(j);
  }
}

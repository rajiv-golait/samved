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

  String _base() => AppConstants.aiServiceUrl.replaceAll(RegExp(r'/$'), '');

  Future<String> uploadScanImage(File imageFile) async {
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final name = 'citizen_scan_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('ticket-photos').upload(
          name,
          imageFile,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('ticket-photos').getPublicUrl(name);
  }

  Future<DetectOutcome> detectRoadDamage(String imagePublicUrl) async {
    final uri = Uri.parse('${_base()}/detect-road-damage');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-SSR-Secret': AppConstants.aiServiceSecret,
          },
          body: jsonEncode({
            'image_url': imagePublicUrl,
            'source_channel': 'app',
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (resp.statusCode != 200) {
      return DetectOutcome(
        success: false,
        errors: ['HTTP ${resp.statusCode}: ${resp.body}'],
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
    final uri = Uri.parse('${_base()}/score-severity');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-SSR-Secret': AppConstants.aiServiceSecret,
          },
          body: jsonEncode({
            'damage_type': damageType,
            'ai_confidence': aiConfidence,
            'total_potholes': totalPotholes,
            'ai_severity_index': aiSeverityIndex,
            'road_class': 'local',
            'proximity_score': 0.5,
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      return SeverityOutcome(
        success: false,
        errors: ['HTTP ${resp.statusCode}: ${resp.body}'],
      );
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return SeverityOutcome.fromJson(j);
  }
}

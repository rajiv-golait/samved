import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/citizen_ai_service.dart';
import 'providers.dart';

const _kActiveStatusesForMap = [
  'open',
  'verified',
  'assigned',
  'in_progress',
  'audit_pending',
  'escalated',
  'cross_assigned',
];

/// Open / active tickets for map pins (not resolved/rejected).
final citizenMapPinsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('tickets')
      .select(
        'id, latitude, longitude, severity_tier, status, ticket_ref',
      )
      .inFilter('status', _kActiveStatusesForMap);

  final list = (rows as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  return list
      .where((m) => m['latitude'] != null && m['longitude'] != null)
      .toList();
});

/// Nearby sheet: same status filter, optional zone, sorted by EPDO.
final citizenNearbyTicketsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return [];

  var query = client
      .from('tickets')
      .select(
        'id, ticket_ref, severity_tier, latitude, longitude, address_text, road_name, photo_before, epdo_score, status',
      )
      .inFilter('status', _kActiveStatusesForMap);

  if (profile.zoneId != null) {
    query = query.eq('zone_id', profile.zoneId!);
  }

  final rows = await query.order('epdo_score', ascending: false).limit(20);
  return (rows as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
});

final citizenAiServiceProvider = Provider<CitizenAiService>(
  (ref) => CitizenAiService(ref.watch(supabaseClientProvider)),
);

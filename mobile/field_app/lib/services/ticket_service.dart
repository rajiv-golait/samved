import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ticket.dart';
import '../models/ticket_dimensions.dart';

class MukadamOption {
  const MukadamOption({required this.id, required this.fullName});
  final String id;
  final String fullName;
}

class ContractorOption {
  const ContractorOption({required this.id, required this.companyName});
  final String id;
  final String companyName;
}

class MukadamHomeSnapshot {
  const MukadamHomeSnapshot({
    required this.rows,
    required this.jeNames,
    required this.completedThisWeekCount,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, String> jeNames;
  final int completedThisWeekCount;

  static MukadamHomeSnapshot empty() => const MukadamHomeSnapshot(
        rows: [],
        jeNames: {},
        completedThisWeekCount: 0,
      );
}

class ContractorHomeSnapshot {
  const ContractorHomeSnapshot({
    required this.rows,
    required this.jeNames,
    required this.pendingAmount,
    required this.pendingCount,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, String> jeNames;
  final double pendingAmount;
  final int pendingCount;

  static ContractorHomeSnapshot empty() => const ContractorHomeSnapshot(
        rows: [],
        jeNames: {},
        pendingAmount: 0,
        pendingCount: 0,
      );
}

class TicketService {
  TicketService(this._client);

  final SupabaseClient _client;

  Future<List<Ticket>> fetchCitizenTickets() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('tickets')
        .select()
        .eq('citizen_id', uid)
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Ticket>> fetchJeZoneTickets(int zoneId) async {
    final rows = await _client
        .from('tickets')
        .select(
          'id, ticket_ref, status, severity_tier, latitude, longitude, address_text, '
          'road_name, epdo_score, created_at, updated_at, zone_id, prabhag_id, '
          'department_id, citizen_id, citizen_phone, citizen_name, source_channel, '
          'photo_before, photo_after, assigned_je, assigned_contractor, assigned_mukadam, '
          'je_checkin_time, dimensions, work_type, rate_card_id, rate_per_unit, '
          'estimated_cost, job_order_ref, ai_confidence, total_potholes',
        )
        .eq('zone_id', zoneId)
        .not('status', 'in', '(resolved,rejected)')
        .order('epdo_score', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Ticket>> fetchMukadamTickets() async {
    final snap = await fetchMukadamHomeSnapshot();
    return snap.rows
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Mukadam work orders (dept gang only — no contractor assignment). No financial columns.
  Future<MukadamHomeSnapshot> fetchMukadamHomeSnapshot() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return MukadamHomeSnapshot.empty();

    const selectCols = '''
id, ticket_ref, status, severity_tier, address_text, work_type, dimensions,
created_at, updated_at, assigned_je, assigned_contractor, photo_before, je_checkin_time,
zone_id, prabhag_id, latitude, longitude, department_id, source_channel,
zones ( name ), prabhags ( name )
''';

    final raw = await _client
        .from('tickets')
        .select(selectCols)
        .eq('assigned_mukadam', uid)
        .inFilter('status', ['assigned', 'in_progress', 'audit_pending'])
        .order('created_at', ascending: false);

    final list = (raw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => m['assigned_contractor'] == null)
        .toList();

    final jeIds = list
        .map((m) => m['assigned_je'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final jeNames = <String, String>{};
    if (jeIds.isNotEmpty) {
      final pr = await _client.from('profiles').select('id, full_name').inFilter('id', jeIds);
      for (final p in pr as List<dynamic>) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['id'] as String?;
        if (id != null) {
          jeNames[id] = m['full_name'] as String? ?? '';
        }
      }
    }

    final weekAgo =
        DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
    final weekRows = await _client
        .from('tickets')
        .select('id, assigned_contractor')
        .eq('assigned_mukadam', uid)
        .inFilter('status', ['audit_pending', 'resolved'])
        .gte('updated_at', weekAgo);
    final weekFiltered = (weekRows as List<dynamic>)
        .where((e) => (e as Map<String, dynamic>)['assigned_contractor'] == null)
        .length;

    return MukadamHomeSnapshot(
      rows: list,
      jeNames: jeNames,
      completedThisWeekCount: weekFiltered,
    );
  }

  Future<int> countMukadamJobsThisWeek() async {
    final snap = await fetchMukadamHomeSnapshot();
    return snap.completedThisWeekCount;
  }

  /// Detail payload for Mukadam (no rate/cost/job_order fields).
  Future<Map<String, dynamic>?> fetchMukadamTicketDetail(String ticketId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    const selectCols = '''
id, ticket_ref, status, severity_tier, address_text, work_type, dimensions,
photo_before, je_checkin_time, latitude, longitude, assigned_je, assigned_mukadam,
assigned_contractor, created_at, updated_at,
zones ( name ), prabhags ( name )
''';
    final row = await _client
        .from('tickets')
        .select(selectCols)
        .eq('id', ticketId)
        .eq('assigned_mukadam', uid)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    if (m['assigned_contractor'] != null) return null;
    return m;
  }

  Future<Map<String, dynamic>?> fetchProfileById(String profileId) async {
    final row = await _client
        .from('profiles')
        .select('id, full_name, phone')
        .eq('id', profileId)
        .maybeSingle();
    return row != null ? Map<String, dynamic>.from(row) : null;
  }

  Future<String?> fetchLatestJeCheckinNotes(String ticketId) async {
    final rows = await _client
        .from('ticket_events')
        .select('notes, created_at')
        .eq('ticket_id', ticketId)
        .eq('event_type', 'je_checkin')
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return list.first['notes'] as String?;
  }

  Future<int?> fetchSlaResolutionHours(String? severityTier) async {
    if (severityTier == null || severityTier.isEmpty) return null;
    final row = await _client
        .from('sla_config')
        .select('resolution_hours')
        .eq('severity', severityTier)
        .maybeSingle();
    if (row == null) return null;
    return (row['resolution_hours'] as num?)?.toInt();
  }

  Future<Map<String, dynamic>?> fetchMukadamTicketForCamera(String ticketId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('tickets')
        .select('id, status, photo_before, assigned_mukadam, assigned_contractor')
        .eq('id', ticketId)
        .eq('assigned_mukadam', uid)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    if (m['assigned_contractor'] != null) return null;
    return m;
  }

  Future<void> mukadamStartGangDeployment({
    required String ticketId,
    required String mukadamFullName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    final detail = await fetchMukadamTicketDetail(ticketId);
    if (detail == null) throw StateError('Ticket unavailable');
    if (detail['status'] != 'assigned') {
      throw StateError('Work order is not in Assigned state.');
    }

    await _client.from('tickets').update({
      'status': 'in_progress',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ticketId);

    await _client.from('ticket_events').insert({
      'ticket_id': ticketId,
      'actor_id': uid,
      'actor_role': 'mukadam',
      'event_type': 'status_change',
      'old_status': 'assigned',
      'new_status': 'in_progress',
      'notes': 'Gang deployment started by Mukadam $mukadamFullName',
      'metadata': {'started_at': DateTime.now().toUtc().toIso8601String()},
    });
  }

  Future<String> mukadamUploadCompletionProof({
    required String ticketId,
    required Uint8List imageBytes,
    String? fieldNotes,
    required String mukadamFullName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');

    final cam = await fetchMukadamTicketForCamera(ticketId);
    if (cam == null) throw StateError('Ticket unavailable');
    if (cam['status'] != 'in_progress') {
      throw StateError('Submit proof only while work is in progress.');
    }

    final name =
        '${uid}_mukadam_${ticketId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'after/$name';
    await _client.storage.from('after-photos').uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final photoUrl = _client.storage.from('after-photos').getPublicUrl(path);

    await _client.from('tickets').update({
      'photo_after': photoUrl,
      'status': 'audit_pending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ticketId);

    final note = fieldNotes != null && fieldNotes.trim().isNotEmpty
        ? fieldNotes.trim()
        : 'Completion proof submitted by Mukadam';

    await _client.from('ticket_events').insert({
      'ticket_id': ticketId,
      'actor_id': uid,
      'actor_role': 'mukadam',
      'event_type': 'photo_upload',
      'old_status': 'in_progress',
      'new_status': 'audit_pending',
      'notes': note,
      'metadata': {
        'submitted_by': mukadamFullName,
        'photo_url': photoUrl,
      },
    });

    return photoUrl;
  }

  Future<List<Ticket>> fetchContractorTickets() async {
    final snap = await fetchContractorHomeSnapshot();
    return snap.rows
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ContractorHomeSnapshot> fetchContractorHomeSnapshot() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return ContractorHomeSnapshot.empty();

    const selectCols = '''
id, ticket_ref, status, severity_tier, address_text, road_name, work_type, dimensions,
estimated_cost, rate_per_unit, job_order_ref, created_at, updated_at, assigned_je,
assigned_mukadam, assigned_contractor, zone_id, prabhag_id,
zones ( name ), prabhags ( name )
''';

    final raw = await _client
        .from('tickets')
        .select(selectCols)
        .eq('assigned_contractor', uid)
        .inFilter('status', ['assigned', 'in_progress', 'audit_pending', 'resolved'])
        .order('created_at', ascending: false);

    final rows = (raw as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => m['assigned_mukadam'] == null)
        .toList();

    final jeIds = rows
        .map((m) => m['assigned_je'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final jeNames = <String, String>{};
    if (jeIds.isNotEmpty) {
      final prs =
          await _client.from('profiles').select('id, full_name').inFilter('id', jeIds);
      for (final p in prs as List<dynamic>) {
        final m = Map<String, dynamic>.from(p as Map);
        final id = m['id'] as String?;
        if (id != null) {
          jeNames[id] = m['full_name'] as String? ?? '';
        }
      }
    }

    double pendingAmount = 0;
    int pendingCount = 0;
    for (final row in rows) {
      if (row['status'] == 'audit_pending') {
        pendingCount += 1;
        pendingAmount += (row['estimated_cost'] as num?)?.toDouble() ?? 0;
      }
    }

    return ContractorHomeSnapshot(
      rows: rows,
      jeNames: jeNames,
      pendingAmount: pendingAmount,
      pendingCount: pendingCount,
    );
  }

  Future<Map<String, dynamic>?> fetchContractorTicketDetail(String ticketId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    const selectCols = '''
id, ticket_ref, status, severity_tier, address_text, road_name, work_type, dimensions,
estimated_cost, rate_per_unit, job_order_ref, created_at, updated_at, assigned_je,
assigned_mukadam, assigned_contractor, photo_before, photo_after, verification_hash,
ssim_score, ssim_pass, latitude, longitude,
zones ( name ), prabhags ( name ),
je:profiles!tickets_assigned_je_fkey ( id, full_name, phone )
''';
    final row = await _client
        .from('tickets')
        .select(selectCols)
        .eq('id', ticketId)
        .eq('assigned_contractor', uid)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    if (m['assigned_mukadam'] != null) return null;
    return m;
  }

  Future<void> contractorStartWork({
    required String ticketId,
    required String companyName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    final detail = await fetchContractorTicketDetail(ticketId);
    if (detail == null) throw StateError('Ticket unavailable');
    if (detail['status'] != 'assigned') {
      throw StateError('Only assigned work orders can be started.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('tickets').update({
      'status': 'in_progress',
      'updated_at': now,
    }).eq('id', ticketId);
    await _client.from('ticket_events').insert({
      'ticket_id': ticketId,
      'actor_id': uid,
      'actor_role': 'contractor',
      'event_type': 'status_change',
      'old_status': 'assigned',
      'new_status': 'in_progress',
      'notes': 'Work started by contractor $companyName',
      'metadata': {'started_at': now},
    });
  }

  Future<(String photoUrl, String hash)> contractorUploadProof({
    required String ticketId,
    required Uint8List imageBytes,
    required String hash,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    final detail = await fetchContractorTicketDetail(ticketId);
    if (detail == null) throw StateError('Ticket unavailable');
    if (detail['status'] != 'in_progress') {
      throw StateError('Submit proof only while job is in progress.');
    }
    final path = 'after/${uid}_${ticketId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('after-photos').uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final photoUrl = _client.storage.from('after-photos').getPublicUrl(path);
    await _client.from('tickets').update({
      'photo_after': photoUrl,
      'status': 'audit_pending',
      'verification_hash': hash,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ticketId);
    await _client.from('ticket_events').insert({
      'ticket_id': ticketId,
      'actor_id': uid,
      'actor_role': 'contractor',
      'event_type': 'photo_upload',
      'old_status': 'in_progress',
      'new_status': 'audit_pending',
      'notes': 'Proof of repair submitted by contractor. SHA-256: ${hash.substring(0, 16)}...',
      'metadata': {'photo_url': photoUrl, 'verification_hash': hash},
    });
    return (photoUrl, hash);
  }

  Future<Map<String, dynamic>?> fetchContractorProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('contractors')
        .select(
            'id, company_name, gst_number, pan_number, zone_ids, contract_number, contract_start, contract_end, is_blacklisted, profiles!contractors_id_fkey(full_name, phone)')
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> fetchZonesByIds(List<int> zoneIds) async {
    if (zoneIds.isEmpty) return [];
    final rows = await _client.from('zones').select('id, name').inFilter('id', zoneIds);
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Ticket?> fetchTicket(String id) async {
    final row = await _client.from('tickets').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Ticket.fromJson(Map<String, dynamic>.from(row));
  }

  /// Citizen creates a ticket. `location` must be EWKT — PostgREST casts text
  /// to `geography`; a GeoJSON map is parsed as WKT and fails with "invalid geometry".
  Future<String> createCitizenTicket({
    required String citizenPhone,
    String? citizenName,
    required double lat,
    required double lng,
    required List<String> photoBeforeUrls,
    String? addressText,
    String? nearestLandmark,
    String? damageType,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final locationEwkt =
        'SRID=4326;POINT(${lng.toStringAsFixed(7)} ${lat.toStringAsFixed(7)})';
    final payload = <String, dynamic>{
      'citizen_id': uid,
      'citizen_phone': citizenPhone,
      'citizen_name': citizenName,
      'source_channel': 'app',
      'latitude': lat,
      'longitude': lng,
      'location': locationEwkt,
      'photo_before': photoBeforeUrls,
      'address_text': addressText,
      'nearest_landmark': nearestLandmark,
      'damage_type': damageType,
      'department_id': 1,
    };
    final inserted =
        await _client.from('tickets').insert(payload).select('id').single();
    return inserted['id'] as String;
  }

  Future<void> updateJeCheckIn({
    required String ticketId,
    required double lat,
    required double lng,
    required double distanceM,
  }) async {
    await _client.from('tickets').update({
      'je_checkin_lat': lat,
      'je_checkin_lng': lng,
      'je_checkin_time': DateTime.now().toUtc().toIso8601String(),
      'je_checkin_distance_m': distanceM,
    }).eq('id', ticketId);
  }

  Future<void> updateJeMeasure({
    required String ticketId,
    required TicketDimensions dimensions,
    required String workType,
    required String rateCardId,
    required double ratePerUnit,
    required double estimatedCost,
  }) async {
    await _client.from('tickets').update({
      'dimensions': dimensions.toJson(),
      'work_type': workType,
      'rate_card_id': rateCardId,
      'rate_per_unit': ratePerUnit,
      'estimated_cost': estimatedCost,
      'status': 'verified',
    }).eq('id', ticketId);
  }

  Future<void> assignExecutor({
    required String ticketId,
    required String ticketRef,
    String? assignedMukadam,
    String? assignedContractor,
  }) async {
    assert(
      (assignedMukadam != null) ^ (assignedContractor != null),
      'XOR executor',
    );
    final jobRef = 'JO-${ticketRef.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-')}-${ticketId.substring(0, 8)}';
    await _client.from('tickets').update({
      'assigned_mukadam': assignedMukadam,
      'assigned_contractor': assignedContractor,
      'status': 'assigned',
      'job_order_ref': jobRef,
    }).eq('id', ticketId);
  }

  Future<void> startWork(String ticketId) async {
    await _client.from('tickets').update({
      'status': 'in_progress',
    }).eq('id', ticketId);
  }

  Future<void> submitExecutionProof({
    required String ticketId,
    required String afterPhotoUrl,
  }) async {
    await _client.from('tickets').update({
      'photo_after': afterPhotoUrl,
      'status': 'audit_pending',
    }).eq('id', ticketId);
  }

  Future<List<MukadamOption>> listMukadamsInZone(int zoneId) async {
    final rows = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'mukadam')
        .eq('zone_id', zoneId)
        .eq('is_active', true)
        .order('full_name');
    return (rows as List<dynamic>)
        .map(
          (e) => MukadamOption(
            id: (e as Map)['id'] as String,
            fullName: (e)['full_name'] as String? ?? 'Mukadam',
          ),
        )
        .toList();
  }

  Future<List<ContractorOption>> listContractorsInZone(int zoneId) async {
    final rows = await _client.from('contractors').select('id, company_name, zone_ids');
    final list = rows as List<dynamic>;
    final out = <ContractorOption>[];
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final ids = m['zone_ids'];
      if (ids is! List) continue;
      final z = ids.map((e) => (e as num).toInt()).toList();
      if (!z.contains(zoneId)) continue;
      out.add(ContractorOption(
        id: m['id'] as String,
        companyName: m['company_name'] as String? ?? 'Contractor',
      ));
    }
    out.sort((a, b) => a.companyName.compareTo(b.companyName));
    return out;
  }
}

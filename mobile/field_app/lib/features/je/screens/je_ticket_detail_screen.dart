import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/status_labels.dart';
import '../../../core/theme/je_design.dart';
import '../../../providers/providers.dart';

class JeTicketDetailScreen extends ConsumerStatefulWidget {
  const JeTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<JeTicketDetailScreen> createState() => _JeTicketDetailScreenState();
}

class _JeTicketDetailScreenState extends ConsumerState<JeTicketDetailScreen> {
  Map<String, dynamic>? _row;
  String? _citizenName;
  String? _jeName;
  bool _loading = true;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: JeDesign.error, content: Text(msg)),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final row = await supa
          .from('tickets')
          .select('''
            id, ticket_ref, status, severity_tier,
            latitude, longitude, address_text,
            ai_confidence, epdo_score, total_potholes,
            photo_before, source_channel,
            je_checkin_time,
            zone_id, prabhag_id, citizen_id, assigned_je, department_id,
            created_at,
            zones ( name ),
            prabhags ( name ),
            departments ( name, map_pin_color )
          ''')
          .eq('id', widget.ticketId)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() => _row = null);
        return;
      }

      final citizenId = row['citizen_id'] as String?;
      if (citizenId != null) {
        final pr = await supa.from('profiles').select('full_name').eq('id', citizenId).maybeSingle();
        _citizenName = pr?['full_name'] as String?;
      }
      final assignedJe = row['assigned_je'] as String?;
      if (assignedJe != null) {
        final jp = await supa.from('profiles').select('full_name').eq('id', assignedJe).maybeSingle();
        _jeName = jp?['full_name'] as String?;
      }

      setState(() => _row = Map<String, dynamic>.from(row));
    } catch (e) {
      _snack('Could not load ticket: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final u = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _reject() async {
    final row = _row;
    if (row == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject complaint?'),
        content: const Text('This will mark the ticket as rejected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final oldStatus = row['status'] as String? ?? 'open';
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Not signed in');

      await supa.from('tickets').update({
        'status': 'rejected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);

      await supa.from('ticket_events').insert({
        'ticket_id': widget.ticketId,
        'actor_id': uid,
        'actor_role': 'je',
        'event_type': 'status_change',
        'old_status': oldStatus,
        'new_status': 'rejected',
        'notes': 'Rejected by JE after review',
      });

      if (mounted) context.go('/je/home');
    } catch (e) {
      _snack('Reject failed: $e');
    }
  }

  Future<void> _changeDepartment() async {
    final supa = Supabase.instance.client;
    try {
      final deps = await supa.from('departments').select('id, name, map_pin_color').order('id');
      if (!mounted) return;
      final list = (deps as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => ListView(
          children: list
              .map(
                (d) => ListTile(
                  title: Text(d['name'] as String? ?? ''),
                  onTap: () => Navigator.pop(ctx, d),
                ),
              )
              .toList(),
        ),
      );
      if (picked == null) return;
      await supa.from('tickets').update({
        'department_id': picked['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Department updated')),
        );
      }
    } catch (e) {
      _snack('Could not update department: $e');
    }
  }

  int _hoursAgo(String? iso) {
    if (iso == null) return 0;
    try {
      final t = DateTime.parse(iso).toUtc();
      return DateTime.now().toUtc().difference(t).inHours;
    } catch (_) {
      return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    if (_loading) {
      return const Scaffold(
        backgroundColor: JeDesign.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_row == null) {
      return Scaffold(
        backgroundColor: JeDesign.background,
        appBar: AppBar(backgroundColor: JeDesign.background, title: const Text('Ticket')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final row = _row!;
    final photos = row['photo_before'];
    final List<String> urls = photos is List ? photos.map((e) => e.toString()).toList() : [];
    final heroUrl = urls.isNotEmpty ? urls.first : null;
    final tier = (row['severity_tier'] as String? ?? '').toUpperCase();
    final lat = (row['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (row['longitude'] as num?)?.toDouble() ?? 0;
    final zoneName = (row['zones'] is Map ? (row['zones'] as Map)['name'] : null) as String? ?? '—';
    final prabhagName =
        (row['prabhags'] is Map ? (row['prabhags'] as Map)['name'] : null) as String? ?? '—';
    final dept = row['departments'];
    final deptName = dept is Map ? dept['name'] as String? : null;
    final conf = (row['ai_confidence'] as num?)?.toDouble();
    final epdo = (row['epdo_score'] as num?)?.toDouble();
    final potholes = row['total_potholes'] as int?;
    final checkin = row['je_checkin_time'];
    final profile = profileAsync.asData?.value;

    return Scaffold(
      backgroundColor: JeDesign.background,
      appBar: AppBar(
        backgroundColor: JeDesign.background,
        elevation: 0,
        foregroundColor: JeDesign.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          row['ticket_ref'] as String? ?? '',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: row['ticket_ref'] as String? ?? ''));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ticket reference copied')),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/je/checkin/${widget.ticketId}'),
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: JeDesign.primaryGradient,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: JeDesign.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Begin Site Check-In',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _reject,
                child: Text(
                  'REJECT COMPLAINT',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: JeDesign.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: JeDesign.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SSR TICKET',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: JeDesign.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (heroUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(heroUrl, fit: BoxFit.cover),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: JeDesign.tertiaryFixed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$tier SEVERITY',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: JeDesign.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: Colors.black54,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_outlined,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Citizen Evidence',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'रोड NIRMAN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: JeDesign.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: JeDesign.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: JeDesign.primaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel(row['status'] as String? ?? 'open'),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'JE: ${_jeName ?? profile?.fullName ?? '—'}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: JeDesign.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JeDesign.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: JeDesign.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ZONE',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: JeDesign.onSurfaceVariant)),
                            Text(zoneName,
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRABHAG',
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: JeDesign.onSurfaceVariant)),
                            Text(prabhagName,
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    row['address_text'] as String? ?? '—',
                    style: GoogleFonts.inter(height: 1.4),
                  ),
                  TextButton(
                    onPressed: () => _openMaps(lat, lng),
                    child: Text(
                      'View on Map →',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: JeDesign.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JeDesign.secondaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: JeDesign.primaryContainer, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI ANALYSIS ENGINE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: JeDesign.primaryContainer,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: JeDesign.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ROBOFLOW_API',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _aiStat('Potholes', '${potholes ?? '—'}')),
                      Expanded(
                        child: _aiStat(
                          'Confidence',
                          conf != null ? '${(conf * 100).round()}%' : '—',
                        ),
                      ),
                      Expanded(
                        child: _aiStat(
                          'EPDO',
                          epdo != null ? epdo.toStringAsFixed(2) : '—',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '* AI data is preliminary. Field verify required.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: JeDesign.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: JeDesign.surfaceContainerHigh,
                  child: Icon(Icons.person, color: JeDesign.primaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reported by ${_citizenName ?? 'Citizen'}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${_hoursAgo(row['created_at'] as String?)} hours ago via ${row['source_channel'] ?? 'app'}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: JeDesign.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: JeDesign.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'SOURCE: ${(row['source_channel'] as String? ?? 'APP').toUpperCase()}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCDD2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (deptName ?? 'ROADS').toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _changeDepartment,
                  child: Text(
                    'Change Department →',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: JeDesign.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JeDesign.onSurfaceVariant.withValues(alpha: 0.25)),
              ),
              child: checkin == null
                  ? Column(
                      children: [
                        Text(
                          'JE FIELD NOTES (READ ONLY)',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            color: JeDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Icon(Icons.note_alt_outlined, size: 40, color: JeDesign.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Notes will be available after Site Check-In...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: JeDesign.onSurfaceVariant),
                        ),
                      ],
                    )
                  : Text(
                      'Site check-in recorded.',
                      style: GoogleFonts.inter(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JeDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: JeDesign.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

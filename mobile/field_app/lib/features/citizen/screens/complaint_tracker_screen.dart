import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/citizen_design.dart';
import '../widgets/citizen_bottom_nav.dart';

int trackerActiveStep(String status) {
  switch (status) {
    case 'open':
      return 0;
    case 'verified':
      return 1;
    case 'assigned':
    case 'in_progress':
      return 2;
    case 'audit_pending':
      return 3;
    case 'resolved':
      return 4;
    default:
      return 0;
  }
}

const _kCitizenTrackerSteps = [
  'Received',
  'Verified',
  'JE Inspection',
  'Repair Assigned',
  'Resolved',
];

class ComplaintTrackerScreen extends ConsumerStatefulWidget {
  const ComplaintTrackerScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<ComplaintTrackerScreen> createState() => _ComplaintTrackerScreenState();
}

class _ComplaintTrackerScreenState extends ConsumerState<ComplaintTrackerScreen> {
  RealtimeChannel? _ch;
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _latestEvent;
  String? _zoneName;
  String? _prabhagName;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    try {
      final t = await client.from('tickets').select('''
            id, ticket_ref, status, severity_tier, address_text, road_name,
            latitude, longitude, created_at, resolved_at, epdo_score,
            zone_id, prabhag_id, updated_at
            ''').eq('id', widget.ticketId).maybeSingle();

      if (t == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Ticket not found';
          });
        }
        return;
      }

      Map<String, dynamic>? ev;
      try {
        final evRows = await client
            .from('ticket_events')
            .select('event_type, notes, created_at, actor_role')
            .eq('ticket_id', widget.ticketId)
            .order('created_at', ascending: false)
            .limit(1);
        if (evRows.isNotEmpty) {
          ev = Map<String, dynamic>.from(evRows.first as Map);
        }
      } catch (_) {}

      final zid = t['zone_id'] as int?;
      final pid = t['prabhag_id'] as int?;
      if (zid != null) {
        try {
          final z = await client.from('zones').select('name').eq('id', zid).maybeSingle();
          _zoneName = z?['name'] as String?;
        } catch (_) {}
      }
      if (pid != null) {
        try {
          final p = await client.from('prabhags').select('name').eq('id', pid).maybeSingle();
          _prabhagName = p?['name'] as String?;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _ticket = Map<String, dynamic>.from(t);
          _latestEvent = ev;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    _ch = client.channel('ticket_track_${widget.ticketId}');
    _ch!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.ticketId,
          ),
          callback: (_) {
            _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    super.dispose();
  }

  String _ago(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complaint')),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    final t = _ticket!;
    final status = t['status'] as String? ?? 'open';
    final step = trackerActiveStep(status);
    final refStr = t['ticket_ref'] as String? ?? '';
    final addr = (t['road_name'] as String?)?.trim().isNotEmpty == true
        ? t['road_name'] as String
        : (t['address_text'] as String? ?? 'Address on file');
    final created = t['created_at'] as String?;
    final epdo = (t['epdo_score'] as num?)?.toDouble();
    final tier = (t['severity_tier'] as String? ?? 'HIGH').toUpperCase();
    final zLine = [
      if (_zoneName != null) 'Zone: $_zoneName',
      if (_prabhagName != null) 'Prabhag: $_prabhagName',
    ].join(' · ');

    return Scaffold(
      backgroundColor: CitizenDesign.surface,
      appBar: AppBar(
        backgroundColor: CitizenDesign.surface,
        foregroundColor: CitizenDesign.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Complaint Status',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: refStr));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reference copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REFERENCE ID',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: CitizenDesign.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  refStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CitizenDesign.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('Updated ${_ago(t['updated_at'] as String?)}'),
                      backgroundColor: CitizenDesign.surfaceContainerLow,
                      labelStyle: GoogleFonts.inter(fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CitizenDesign.tertiaryFixed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$tier SEVERITY',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: CitizenDesign.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: CitizenDesign.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        zLine.isNotEmpty ? '$addr\n$zLine' : addr,
                        style: GoogleFonts.inter(height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: CitizenDesign.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Submitted on ${created != null ? created.split('T').first : '—'}',
                      style: GoogleFonts.inter(fontSize: 13, color: CitizenDesign.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded, size: 16, color: CitizenDesign.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'EPDO Score: ${epdo?.toStringAsFixed(2) ?? '—'} · 48h SLA',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CitizenDesign.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_latestEvent != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CitizenDesign.tertiaryFixed.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: CitizenDesign.accent, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LATEST UPDATE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: CitizenDesign.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_ago(_latestEvent!['created_at'] as String?)} — ${_latestEvent!['notes'] ?? _latestEvent!['event_type'] ?? 'Update'}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: CitizenDesign.primary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Current Progress',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CitizenDesign.primary,
            ),
          ),
          const SizedBox(height: 16),
          _VerticalStepper(currentStep: step, status: status),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: CitizenDesign.navyGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () async {
                    final uri = Uri.parse('tel:+912172400000');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'Contact Zone Office',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CitizenBottomNav(currentIndex: 2),
    );
  }
}

class _VerticalStepper extends StatelessWidget {
  const _VerticalStepper({required this.currentStep, required this.status});

  final int currentStep;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (i) {
        final done = status == 'resolved' || i < currentStep;
        final active = status != 'resolved' && i == currentStep;
        final pending = i > currentStep;
        final last = i == 4;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? CitizenDesign.accent
                        : active
                            ? CitizenDesign.primary
                            : Colors.transparent,
                    border: Border.all(
                      color: pending ? CitizenDesign.outlineVariant : CitizenDesign.accent,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : active
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                ),
                if (!last)
                  Container(
                    width: 2,
                    height: 36,
                    color: done ? CitizenDesign.accent : CitizenDesign.outlineVariant.withValues(alpha: 0.4),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kCitizenTrackerSteps[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: active || done ? FontWeight.w800 : FontWeight.w600,
                        color: pending ? CitizenDesign.onSurfaceVariant : CitizenDesign.primary,
                        fontSize: 15,
                      ),
                    ),
                    if (active && (status == 'assigned' || status == 'in_progress'))
                      Text(
                        'Crew assignment in progress',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CitizenDesign.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (pending)
                      Text(
                        'Pending',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CitizenDesign.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

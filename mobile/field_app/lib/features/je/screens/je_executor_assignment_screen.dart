import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/je_design.dart';
import '../../../providers/providers.dart';

enum _ExecutorKind { departmentGang, privateContractor }

class JeExecutorAssignmentScreen extends ConsumerStatefulWidget {
  const JeExecutorAssignmentScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<JeExecutorAssignmentScreen> createState() => _JeExecutorAssignmentScreenState();
}

class _JeExecutorAssignmentScreenState extends ConsumerState<JeExecutorAssignmentScreen> {
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _mukadams = [];
  List<Map<String, dynamic>> _contractors = [];
  _ExecutorKind? _kind;
  String? _selectedMukadamId;
  String? _selectedContractorId;
  bool _loading = true;
  bool _submitting = false;

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? JeDesign.error : JeDesign.primaryContainer,
        content: Text(msg),
      ),
    );
  }

  String _jobOrderRef(String? ticketRef) {
    final tr = ticketRef ?? '';
    if (tr.startsWith('SSR-')) {
      return 'JO-${tr.substring(4)}';
    }
    return 'JO-$tr';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ref.read(profileProvider.future);
      final z = profile?.zoneId;
      if (z == null) throw Exception('No zone');

      final supa = Supabase.instance.client;
      final t = await supa
          .from('tickets')
          .select(
            'id, ticket_ref, address_text, work_type, estimated_cost, status',
          )
          .eq('id', widget.ticketId)
          .maybeSingle();

      final mRows = await supa
          .from('profiles')
          .select('id, full_name, phone')
          .eq('role', 'mukadam')
          .eq('zone_id', z)
          .eq('is_active', true)
          .order('full_name');

      final cRows = await supa
          .from('contractors')
          .select('id, company_name, zone_ids, profiles(full_name)')
          .eq('is_blacklisted', false);

      final mList = (mRows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final cAll = (cRows as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final cFiltered = <Map<String, dynamic>>[];
      for (final c in cAll) {
        final ids = c['zone_ids'];
        if (ids is! List) continue;
        final zi = ids.map((e) => (e as num).toInt()).toList();
        if (zi.contains(z)) cFiltered.add(c);
      }

      if (!mounted) return;
      setState(() {
        _ticket = t != null ? Map<String, dynamic>.from(t) : null;
        _mukadams = mList;
        _contractors = cFiltered;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Load failed: $e');
      }
    }
  }

  Future<void> _assign() async {
    final t = _ticket;
    if (t == null || _kind == null) return;
    if (_kind == _ExecutorKind.departmentGang && _selectedMukadamId == null) return;
    if (_kind == _ExecutorKind.privateContractor && _selectedContractorId == null) return;

    final jobRef = _jobOrderRef(t['ticket_ref'] as String?);

    setState(() => _submitting = true);
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Not signed in');

      final oldStatus = t['status'] as String? ?? 'verified';

      final update = <String, dynamic>{
        'status': 'assigned',
        'job_order_ref': jobRef,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (_kind == _ExecutorKind.departmentGang) {
        update['assigned_mukadam'] = _selectedMukadamId;
        update['assigned_contractor'] = null;
      } else {
        update['assigned_contractor'] = _selectedContractorId;
        update['assigned_mukadam'] = null;
      }

      await supa.from('tickets').update(update).eq('id', widget.ticketId);

      await supa.from('ticket_events').insert({
        'ticket_id': widget.ticketId,
        'actor_id': uid,
        'actor_role': 'je',
        'event_type': 'assignment',
        'old_status': oldStatus,
        'new_status': 'assigned',
        'notes': _kind == _ExecutorKind.departmentGang
            ? 'Assigned to Mukadam. Job Order: $jobRef'
            : 'Assigned to Contractor. Job Order: $jobRef',
        'metadata': {'job_order_ref': jobRef},
      });

      if (mounted) {
        _snack('Job Order $jobRef generated and executor assigned.', error: false);
        context.go('/je/home');
      }
    } catch (e) {
      final msg = '$e';
      if (msg.contains('23505') || msg.contains('unique')) {
        _snack('This ticket already has a job order assigned.');
      } else {
        _snack('Assignment failed: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  String? _executorLabel() {
    if (_kind == _ExecutorKind.departmentGang && _selectedMukadamId != null) {
      for (final m in _mukadams) {
        if (m['id'] == _selectedMukadamId) {
          final n = m['full_name'] as String? ?? '';
          final parts = n.split(' ').where((s) => s.isNotEmpty).toList();
          final first = parts.isEmpty ? n : parts.first;
          return '$first (Dept. Gang)';
        }
      }
    }
    if (_kind == _ExecutorKind.privateContractor && _selectedContractorId != null) {
      for (final c in _contractors) {
        if (c['id'] == _selectedContractorId) {
          return c['company_name'] as String? ?? 'Contractor';
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final z = profileAsync.asData?.value?.zoneId;

    return Scaffold(
      backgroundColor: JeDesign.background,
      appBar: AppBar(
        backgroundColor: JeDesign.background,
        elevation: 0,
        foregroundColor: JeDesign.onSurface,
        title: Text(
          'ASSIGN WORK EXECUTOR',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search_rounded), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ticket == null
              ? const Center(child: Text('Ticket not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 20),
                      Text(
                        'Select Executor Type',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: _kind == _ExecutorKind.privateContractor ? 0.55 : 1,
                              child: _typeCard(
                                selected: _kind == _ExecutorKind.departmentGang,
                                icon: Icons.groups_rounded,
                                title: 'Department Gang',
                                subtitle: 'Assign to Mukadam',
                                onTap: () => setState(() {
                                  _kind = _ExecutorKind.departmentGang;
                                  _selectedContractorId = null;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Opacity(
                              opacity: _kind == _ExecutorKind.departmentGang ? 0.55 : 1,
                              child: _typeCard(
                                selected: _kind == _ExecutorKind.privateContractor,
                                icon: Icons.business_rounded,
                                title: 'Private Contractor',
                                subtitle: 'Assign to empanelled firm',
                                onTap: () => setState(() {
                                  _kind = _ExecutorKind.privateContractor;
                                  _selectedMukadamId = null;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_kind == _ExecutorKind.departmentGang) ...[
                        const SizedBox(height: 20),
                        Text(
                          'SELECT MUKADAM',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: JeDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_mukadams.isEmpty)
                          Text(
                            'No Mukadam available in Zone ${z ?? '—'}. Select Private Contractor instead.',
                            style: GoogleFonts.inter(color: JeDesign.error),
                          )
                        else
                          ..._mukadams.map((m) => _personTile(
                                name: m['full_name'] as String? ?? '',
                                subtitle: 'Zone $z Gang Leader',
                                selected: _selectedMukadamId == m['id'],
                                onTap: () => setState(() => _selectedMukadamId = m['id'] as String),
                              )),
                      ],
                      if (_kind == _ExecutorKind.privateContractor) ...[
                        const SizedBox(height: 20),
                        Text(
                          'SELECT CONTRACTOR',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: JeDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_contractors.isEmpty)
                          Text(
                            'No empanelled contractors for Zone ${z ?? '—'}. Select Department Gang instead.',
                            style: GoogleFonts.inter(color: JeDesign.error),
                          )
                        else
                          ..._contractors.map((c) {
                            final prof = c['profiles'];
                            final contact = prof is Map ? prof['full_name'] as String? : null;
                            final name = c['company_name'] as String? ?? contact ?? 'Contractor';
                            return _personTile(
                              name: name,
                              subtitle: 'Empanelled firm',
                              selected: _selectedContractorId == c['id'],
                              onTap: () => setState(() => _selectedContractorId = c['id'] as String),
                            );
                          }),
                      ],
                      if (_executorLabel() != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: JeDesign.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: JeDesign.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DRAFT JOB ORDER',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: JeDesign.secondaryContainer,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _jobOrderRef(_ticket!['ticket_ref'] as String?),
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'EXECUTOR: ${_executorLabel()}',
                                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'TOTAL ALLOCATION: ₹${(_ticket!['estimated_cost'] as num?)?.toStringAsFixed(2) ?? '—'}',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JeDesign.tertiaryFixed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Full road surface restoration including base layer preparation and ${_ticket!['work_type'] ?? 'work'} as per SSR guidelines.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.4,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: JeDesign.tertiaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: JeDesign.onTertiaryContainer),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Once assigned, the executor cannot be changed without Executive Engineer approval. Ensure all site assessment data and executor availability are verified before generation.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: JeDesign.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _canSubmit() && !_submitting ? _assign : null,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: _canSubmit() ? JeDesign.primaryGradient : null,
                  color: _canSubmit() ? null : JeDesign.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _submitting
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Generate Job Order & Assign',
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
      ),
    );
  }

  bool _canSubmit() {
    if (_kind == null) return false;
    if (_kind == _ExecutorKind.departmentGang) {
      return _selectedMukadamId != null && _mukadams.isNotEmpty;
    }
    return _selectedContractorId != null && _contractors.isNotEmpty;
  }

  Widget _summaryCard() {
    final t = _ticket!;
    final cost = (t['estimated_cost'] as num?)?.toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: JeDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: JeDesign.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.12,
              child: Icon(Icons.lock_rounded, size: 40, color: JeDesign.onSurfaceVariant),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TASK ID',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: JeDesign.onSurfaceVariant,
                ),
              ),
              Text(
                t['ticket_ref'] as String? ?? '',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: JeDesign.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t['address_text'] as String? ?? '—',
                      style: GoogleFonts.inter(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.build_outlined, size: 18, color: JeDesign.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t['work_type'] as String? ?? '—',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimated Allocation',
                    style: GoogleFonts.inter(color: JeDesign.onSurfaceVariant),
                  ),
                  Text(
                    '₹${cost?.toStringAsFixed(2) ?? '—'}',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: JeDesign.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
        color: JeDesign.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? JeDesign.primaryNavy : JeDesign.surfaceContainerHigh,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: JeDesign.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: JeDesign.primaryNavy),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: JeDesign.onSurfaceVariant),
                ),
                if (selected)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.check_circle, color: JeDesign.primaryNavy),
                  ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _personTile({
    required String name,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: JeDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: JeDesign.cardShadow,
              border: Border.all(
                color: selected ? JeDesign.primaryNavy : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: JeDesign.primaryContainer,
                  child: Text(
                    _initials(name),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: JeDesign.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '• AVAILABLE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF166534),
                    ),
                  ),
                ),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

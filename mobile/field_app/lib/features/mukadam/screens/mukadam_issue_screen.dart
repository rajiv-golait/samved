import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../mukadam_formatters.dart';

class MukadamIssueScreen extends ConsumerStatefulWidget {
  const MukadamIssueScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<MukadamIssueScreen> createState() => _MukadamIssueScreenState();
}

class _MukadamIssueScreenState extends ConsumerState<MukadamIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _je;
  bool _loading = true;
  String? _error;

  String? _issueType;
  String _urgency = 'medium';
  bool _sending = false;

  static const _types = [
    _IssueType('access_blocked', 'Access Blocked', Icons.block),
    _IssueType('rain_weather', 'Rain / Weather', Icons.cloudy_snowing),
    _IssueType('material_delay', 'Material Delay', Icons.inventory_2_outlined),
    _IssueType('site_mismatch', 'Site Mismatch', Icons.compare_arrows),
    _IssueType('safety_issue', 'Safety Issue', Icons.health_and_safety_outlined),
    _IssueType('other', 'Other', Icons.more_horiz),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = ref.read(ticketServiceProvider);
    try {
      final t = await svc.fetchMukadamTicketDetail(widget.ticketId);
      if (!mounted) return;
      if (t == null) {
        setState(() {
          _error = 'Ticket not found';
          _loading = false;
        });
        return;
      }
      final jeId = t['assigned_je'] as String?;
      Map<String, dynamic>? je;
      if (jeId != null) je = await svc.fetchProfileById(jeId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _je = je;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_issueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue type')),
      );
      return;
    }
    final profile = await ref.read(profileProvider.future);
    if (!mounted || profile == null) return;

    setState(() => _sending = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;
      await client.from('ticket_events').insert({
        'ticket_id': widget.ticketId,
        'actor_id': uid,
        'actor_role': 'mukadam',
        'event_type': 'escalation',
        'notes': '$_issueType: ${_notes.text.trim()}',
        'metadata': {
          'issue_type': _issueType,
          'urgency': _urgency,
          'reported_by': profile.fullName,
        },
      });
      if (!mounted) return;
      final jeName = _je?['full_name'] as String? ?? 'JE';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alert sent to JE $jeName. They will respond shortly.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _ticket == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(_error ?? 'Error')),
      );
    }

    final t = _ticket!;
    final refStr = t['ticket_ref'] as String? ?? '';
    final address = t['address_text'] as String? ?? '';
    final severity = t['severity_tier'] as String?;
    final jeName = _je?['full_name'] as String? ?? 'JE';
    final zoneName = embeddedZoneName(t) ?? '—';

    final canSend = _issueType != null && _notes.text.trim().length >= 10;

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        backgroundColor: MukadamDesign.accent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'RAISE AN ISSUE',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            Text(
              refStr,
              style: mukadamMono(11, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: MukadamDesign.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined,
                      color: MukadamDesign.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MukadamDesign.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MukadamDesign.tertiaryFixed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      severityLabel(severity),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: MukadamDesign.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'What is blocking your work?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: MukadamDesign.onSurface,
              ),
            ),
            Text(
              'Select the type of issue you are facing',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MukadamDesign.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: _types.map((type) {
                final sel = _issueType == type.id;
                return Material(
                  color: MukadamDesign.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() => _issueType = type.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? MukadamDesign.primaryContainer
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: MukadamDesign.cardShadow,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type.icon,
                            color: sel
                                ? MukadamDesign.accent
                                : MukadamDesign.primaryNavy,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            type.label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                              color: MukadamDesign.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'HOW URGENT?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _UrgencyChip(
                  label: 'Low',
                  selected: _urgency == 'low',
                  onTap: () => setState(() => _urgency = 'low'),
                ),
                const SizedBox(width: 8),
                _UrgencyChip(
                  label: 'Medium',
                  selected: _urgency == 'medium',
                  onTap: () => setState(() => _urgency = 'medium'),
                ),
                const SizedBox(width: 8),
                _UrgencyChip(
                  label: 'Critical',
                  selected: _urgency == 'critical',
                  onTap: () => setState(() => _urgency = 'critical'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Describe the issue (required)',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: MukadamDesign.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) {
                  return 'Please enter at least 10 characters';
                }
                return null;
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: MukadamDesign.surfaceContainerLow,
                hintText:
                    'Describe what is blocking your gang. Be specific for JE to respond quickly.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MukadamDesign.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS WILL IMMEDIATELY NOTIFY:',
                    style: mukadamMono(10,
                        color: MukadamDesign.onSurfaceVariant,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: MukadamDesign.primaryNavy,
                        child: Text(
                          initialsFromName(jeName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'JE $jeName',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              zoneName,
                              style: mukadamMono(12,
                                  color: MukadamDesign.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MukadamDesign.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Push notification + SMS will be sent',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MukadamDesign.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        decoration: const BoxDecoration(
          color: MukadamDesign.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: canSend && !_sending
                    ? MukadamDesign.accentGradient
                    : null,
                color: canSend && !_sending
                    ? null
                    : MukadamDesign.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSend && !_sending ? _submit : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sending)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else ...[
                          Text(
                            'Send Alert to JE →',
                            style: GoogleFonts.plusJakartaSans(
                              color: canSend ? Colors.white : MukadamDesign.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JE will be notified immediately. Track their response in your task detail.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: MukadamDesign.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueType {
  const _IssueType(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? MukadamDesign.accent : MukadamDesign.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : MukadamDesign.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../contractor_formatters.dart';
import '../contractor_prefs.dart';

class ContractorInProgressScreen extends ConsumerStatefulWidget {
  const ContractorInProgressScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<ContractorInProgressScreen> createState() => _ContractorInProgressScreenState();
}

class _ContractorInProgressScreenState extends ConsumerState<ContractorInProgressScreen> {
  Map<String, dynamic>? _t;
  Timer? _timer;
  List<bool> _check = [false, false, false, false];
  final _notes = TextEditingController();
  int _slaH = 48;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await ref.read(ticketServiceProvider).fetchContractorTicketDetail(widget.ticketId);
    final list = await loadContractorChecklist(widget.ticketId);
    final sla = await ref.read(ticketServiceProvider).fetchSlaResolutionHours(t?['severity_tier'] as String?);
    if (!mounted) return;
    _t = t;
    _check = list;
    _slaH = sla ?? 48;
    setState(() {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final je = t['je'] as Map?;
    final d = dims(t);
    final start = DateTime.tryParse((t['updated_at'] ?? '').toString()) ?? DateTime.now();
    final elapsed = DateTime.now().difference(start);
    final progress = (elapsed.inSeconds / Duration(hours: _slaH).inSeconds).clamp(0.0, 1.0);
    final done = _check.where((e) => e).length;
    final depthCm = ((d?.depthM ?? 0) * 100).round();
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        backgroundColor: MukadamDesign.primaryContainer,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('IN PROGRESS', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          Text((t['job_order_ref'] ?? t['ticket_ref']).toString(), style: contractorMono(11, color: Colors.white70)),
        ]),
      ),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('TIME ON SITE', style: contractorMono(10)), const Spacer(), Text('SLA Deadline: ${(_slaH - elapsed.inHours).clamp(0, _slaH)}h remaining', style: GoogleFonts.inter(fontSize: 12))]),
              Text(hms(elapsed), style: contractorMono(44, color: MukadamDesign.accent, weight: FontWeight.w800)),
              Text('Started at ${formatTimeHm(start)} · Today', style: GoogleFonts.inter(fontSize: 12, color: MukadamDesign.onSurfaceVariant)),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progress, minHeight: 8, color: MukadamDesign.accent)),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Work Scope', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22)),
              Text('${t['work_type']} · ${d?.areaSqm.toStringAsFixed(2) ?? '0'} sqm · ₹${((t['rate_per_unit'] as num?) ?? 0).toStringAsFixed(0)}/sqm'),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('Quality Checklist', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)), const Spacer(), Text('$done of 4 COMPLETE', style: contractorMono(10))]),
              const SizedBox(height: 10),
              ...[
                'Road surface thoroughly cleaned before patching',
                'Hot mix applied at correct depth ($depthCm cm)',
                'Surface compacted with roller or plate',
                'Debris removed and site cleared',
              ].asMap().entries.map((e) => InkWell(
                    onTap: () async {
                      _check[e.key] = !_check[e.key];
                      await saveContractorChecklist(widget.ticketId, _check);
                      if (mounted) setState(() {});
                    },
                    child: SizedBox(height: 56, child: Row(children: [
                      Icon(_check[e.key] ? Icons.check_circle : Icons.radio_button_unchecked, color: _check[e.key] ? MukadamDesign.success : MukadamDesign.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.value)),
                    ])),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Evidence Readiness', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _s(Icons.camera_alt_outlined, 'Before photo loaded', 'READY ✓', MukadamDesign.success),
              _s(Icons.gps_fixed, 'GPS location locked', 'READY ✓', MukadamDesign.success),
              _s(Icons.timer_outlined, 'Timestamp recording', 'ACTIVE', MukadamDesign.accent),
            ]),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: MukadamDesign.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.warning_amber_rounded, color: MukadamDesign.error),
            title: const Text('Flag a Blocker or Issue'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/contractor/issue/${widget.ticketId}'),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: MukadamDesign.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: CircleAvatar(backgroundColor: MukadamDesign.primaryNavy, child: Text(initialsFromText(je?['full_name']?.toString() ?? 'JE'), style: const TextStyle(color: Colors.white))),
            title: Text('Contact JE ${je?['full_name'] ?? 'JE'}'),
            trailing: const Icon(Icons.phone),
            onTap: () async {
              final p = je?['phone']?.toString();
              if (p != null) await launchUrl(Uri.parse('tel:$p'));
            },
          )
        ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DecoratedBox(
                decoration: BoxDecoration(gradient: done == 4 ? MukadamDesign.primaryGradient : null, color: done == 4 ? null : MukadamDesign.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                child: InkWell(
                  onTap: done == 4
                      ? () => context.push('/contractor/camera/${widget.ticketId}', extra: {'fieldNotes': _notes.text.trim().isEmpty ? null : _notes.text.trim()})
                      : null,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(height: 52, child: Center(child: Text('Submit Proof of Repair →'))),
                ),
              ),
              const SizedBox(height: 6),
              Text('Proof submission is final and cryptographically recorded.', style: GoogleFonts.inter(fontSize: 11, color: MukadamDesign.error)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _s(IconData icon, String l, String r, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Expanded(child: Text(l)), Text(r, style: GoogleFonts.inter(color: c, fontWeight: FontWeight.w700))]),
      );
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../contractor_formatters.dart';

class ContractorJobDetailScreen extends ConsumerStatefulWidget {
  const ContractorJobDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<ContractorJobDetailScreen> createState() => _ContractorJobDetailScreenState();
}

class _ContractorJobDetailScreenState extends ConsumerState<ContractorJobDetailScreen> {
  Map<String, dynamic>? _ticket;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _ticket = await ref.read(ticketServiceProvider).fetchContractorTicketDetail(widget.ticketId);
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    final cp = await ref.read(ticketServiceProvider).fetchContractorProfile();
    final company = cp?['company_name']?.toString() ?? 'Contractor';
    setState(() => _busy = true);
    try {
      await ref.read(ticketServiceProvider).contractorStartWork(ticketId: widget.ticketId, companyName: company);
      ref.invalidate(contractorHomeProvider);
      if (mounted) context.push('/contractor/inprogress/${widget.ticketId}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final before = t['photo_before'];
    final beforeUrl = before is List && before.isNotEmpty ? before.first.toString() : null;
    final je = t['je'] as Map?;
    final jeName = je?['full_name']?.toString() ?? 'JE';
    final status = t['status'] as String? ?? '';
    final d = dims(t);
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        title: Text((t['job_order_ref'] ?? t['ticket_ref']).toString(), style: contractorMono(13)),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
      ),
      body: Stack(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 130), children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: beforeUrl == null
                  ? Container(color: MukadamDesign.surfaceContainerHigh, child: const Icon(Icons.camera_alt_outlined))
                  : CachedNetworkImage(imageUrl: beforeUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: MukadamDesign.tertiaryFixed, borderRadius: BorderRadius.circular(999)),
            child: Text('JO TICKET', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MukadamDesign.onTertiaryContainer)),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((t['job_order_ref'] ?? '').toString(), style: contractorMono(20, weight: FontWeight.w800, color: MukadamDesign.primaryNavy)),
              Text('Assigned by JE $jeName', style: GoogleFonts.inter(color: MukadamDesign.onSurfaceVariant)),
              const SizedBox(height: 10),
              Text('Zone: ${zoneName(t) ?? '—'}   Prabhag: ${prabhagName(t) ?? '—'}'),
              Text('Work Type: ${t['work_type'] ?? '—'}   Area: ${d?.areaSqm.toStringAsFixed(2) ?? '0'} sqm'),
              Text('Depth: ${((d?.depthM ?? 0) * 100).round()} cm   AMC Rate: ₹${((t['rate_per_unit'] as num?) ?? 0).toStringAsFixed(0)} / sqm'),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: MukadamDesign.tertiaryFixed, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BILLING SUMMARY', style: contractorMono(10, color: MukadamDesign.onTertiaryContainer, weight: FontWeight.w700)),
              Text('₹${((t['rate_per_unit'] as num?) ?? 0).toStringAsFixed(0)} / sqm', style: contractorMono(32, color: MukadamDesign.onTertiaryContainer, weight: FontWeight.w800)),
              Text('${d?.areaSqm.toStringAsFixed(2) ?? '0'} sqm measured by system', style: GoogleFonts.inter(color: MukadamDesign.onSurfaceVariant)),
              const Divider(),
              Text('TOTAL PAYABLE', style: contractorMono(11, color: MukadamDesign.onSurfaceVariant)),
              Text(inr((t['estimated_cost'] as num?) ?? 0), style: contractorMono(38, color: MukadamDesign.onTertiaryContainer, weight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final phone = je?['phone']?.toString();
              if (phone != null) await launchUrl(Uri.parse('tel:$phone'));
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
              child: Row(children: [const Icon(Icons.phone), const SizedBox(width: 8), Expanded(child: Text('Contact JE $jeName')), const Icon(Icons.chevron_right)]),
            ),
          )
        ]),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.white.withValues(alpha: 0.92),
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 16),
            child: status == 'assigned'
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    _btn(_busy ? 'Starting...' : 'Start Work', onTap: _busy ? null : _start),
                    const SizedBox(height: 6),
                    Text('Starting work creates an immutable timestamp record', style: GoogleFonts.inter(fontSize: 11, color: MukadamDesign.onSurfaceVariant)),
                  ])
                : status == 'in_progress'
                    ? _btn('Submit Proof of Repair →', onTap: () => context.push('/contractor/inprogress/${widget.ticketId}'))
                    : Container(
                        height: 52,
                        decoration: BoxDecoration(color: MukadamDesign.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                        alignment: Alignment.center,
                        child: Text(status == 'audit_pending' ? 'Proof Submitted — Awaiting SMC Verification' : 'Completed', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      ),
          ),
        )
      ]),
    );
  }

  Widget _btn(String label, {VoidCallback? onTap}) => DecoratedBox(
        decoration: BoxDecoration(gradient: MukadamDesign.primaryGradient, borderRadius: BorderRadius.circular(999)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 52,
            child: Center(child: Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800))),
          ),
        ),
      );
}

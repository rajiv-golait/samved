import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../contractor_formatters.dart';

class ContractorSubmissionCompleteScreen extends ConsumerStatefulWidget {
  const ContractorSubmissionCompleteScreen({
    super.key,
    required this.ticketId,
    required this.hash,
    required this.submittedAt,
  });
  final String ticketId;
  final String hash;
  final DateTime submittedAt;

  @override
  ConsumerState<ContractorSubmissionCompleteScreen> createState() => _ContractorSubmissionCompleteScreenState();
}

class _ContractorSubmissionCompleteScreenState extends ConsumerState<ContractorSubmissionCompleteScreen> {
  Map<String, dynamic>? _t;
  RealtimeChannel? _ch;

  @override
  void initState() {
    super.initState();
    _load();
    _ch = Supabase.instance.client
        .channel('contractor_submit_${widget.ticketId}')
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'tickets', filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.ticketId), callback: (_) => _load())
        .subscribe();
  }

  Future<void> _load() async {
    final t = await ref.read(ticketServiceProvider).fetchContractorTicketDetail(widget.ticketId);
    if (mounted) setState(() => _t = t);
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cpAsync = ref.watch(profileProvider);
    final company = cpAsync.value?.fullName ?? 'Contractor';
    final ssim = t['ssim_score'] as num?;
    final pass = t['ssim_pass'] == true;
    final state = ssim == null ? 'PENDING' : (pass ? 'VERIFIED' : 'REJECTED');
    final stateColor = ssim == null ? MukadamDesign.onSurfaceVariant : (pass ? MukadamDesign.success : MukadamDesign.error);
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        title: Text('Submission Complete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: IconButton(onPressed: () => context.go('/contractor/home'), icon: const Icon(Icons.arrow_back)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(color: MukadamDesign.primaryNavy, shape: BoxShape.circle), child: const Icon(Icons.shield, color: Colors.white, size: 44)),
        const SizedBox(height: 10),
        Text('Proof Submitted', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: MukadamDesign.primaryNavy)),
        Text('Cryptographically signed and recorded in SMC system', style: GoogleFonts.inter(color: MukadamDesign.onSurfaceVariant)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: MukadamDesign.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)), child: Text((t['job_order_ref'] ?? t['ticket_ref']).toString(), style: contractorMono(12))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('SUBMISSION RECEIPT', style: contractorMono(10, color: MukadamDesign.onSurfaceVariant)), const Spacer(), const Icon(Icons.verified_user_outlined, size: 16)]),
            const SizedBox(height: 8),
            _r('Job Order', (t['job_order_ref'] ?? t['ticket_ref']).toString(), mono: true),
            _r('Submitted At', formatSubmittedAt(widget.submittedAt)),
            _r('Submitted By', company),
            Row(children: [Text('SSIM SCORE', style: contractorMono(11)), const Spacer(), Text(ssim?.toStringAsFixed(2) ?? '—', style: contractorMono(13, weight: FontWeight.w800)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: stateColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text(state, style: GoogleFonts.inter(fontSize: 10, color: stateColor, fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 8),
            _r('Bill Status', 'PENDING ACCOUNTS REVIEW'),
            const SizedBox(height: 8),
            Text('SHA-256 PROOF', style: contractorMono(11)),
            Text(widget.hash, style: contractorMono(10)),
            const SizedBox(height: 8),
            _r('Amount Claimed', inr((t['estimated_cost'] as num?) ?? 0), mono: true, valueColor: MukadamDesign.onTertiaryContainer),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: MukadamDesign.tertiaryFixed, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payment Pipeline', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 8),
            Text('₹${inr((t["estimated_cost"] as num?) ?? 0).replaceFirst("₹", "")} payable upon pipeline completion', style: GoogleFonts.inter(color: MukadamDesign.onTertiaryContainer)),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))), icon: const Icon(Icons.download), label: const Text('Download Receipt PDF')),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(gradient: MukadamDesign.primaryGradient, borderRadius: BorderRadius.circular(999)),
          child: InkWell(
            onTap: () => context.go('/contractor/home'),
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(height: 52, child: Center(child: Text('Return to Work Orders', style: TextStyle(color: Colors.white)))),
          ),
        ),
      ]),
    );
  }

  Widget _r(String l, String v, {bool mono = false, Color? valueColor}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [Expanded(child: Text(l, style: contractorMono(11, color: MukadamDesign.onSurfaceVariant))), Text(v, style: (mono ? contractorMono(13, weight: FontWeight.w700) : GoogleFonts.inter(fontWeight: FontWeight.w700)).copyWith(color: valueColor))]),
      );
}

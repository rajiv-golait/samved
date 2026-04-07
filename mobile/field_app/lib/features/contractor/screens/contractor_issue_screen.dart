import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../contractor_formatters.dart';

class ContractorIssueScreen extends ConsumerStatefulWidget {
  const ContractorIssueScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<ContractorIssueScreen> createState() => _ContractorIssueScreenState();
}

class _ContractorIssueScreenState extends ConsumerState<ContractorIssueScreen> {
  Map<String, dynamic>? _t;
  String _urgency = 'medium';
  String? _type;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(ticketServiceProvider).fetchContractorTicketDetail(widget.ticketId).then((v) {
      if (mounted) setState(() => _t = v);
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final can = _type != null && _notes.text.trim().length >= 10;
    final je = t['je'] as Map?;
    final jeName = je?['full_name']?.toString() ?? 'JE';
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        backgroundColor: MukadamDesign.accent,
        foregroundColor: Colors.white,
        title: Column(children: [
          Text('RAISE AN ISSUE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
          Text((t['job_order_ref'] ?? t['ticket_ref']).toString(), style: contractorMono(11, color: Colors.white70)),
        ]),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [const Icon(Icons.place_outlined), const SizedBox(width: 6), Expanded(child: Text('${t['address_text']} · ${zoneName(t)} · ${prabhagName(t)}'))]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
          child: Row(children: [
            Expanded(child: Text('${inr((t['estimated_cost'] as num?) ?? 0)} at risk', style: contractorMono(15, color: MukadamDesign.onTertiaryContainer, weight: FontWeight.w800))),
            Text('SLA: 4h remaining', style: GoogleFonts.inter(color: MukadamDesign.error, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 16),
        Text('What is blocking your work?', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            ('access_blocked', 'Access Blocked', Icons.block),
            ('rain_weather', 'Rain / Weather', Icons.cloudy_snowing),
            ('material_delay', 'Material Delay', Icons.inventory_2_outlined),
            ('site_mismatch', 'Site Mismatch', Icons.warning_amber_rounded),
            ('safety_issue', 'Safety Issue', Icons.health_and_safety_outlined),
            ('contract_dispute', 'Contract Dispute', Icons.description_outlined),
          ].map((e) {
            final id = e.$1;
            final selected = _type == id;
            return SizedBox(
              width: (MediaQuery.sizeOf(context).width - 40) / 2,
              child: InkWell(
                onTap: () => setState(() => _type = id),
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? MukadamDesign.primaryContainer : Colors.transparent, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(e.$3, color: selected ? MukadamDesign.accent : MukadamDesign.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(e.$2, style: GoogleFonts.inter(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        Row(children: ['Low', 'Medium', 'Critical'].map((l) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(l), selected: _urgency == l.toLowerCase(), onSelected: (_) => setState(() => _urgency = l.toLowerCase()), selectedColor: MukadamDesign.accent, labelStyle: TextStyle(color: _urgency == l.toLowerCase() ? Colors.white : null))))).toList()),
        const SizedBox(height: 12),
        Row(children: [Text('Issue description (required)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)), const Spacer(), Text('${_notes.text.length} / 200')]),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          maxLength: 200,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(filled: true, fillColor: MukadamDesign.surfaceContainerLow, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: MukadamDesign.accent, width: 4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('THIS WILL IMMEDIATELY NOTIFY:', style: contractorMono(10)),
            ListTile(leading: CircleAvatar(backgroundColor: MukadamDesign.primaryNavy, child: Text(initialsFromText(jeName), style: const TextStyle(color: Colors.white))), title: Text(jeName), subtitle: Text(zoneName(t) ?? '')),
            Text('Issue logged against ${(t['job_order_ref'] ?? t['ticket_ref'])} for audit trail', style: GoogleFonts.inter(fontSize: 11, color: MukadamDesign.onSurfaceVariant)),
          ]),
        ),
      ]),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 12),
        color: Colors.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: can ? MukadamDesign.accentGradient : null, color: can ? null : MukadamDesign.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
            child: InkWell(
              onTap: can
                  ? () async {
                      final uid = Supabase.instance.client.auth.currentUser?.id;
                      if (uid == null) return;
                      await Supabase.instance.client.from('ticket_events').insert({
                        'ticket_id': widget.ticketId,
                        'actor_id': uid,
                        'actor_role': 'contractor',
                        'event_type': 'escalation',
                        'notes': '$_type: ${_notes.text.trim()}',
                        'metadata': {'issue_type': _type, 'urgency': _urgency, 'job_order_ref': t['job_order_ref'], 'amount_at_risk': t['estimated_cost']},
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert sent to JE $jeName. Issue logged against ${t['job_order_ref']}.')));
                        context.pop();
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(999),
              child: const SizedBox(height: 52, child: Center(child: Text('Send Alert to JE →'))),
            ),
          ),
          const SizedBox(height: 6),
          Text('This issue will be permanently recorded in the job audit trail.', style: GoogleFonts.inter(fontSize: 11, color: MukadamDesign.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

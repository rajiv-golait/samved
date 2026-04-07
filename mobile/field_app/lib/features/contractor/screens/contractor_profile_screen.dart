import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../contractor_formatters.dart';
import '../contractor_prefs.dart';
import '../widgets/contractor_bottom_nav.dart';

class ContractorProfileScreen extends ConsumerStatefulWidget {
  const ContractorProfileScreen({super.key});

  @override
  ConsumerState<ContractorProfileScreen> createState() => _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends ConsumerState<ContractorProfileScreen> {
  Map<String, dynamic>? _c;
  List<Map<String, dynamic>> _zones = [];
  String _lang = 'en';
  bool _jobs = true, _pay = true, _sla = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ref.read(ticketServiceProvider).fetchContractorProfile();
    final zoneIds = ((c?['zone_ids'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    final zones = await ref.read(ticketServiceProvider).fetchZonesByIds(zoneIds);
    final n = await loadContractorNotif();
    final lang = await loadContractorLanguage();
    if (mounted) {
      setState(() {
        _c = c;
        _zones = zones;
        _jobs = n['jobs'] ?? true;
        _pay = n['payment'] ?? true;
        _sla = n['sla'] ?? true;
        _lang = lang;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final home = ref.watch(contractorHomeProvider).valueOrNull;
    final pendingCount = home?.pendingCount ?? 0;
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final company = c['company_name']?.toString() ?? 'Contractor';
    final initials = initialsFromText(company);
    final blacklisted = c['is_blacklisted'] == true;
    final zoneLabel = _zones.map((e) => e['name']).join(' · ');
    final tickets = home?.rows ?? [];
    final billed = tickets.where((e) => e['status'] == 'audit_pending' || e['status'] == 'resolved').fold<double>(0, (a, b) => a + ((b['estimated_cost'] as num?)?.toDouble() ?? 0));
    final pending = tickets.where((e) => e['status'] == 'audit_pending').fold<double>(0, (a, b) => a + ((b['estimated_cost'] as num?)?.toDouble() ?? 0));
    final paid = tickets.where((e) => e['status'] == 'resolved').fold<double>(0, (a, b) => a + ((b['estimated_cost'] as num?)?.toDouble() ?? 0));
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 22),
            decoration: const BoxDecoration(color: MukadamDesign.primaryContainer, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
            child: Column(children: [
              Row(children: [IconButton(onPressed: () => context.go('/contractor/home'), icon: const Icon(Icons.arrow_back, color: Colors.white)), const Spacer(), const Icon(Icons.settings, color: Colors.white)]),
              CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Text(initials, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800))),
              const SizedBox(height: 8),
              Text(company, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text((c['profiles']?['phone'] ?? '').toString(), style: GoogleFonts.inter(color: Colors.white70)),
              Text('CONTRACTOR · $zoneLabel', style: contractorMono(11, color: Colors.white60)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CONTRACT DETAILS', style: contractorMono(10, color: MukadamDesign.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text('Contract #: ${c['contract_number'] ?? '—'}'),
                Text('GST: ${c['gst_number'] ?? '—'}', style: contractorMono(12)),
                Text('PAN: ${c['pan_number'] ?? '—'}', style: contractorMono(12)),
                Text('Valid Until: ${(c['contract_end'] ?? '').toString().split('T').first}'),
                Text(blacklisted ? 'BLACKLISTED' : 'ACTIVE', style: GoogleFonts.inter(color: blacklisted ? MukadamDesign.error : MukadamDesign.success, fontWeight: FontWeight.w800)),
              ])),
              const SizedBox(height: 10),
              _card(Container(
                color: MukadamDesign.tertiaryFixed,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BILLING SUMMARY — FY 2025-26', style: contractorMono(10, color: MukadamDesign.onTertiaryContainer)),
                    _row('Total Billed', inr(billed)),
                    _row('Pending Approval', inr(pending)),
                    _row('Paid to Date', inr(paid)),
                  ]),
                ),
              )),
              const SizedBox(height: 10),
              _card(Row(children: [
                const Icon(Icons.language),
                const SizedBox(width: 8),
                const Text('Interface Language'),
                const Spacer(),
                ChoiceChip(label: const Text('English'), selected: _lang == 'en', onSelected: (_) async {
                  await saveContractorLanguage('en');
                  setState(() => _lang = 'en');
                }),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('मराठी'), selected: _lang == 'mr', onSelected: (_) async {
                  await saveContractorLanguage('mr');
                  setState(() => _lang = 'mr');
                }),
              ])),
              const SizedBox(height: 10),
              _card(Column(children: [
                SwitchListTile(value: _jobs, onChanged: (v) async {
                  setState(() => _jobs = v);
                  await saveContractorNotif(jobs: _jobs, payment: _pay, sla: _sla);
                }, title: const Text('New Job Assignments')),
                SwitchListTile(value: _pay, onChanged: (v) async {
                  setState(() => _pay = v);
                  await saveContractorNotif(jobs: _jobs, payment: _pay, sla: _sla);
                }, title: const Text('Payment Status Updates')),
                SwitchListTile(value: _sla, onChanged: (v) async {
                  setState(() => _sla = v);
                  await saveContractorNotif(jobs: _jobs, payment: _pay, sla: _sla);
                }, title: const Text('SLA Breach Alerts')),
              ])),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, color: MukadamDesign.accent),
                label: const Text('Sign Out', style: TextStyle(color: MukadamDesign.accent)),
              )
            ]),
          ),
        ],
      ),
      bottomNavigationBar: ContractorBottomNav(currentIndex: 3, pendingCount: pendingCount),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [Expanded(child: Text(l)), Text(v, style: contractorMono(13, weight: FontWeight.w700))]),
      );
}

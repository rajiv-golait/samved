import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/ticket_providers.dart';
import '../../contractor/contractor_formatters.dart';
import '../widgets/contractor_bottom_nav.dart';

enum _Filter { all, active, pending, completed }

class ContractorHomeScreen extends ConsumerStatefulWidget {
  const ContractorHomeScreen({super.key});

  @override
  ConsumerState<ContractorHomeScreen> createState() => _ContractorHomeScreenState();
}

class _ContractorHomeScreenState extends ConsumerState<ContractorHomeScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractorHomeProvider);
    return Scaffold(
      backgroundColor: MukadamDesign.background,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (snap) {
            final rows = snap.rows;
            final activeCount = rows.where((e) => e['status'] == 'assigned' || e['status'] == 'in_progress').length;
            final completedCount = rows.where((e) => e['status'] == 'resolved').length;
            final pendingCount = snap.pendingCount;
            final pendingAmount = snap.pendingAmount;

            final filtered = rows.where((r) {
              switch (_filter) {
                case _Filter.all:
                  return true;
                case _Filter.active:
                  return r['status'] == 'assigned' || r['status'] == 'in_progress';
                case _Filter.pending:
                  return r['status'] == 'audit_pending';
                case _Filter.completed:
                  return r['status'] == 'resolved';
              }
            }).toList();

            final title = 'Work Orders';
            final initials = initialsFromText('Contractor');

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 6),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 22, backgroundColor: MukadamDesign.primaryNavy, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800)),
                          Text('CONTRACTOR', style: contractorMono(10, color: MukadamDesign.onSurfaceVariant)),
                        ]),
                      ),
                      Stack(children: [
                        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
                        const Positioned(right: 13, top: 14, child: CircleAvatar(radius: 3, backgroundColor: Colors.red))
                      ]),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _chip(MukadamDesign.accent, '$activeCount Active'),
                      const SizedBox(width: 8),
                      _chip(MukadamDesign.primaryNavy, '${inr(pendingAmount)} Pending', mono: true),
                      const SizedBox(width: 8),
                      _chip(MukadamDesign.success, '$completedCount Completed'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _tab('All', _filter == _Filter.all, () => setState(() => _filter = _Filter.all)),
                    const SizedBox(width: 8),
                    _tab('Active', _filter == _Filter.active, () => setState(() => _filter = _Filter.active)),
                    const SizedBox(width: 8),
                    _tab('Pending Payment', _filter == _Filter.pending, () => setState(() => _filter = _Filter.pending), dot: pendingCount > 0),
                    const SizedBox(width: 8),
                    _tab('Completed', _filter == _Filter.completed, () => setState(() => _filter = _Filter.completed)),
                  ]),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(contractorHomeProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _card(context, filtered[i]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: ContractorBottomNav(currentIndex: 0, pendingCount: async.valueOrNull?.pendingCount ?? 0),
    );
  }

  Widget _chip(Color c, String text, {bool mono = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), boxShadow: MukadamDesign.cardShadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: (mono ? contractorMono(12) : GoogleFonts.inter(fontSize: 12)).copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _tab(String label, bool active, VoidCallback onTap, {bool dot = false}) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: active ? MukadamDesign.tertiaryFixed : MukadamDesign.surfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (dot) ...[const Icon(Icons.circle, size: 6, color: MukadamDesign.accent), const SizedBox(width: 4)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: MukadamDesign.primaryNavy))),
            ]),
          ),
        ),
      );

  Widget _card(BuildContext context, Map<String, dynamic> row) {
    final d = dims(row);
    final area = d?.areaSqm ?? 0;
    final status = row['status'] as String? ?? '';
    return InkWell(
      onTap: () => context.push('/contractor/detail/${row['id']}'),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: MukadamDesign.cardShadow),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, decoration: BoxDecoration(color: MukadamDesign.severityBar(row['severity_tier'] as String?), borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(999)), child: Text((row['job_order_ref'] ?? row['ticket_ref']).toString(), style: contractorMono(10))),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: MukadamDesign.tertiaryFixed, borderRadius: BorderRadius.circular(999)), child: Text((row['severity_tier'] ?? '').toString(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: MukadamDesign.onTertiaryContainer))),
                ]),
                const SizedBox(height: 8),
                Text((row['road_name'] ?? row['address_text'] ?? '—').toString(), style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${zoneName(row) ?? '—'} — ${prabhagName(row) ?? '—'}', style: GoogleFonts.inter(fontSize: 12, color: MukadamDesign.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: MukadamDesign.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(child: Text('₹${((row['rate_per_unit'] as num?) ?? 0).toStringAsFixed(0)}/sqm · ${area.toStringAsFixed(2)} sqm', style: contractorMono(11))),
                    Text(inr((row['estimated_cost'] as num?) ?? 0), style: contractorMono(18, color: MukadamDesign.accent, weight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    status == 'in_progress' ? 'Continue Work →' : 'View Details →',
                    style: GoogleFonts.inter(color: MukadamDesign.onTertiaryContainer, fontWeight: FontWeight.w700),
                  ),
                )
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

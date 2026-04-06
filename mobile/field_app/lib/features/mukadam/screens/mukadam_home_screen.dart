import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../../../services/ticket_service.dart';
import '../mukadam_formatters.dart';
import '../mukadam_prefs.dart';
import '../widgets/mukadam_bottom_nav.dart';

enum _MukadamListFilter { all, assigned, inProgress, completed }

class MukadamHomeScreen extends ConsumerStatefulWidget {
  const MukadamHomeScreen({super.key});

  @override
  ConsumerState<MukadamHomeScreen> createState() => _MukadamHomeScreenState();
}

class _MukadamHomeScreenState extends ConsumerState<MukadamHomeScreen> {
  _MukadamListFilter _filter = _MukadamListFilter.all;
  final Map<String, int> _checklistDone = {};
  Map<String, int> _slaHours = {};

  Future<void> _refreshSlaAndChecklists(MukadamHomeSnapshot snap) async {
    final svc = ref.read(ticketServiceProvider);
    final tiers = snap.rows
        .map((r) => r['severity_tier'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final sla = <String, int>{};
    for (final t in tiers) {
      final h = await svc.fetchSlaResolutionHours(t);
      if (h != null) sla[t] = h;
    }
    if (mounted) setState(() => _slaHours = sla);

    final inProg = snap.rows
        .where((r) => r['status'] == 'in_progress')
        .map((r) => r['id'] as String)
        .toList();
    for (final id in inProg) {
      final list = await loadMukadamChecklist(id);
      final n = list.where((b) => b).length;
      if (mounted) {
        setState(() => _checklistDone[id] = n);
      }
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> rows) {
    switch (_filter) {
      case _MukadamListFilter.all:
        return rows;
      case _MukadamListFilter.assigned:
        return rows.where((r) => r['status'] == 'assigned').toList();
      case _MukadamListFilter.inProgress:
        return rows.where((r) => r['status'] == 'in_progress').toList();
      case _MukadamListFilter.completed:
        return rows.where((r) => r['status'] == 'audit_pending').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapAsync = ref.watch(mukadamHomeProvider);
    final profileAsync = ref.watch(profileProvider);

    ref.listen(mukadamHomeProvider, (prev, next) {
      next.whenData((snap) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshSlaAndChecklists(snap);
        });
      });
    });

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      body: SafeArea(
        child: snapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (snap) {
            if (_slaHours.isEmpty && snap.rows.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _refreshSlaAndChecklists(snap);
              });
            }
            return profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (profile) {
                if (profile == null) {
                  return const Center(child: Text('No profile'));
                }
                final filtered = _applyFilter(
                  snap.rows.map((e) => Map<String, dynamic>.from(e)).toList(),
                );
                final nAssigned =
                    snap.rows.where((r) => r['status'] == 'assigned').length;
                final nProgress =
                    snap.rows.where((r) => r['status'] == 'in_progress').length;
                final nDoneWeek = snap.completedThisWeekCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: MukadamDesign.primaryNavy,
                            child: Text(
                              initialsFromName(profile.fullName),
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Work Orders',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: MukadamDesign.primaryNavy,
                                  ),
                                ),
                                Text(
                                  '${profile.fullName.toUpperCase()} · GANG LEADER',
                                  style: mukadamMono(11,
                                      color: MukadamDesign.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined),
                            color: MukadamDesign.primaryNavy,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _StatChip(
                            color: MukadamDesign.accent,
                            label: '$nAssigned Assigned',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            color: MukadamDesign.primaryNavy,
                            label: '$nProgress In Progress',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            color: MukadamDesign.success,
                            label: '$nDoneWeek Done',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _FilterTab(
                            label: 'All',
                            selected: _filter == _MukadamListFilter.all,
                            onTap: () => setState(
                                () => _filter = _MukadamListFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'Assigned',
                            selected: _filter == _MukadamListFilter.assigned,
                            onTap: () => setState(
                                () => _filter = _MukadamListFilter.assigned),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'In Progress',
                            selected:
                                _filter == _MukadamListFilter.inProgress,
                            onTap: () => setState(
                                () => _filter = _MukadamListFilter.inProgress),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'Completed',
                            selected: _filter == _MukadamListFilter.completed,
                            onTap: () => setState(
                                () => _filter = _MukadamListFilter.completed),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(mukadamHomeProvider);
                          await ref.read(mukadamHomeProvider.future);
                        },
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text('No work orders in this view.'),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 100),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final row = filtered[i];
                                  final id = row['id'] as String;
                                  final jeId = row['assigned_je'] as String?;
                                  final jeName = jeId != null
                                      ? (snap.jeNames[jeId] ?? 'JE')
                                      : 'JE';
                                  return _WorkOrderCard(
                                    row: row,
                                    jeName: jeName,
                                    slaHours: _slaHours[row['severity_tier']
                                        as String?],
                                    checklistDone: _checklistDone[id] ?? 0,
                                    onOpen: () => context
                                        .push('/mukadam/detail/$id'),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const MukadamBottomNav(currentIndex: 0),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: MukadamDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        boxShadow: MukadamDesign.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MukadamDesign.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? MukadamDesign.primaryNavy
                  : MukadamDesign.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : MukadamDesign.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({
    required this.row,
    required this.jeName,
    required this.slaHours,
    required this.checklistDone,
    required this.onOpen,
  });

  final Map<String, dynamic> row;
  final String jeName;
  final int? slaHours;
  final int checklistDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = row['status'] as String? ?? '';
    final refStr = row['ticket_ref'] as String? ?? '';
    final severity = row['severity_tier'] as String?;
    final address = row['address_text'] as String? ?? '—';
    final workType = row['work_type'] as String? ?? '—';
    final dims = dimsFromRow(row);
    final area = dims?.areaSqm;
    final areaStr =
        area != null && area > 0 ? '${area.toStringAsFixed(2)} sqm' : '—';

    Color dueColor = MukadamDesign.onSurfaceVariant;
    String? dueText;
    if (status == 'assigned' && slaHours != null) {
      final created = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (created != null) {
        final deadline = created.toUtc().add(Duration(hours: slaHours!));
        final left = deadline.difference(DateTime.now().toUtc());
        if (left.isNegative) {
          dueText = 'Overdue';
          dueColor = MukadamDesign.error;
        } else {
          final h = left.inHours;
          dueText = h < 1
              ? 'Due in <1h'
              : 'Due in ${h}h';
          dueColor =
              h <= 18 ? MukadamDesign.error : MukadamDesign.onTertiaryContainer;
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: MukadamDesign.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: MukadamDesign.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  color: MukadamDesign.severityBar(severity),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                refStr,
                                style: mukadamMono(11,
                                    color: MukadamDesign.onSurfaceVariant),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: severity == 'CRITICAL'
                                    ? MukadamDesign.error.withValues(alpha: 0.12)
                                    : MukadamDesign.tertiaryFixed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                status == 'in_progress'
                                    ? 'IN PROGRESS'
                                    : severityLabel(severity),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: status == 'in_progress'
                                      ? MukadamDesign.primaryContainer
                                      : (severity == 'CRITICAL'
                                          ? MukadamDesign.error
                                          : MukadamDesign.onTertiaryContainer),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          address,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MukadamDesign.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$workType · $areaStr',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MukadamDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 16,
                                color: MukadamDesign.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Assigned by JE $jeName',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: MukadamDesign.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (status == 'assigned') ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (dueText != null) ...[
                                Icon(Icons.schedule,
                                    size: 16, color: dueColor),
                                const SizedBox(width: 6),
                                Text(
                                  dueText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: dueColor,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                'View Instructions →',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MukadamDesign.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (status == 'in_progress') ...[
                          const SizedBox(height: 12),
                          Text(
                            'PROGRESS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: MukadamDesign.accent,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: checklistDone / 4,
                              minHeight: 6,
                              backgroundColor:
                                  MukadamDesign.surfaceContainerHigh,
                              color: MukadamDesign.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$checklistDone OF 4 STEPS COMPLETE',
                            style: mukadamMono(10,
                                color: MukadamDesign.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Continue Work →',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MukadamDesign.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                        if (status == 'audit_pending') ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'View Instructions →',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MukadamDesign.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

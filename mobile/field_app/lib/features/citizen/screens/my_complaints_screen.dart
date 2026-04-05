import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/citizen_design.dart';
import '../../../models/ticket.dart';
import '../../../providers/ticket_providers.dart';
import '../widgets/citizen_bottom_nav.dart';

enum _ComplaintFilter { all, pending, active, resolved }

class MyComplaintsScreen extends ConsumerStatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  ConsumerState<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends ConsumerState<MyComplaintsScreen> {
  _ComplaintFilter _filter = _ComplaintFilter.all;

  int _horizontalStep(String status) {
    switch (status) {
      case 'open':
        return 0;
      case 'verified':
        return 1;
      case 'assigned':
      case 'in_progress':
        return 2;
      case 'audit_pending':
      case 'resolved':
        return 3;
      default:
        return 0;
    }
  }

  bool _passesFilter(Ticket t) {
    switch (_filter) {
      case _ComplaintFilter.all:
        return true;
      case _ComplaintFilter.pending:
        return t.status == 'open' || t.status == 'verified';
      case _ComplaintFilter.active:
        return t.status == 'assigned' ||
            t.status == 'in_progress' ||
            t.status == 'audit_pending';
      case _ComplaintFilter.resolved:
        return t.status == 'resolved';
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(citizenTicketsProvider);

    return Scaffold(
      backgroundColor: CitizenDesign.surfaceContainerLow,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tickets) {
          final filtered = tickets.where(_passesFilter).toList();
          final activeCount =
              tickets.where((t) => t.status != 'resolved' && t.status != 'rejected').length;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 12, 20, 16),
                color: CitizenDesign.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'My Reports',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: CitizenDesign.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$activeCount active',
                                style: GoogleFonts.inter(
                                  color: CitizenDesign.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.filter_list_rounded)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.menu_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _ComplaintFilter.values.map((f) {
                          final sel = _filter == f;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: sel ? CitizenDesign.accent : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => setState(() => _filter = f),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  child: Text(
                                    f.name[0].toUpperCase() + f.name.substring(1),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: sel ? Colors.white : CitizenDesign.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(onReport: () => context.push('/citizen/report'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final t = filtered[i];
                          return _ComplaintCard(
                            ticket: t,
                            step: _horizontalStep(t.status),
                            onTap: () => context.push('/citizen/tracker?ticketId=${t.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CitizenBottomNav(currentIndex: 2),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({
    required this.ticket,
    required this.step,
    required this.onTap,
  });

  final Ticket ticket;
  final int step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = (ticket.severityTier ?? 'HIGH').toUpperCase();
    final loc = ticket.addressText ?? ticket.roadName ?? 'Location on file';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APPLICATION NUMBER',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: CitizenDesign.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticket.ticketRef,
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: CitizenDesign.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SeverityBadge(status: ticket.status, tier: tier),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: CitizenDesign.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loc,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CitizenDesign.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _HorizontalStepper(currentStep: step, resolved: ticket.status == 'resolved'),
                if (ticket.status == 'resolved' && (ticket.photoAfter ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onTap,
                      child: Text(
                        'View Repair Proof →',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: CitizenDesign.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.status, required this.tier});

  final String status;
  final String tier;

  @override
  Widget build(BuildContext context) {
    if (status == 'resolved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CitizenDesign.severityResolved.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: CitizenDesign.severityResolved),
            const SizedBox(width: 4),
            Text(
              'RESOLVED',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 10,
                color: CitizenDesign.severityResolved,
              ),
            ),
          ],
        ),
      );
    }
    final c = CitizenDesign.severityColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tier,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          color: c,
        ),
      ),
    );
  }
}

class _HorizontalStepper extends StatelessWidget {
  const _HorizontalStepper({required this.currentStep, required this.resolved});

  final int currentStep;
  final bool resolved;

  static const _labels = ['RECEIVED', 'VERIFIED', 'FIXING', 'RESOLVED'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const n = 4;
        final segW = constraints.maxWidth / (n * 2 - 1);
        return SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(n * 2 - 1, (j) {
              if (j.isOdd) {
                final i = j ~/ 2;
                final filled = resolved || i < currentStep;
                return SizedBox(
                  width: segW,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      height: 2,
                      color: filled
                          ? CitizenDesign.accent
                          : CitizenDesign.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                );
              }
              final i = j ~/ 2;
              final done = resolved || i < currentStep;
              final active = !resolved && i == currentStep;
              return SizedBox(
                width: segW * 2,
                child: Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? CitizenDesign.accent : Colors.transparent,
                        border: Border.all(
                          color: done || active ? CitizenDesign.accent : CitizenDesign.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : active
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: CitizenDesign.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                )
                              : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: (done || active)
                            ? CitizenDesign.accent
                            : CitizenDesign.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CitizenDesign.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_road_rounded, size: 36, color: CitizenDesign.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'No more reports',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: CitizenDesign.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Spotted damage? Report it in 30 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: CitizenDesign.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: CitizenDesign.orangeCtaGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onReport,
                    child: Center(
                      child: Text(
                        'Report Damage',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

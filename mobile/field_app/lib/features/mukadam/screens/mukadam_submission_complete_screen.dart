import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../mukadam_formatters.dart';

class MukadamSubmissionCompleteScreen extends ConsumerStatefulWidget {
  const MukadamSubmissionCompleteScreen({
    super.key,
    required this.ticketId,
    required this.submittedAt,
  });

  final String ticketId;
  final DateTime submittedAt;

  @override
  ConsumerState<MukadamSubmissionCompleteScreen> createState() =>
      _MukadamSubmissionCompleteScreenState();
}

class _MukadamSubmissionCompleteScreenState
    extends ConsumerState<MukadamSubmissionCompleteScreen> {
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _je;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(ticketServiceProvider);
    final t = await svc.fetchMukadamTicketDetail(widget.ticketId);
    Map<String, dynamic>? je;
    if (t != null) {
      final jeId = t['assigned_je'] as String?;
      if (jeId != null) je = await svc.fetchProfileById(jeId);
    }
    if (!mounted) return;
    setState(() {
      _ticket = t;
      _je = je;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        backgroundColor: MukadamDesign.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MukadamDesign.primaryNavy),
          onPressed: () => context.go('/mukadam/home'),
        ),
        title: Text(
          'Submission Complete',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: MukadamDesign.primaryNavy,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: MukadamDesign.primaryNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Proof Submitted',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: MukadamDesign.primaryNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Work completion recorded in SMC system',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MukadamDesign.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: MukadamDesign.tertiaryFixed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _ticket?['ticket_ref'] as String? ?? '—',
                      style: mukadamMono(13,
                          color: MukadamDesign.onTertiaryContainer,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MukadamDesign.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: MukadamDesign.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUBMISSION RECEIPT',
                        style: mukadamMono(10,
                            color: MukadamDesign.onSurfaceVariant,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      _receiptRow(
                        'WORK ORDER',
                        _ticket?['ticket_ref'] as String? ?? '—',
                        monoValue: true,
                      ),
                      _receiptRow(
                        'SUBMITTED AT',
                        formatSubmittedAt(widget.submittedAt),
                      ),
                      _receiptRow(
                        'SUBMITTED BY',
                        '${profile?.fullName ?? '—'} · Gang Leader',
                      ),
                      _receiptRow(
                        'ZONE',
                        embeddedZoneName(_ticket ?? {}) ?? '—',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'VERIFICATION',
                            style: mukadamMono(11,
                                color: MukadamDesign.onSurfaceVariant),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: MukadamDesign.tertiaryFixed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'PENDING JE REVIEW',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: MukadamDesign.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: MukadamDesign.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What Happens Next',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MukadamDesign.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _timelineStep(
                        1,
                        Icons.shield_outlined,
                        'JE Site Verification',
                        'JE ${_je?['full_name'] ?? '—'} will visit within 24 hours',
                      ),
                      _timelineStep(
                        2,
                        Icons.visibility_outlined,
                        'Quality Assessment',
                        'Surface quality checked against reported damage',
                      ),
                      _timelineStep(
                        3,
                        Icons.check_circle_outline,
                        'Work Order Closed',
                        'Your work record will be marked complete in SMC',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: MukadamDesign.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go('/mukadam/home'),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Return to Work Orders',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/mukadam/home'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MukadamDesign.primaryNavy,
                    side: const BorderSide(color: MukadamDesign.primaryNavy, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'View Work Order History',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'रोड NIRMAN · OFFICIAL SMC SYSTEM',
                  textAlign: TextAlign.center,
                  style: mukadamMono(10, color: MukadamDesign.onSurfaceVariant),
                ),
              ],
            ),
    );
  }

  Widget _receiptRow(String label, String value, {bool monoValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: mukadamMono(11, color: MukadamDesign.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: monoValue
                  ? mukadamMono(13,
                      color: MukadamDesign.primaryNavy,
                      fontWeight: FontWeight.w700)
                  : GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: MukadamDesign.primaryNavy,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineStep(
    int n,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: MukadamDesign.primaryNavy,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: MukadamDesign.primaryNavy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: MukadamDesign.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MukadamDesign.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

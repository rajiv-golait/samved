import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/citizen_design.dart';

class SubmissionConfirmationScreen extends StatelessWidget {
  const SubmissionConfirmationScreen({super.key, required this.ticket});

  final Map<String, dynamic> ticket;

  @override
  Widget build(BuildContext context) {
    final ref = ticket['ticket_ref'] as String? ?? '—';
    final zoneId = ticket['zone_id'] as int?;
    final prabhagId = ticket['prabhag_id'] as int?;
    final tier = (ticket['severity_tier'] as String? ?? 'HIGH').toString();
    final epdo = (ticket['epdo_score'] as num?)?.toDouble();
    final id = ticket['id'] as String?;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: CitizenDesign.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: CitizenDesign.orangeCtaGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CitizenDesign.accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.verified_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 28),
                Text(
                  'Report Submitted Successfully!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CitizenDesign.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  ref,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CitizenDesign.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Zone ${zoneId ?? '—'} — auto-routed | Prabhag ${prabhagId ?? '—'}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: CitizenDesign.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: CitizenDesign.tertiaryFixed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${tier.toUpperCase()} SEVERITY',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: CitizenDesign.onTertiaryContainer,
                    ),
                  ),
                ),
                if (epdo != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'EPDO score: ${epdo.toStringAsFixed(2)}',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w600,
                      color: CitizenDesign.onSurface,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Expected response within 48 hours',
                  style: GoogleFonts.inter(
                    color: CitizenDesign.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: CitizenDesign.navyGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: id == null
                            ? null
                            : () => context.go('/citizen/tracker?ticketId=$id'),
                        child: Center(
                          child: Text(
                            'Track This Complaint',
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.go('/citizen/home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CitizenDesign.primary,
                      side: const BorderSide(color: CitizenDesign.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Report Another',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
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

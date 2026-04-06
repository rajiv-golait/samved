import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../mukadam_formatters.dart';

class MukadamWorkOrderDetailScreen extends ConsumerStatefulWidget {
  const MukadamWorkOrderDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<MukadamWorkOrderDetailScreen> createState() =>
      _MukadamWorkOrderDetailScreenState();
}

class _MukadamWorkOrderDetailScreenState
    extends ConsumerState<MukadamWorkOrderDetailScreen> {
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _je;
  String? _jeNotes;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final svc = ref.read(ticketServiceProvider);
    try {
      final t = await svc.fetchMukadamTicketDetail(widget.ticketId);
      if (!mounted) return;
      if (t == null) {
        setState(() {
          _ticket = null;
          _error = 'Work order not found.';
          _loading = false;
        });
        return;
      }
      final jeId = t['assigned_je'] as String?;
      Map<String, dynamic>? je;
      if (jeId != null) {
        je = await svc.fetchProfileById(jeId);
      }
      String? notes;
      if (t['je_checkin_time'] != null) {
        notes = await svc.fetchLatestJeCheckinNotes(widget.ticketId);
      }
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _je = je;
        _jeNotes = notes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  int _stepIndex(String status) {
    switch (status) {
      case 'assigned':
        return 0;
      case 'in_progress':
        return 1;
      case 'audit_pending':
        return 2;
      case 'resolved':
        return 3;
      default:
        return 0;
    }
  }

  Future<void> _startDeployment() async {
    if (_acting || _ticket == null) return;
    final profile = await ref.read(profileProvider.future);
    if (!mounted || profile == null) return;
    setState(() => _acting = true);
    try {
      await ref.read(ticketServiceProvider).mukadamStartGangDeployment(
            ticketId: widget.ticketId,
            mukadamFullName: profile.fullName,
          );
      ref.invalidate(mukadamHomeProvider);
      if (!mounted) return;
      context.push('/mukadam/inprogress/${widget.ticketId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _callJe() async {
    final phone = _je?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JE phone not available.')),
      );
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: MukadamDesign.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _ticket == null) {
      return Scaffold(
        backgroundColor: MukadamDesign.background,
        appBar: AppBar(
          backgroundColor: MukadamDesign.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(_error ?? 'Not found')),
      );
    }

    final t = _ticket!;
    final status = t['status'] as String? ?? '';
    final refStr = t['ticket_ref'] as String? ?? '';
    final severity = t['severity_tier'] as String?;
    final zoneName = embeddedZoneName(t) ?? '—';
    final prabhagName = embeddedPrabhagName(t) ?? '—';
    final workType = t['work_type'] as String? ?? '—';
    final address = t['address_text'] as String? ?? '';
    final dims = dimsFromRow(t);
    final areaStr = dims != null && dims.areaSqm > 0
        ? '${dims.areaSqm.toStringAsFixed(2)} sqm'
        : '—';
    final depthCm = dims != null ? (dims.depthM * 100).round() : null;
    final depthStr = depthCm != null ? '$depthCm cm' : '—';
    final lat = (t['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (t['longitude'] as num?)?.toDouble() ?? 0;
    final jeName = _je?['full_name'] as String? ?? 'JE';
    final before = t['photo_before'];
    String? beforeUrl;
    if (before is List && before.isNotEmpty) {
      beforeUrl = before.first.toString();
    }

    final step = _stepIndex(status);
    const labels = [
      'Assigned',
      'Gang Deployed',
      'Work Completed',
      'Verified by JE',
    ];

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: MukadamDesign.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MukadamDesign.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          refStr,
          style: mukadamMono(13, color: MukadamDesign.onSurfaceVariant),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined,
                color: MukadamDesign.onSurface),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: refStr));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Work order reference copied.')),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: beforeUrl != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: beforeUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: MukadamDesign.surfaceContainerHigh,
                                  ),
                                  errorWidget: (_, __, ___) => _photoPlaceholder(),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: MukadamDesign.tertiaryFixed,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${severityLabel(severity)} SEVERITY',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: MukadamDesign.onTertiaryContainer,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.photo_camera_outlined,
                                            color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Before Photo · Citizen Evidence',
                                          style: mukadamMono(10,
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _photoPlaceholder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MukadamDesign.tertiaryFixed,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'WORK ORDER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: MukadamDesign.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Instructions',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MukadamDesign.primaryNavy,
                          ),
                        ),
                        Text(
                          'Issued by JE',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: MukadamDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _grid2(
                          'Zone',
                          zoneName,
                          'Prabhag',
                          prabhagName,
                        ),
                        const SizedBox(height: 10),
                        _grid2(
                          'Work Type',
                          workType,
                          'Area',
                          areaStr,
                        ),
                        const SizedBox(height: 10),
                        _grid2(
                          'Depth',
                          depthStr,
                          'Assigned By',
                          jeName,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                color: MukadamDesign.accent, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  height: 1.35,
                                  color: MukadamDesign.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (lat != 0 && lng != 0) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _openMaps(lat, lng),
                            child: Text(
                              'View Site on Map →',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: MukadamDesign.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MukadamDesign.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: MukadamDesign.primaryNavy),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Executed by SMC Department Work Gang',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MukadamDesign.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Under Mukadam supervision',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: MukadamDesign.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: MukadamDesign.tertiaryFixed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: MukadamDesign.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'THIS IS NOT CONTRACTOR WORK. NO BILLING APPLIES.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: MukadamDesign.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MukadamDesign.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: MukadamDesign.cardShadow,
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JE FIELD NOTES',
                          style: mukadamMono(11,
                              color: MukadamDesign.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        if (t['je_checkin_time'] == null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Column(
                                children: [
                                  Icon(Icons.sticky_note_2_outlined,
                                      size: 40,
                                      color: MukadamDesign.onSurfaceVariant
                                          .withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Notes will appear after site check-in',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontStyle: FontStyle.italic,
                                      color: MukadamDesign.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_jeNotes != null && _jeNotes!.isNotEmpty)
                          Text(
                            _jeNotes!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.4,
                              color: MukadamDesign.onSurface,
                            ),
                          )
                        else
                          Text(
                            'No notes recorded for this check-in.',
                            style: GoogleFonts.inter(
                              fontStyle: FontStyle.italic,
                              color: MukadamDesign.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'WORK PROGRESS',
                    style: mukadamMono(11,
                        color: MukadamDesign.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  _StepperRow(currentStep: step, labels: labels),
                  const SizedBox(height: 20),
                  Material(
                    color: MukadamDesign.primaryNavy,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      onTap: _callJe,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.phone, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              'Contact JE $jeName',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: MukadamDesign.surfaceContainerLowest.withValues(
                      alpha: 0.92),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: _bottomCta(
                  status: status,
                  acting: _acting,
                  onStart: _startDeployment,
                  onProof: () =>
                      context.push('/mukadam/inprogress/${widget.ticketId}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: MukadamDesign.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.photo_camera_outlined,
            size: 48, color: MukadamDesign.onSurfaceVariant),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MukadamDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MukadamDesign.cardShadow,
      ),
      child: child,
    );
  }

  Widget _grid2(String l1, String v1, String l2, String v2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _gridCell(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _gridCell(l2, v2)),
      ],
    );
  }

  Widget _gridCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: mukadamMono(10, color: MukadamDesign.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: MukadamDesign.primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _bottomCta({
    required String status,
    required bool acting,
    required VoidCallback onStart,
    required VoidCallback onProof,
  }) {
    if (status == 'assigned') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: MukadamDesign.accentGradient,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: acting ? null : onStart,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (acting)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else ...[
                        const Icon(Icons.engineering_outlined,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          'START GANG DEPLOYMENT',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activating creates an immutable work start record for GPS-based attendance tracking.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MukadamDesign.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      );
    }
    if (status == 'in_progress') {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: MukadamDesign.primaryGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProof,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Submit Completion Proof →',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (status == 'audit_pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: MukadamDesign.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          'Proof Submitted — Awaiting JE Verification',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: MukadamDesign.onSurfaceVariant,
          ),
        ),
      );
    }
    if (status == 'resolved') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: MukadamDesign.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          'Work order completed',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: MukadamDesign.success,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({required this.currentStep, required this.labels});

  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final isResolvedFlow = currentStep >= 3;
        final stepDone = isResolvedFlow ? true : i < currentStep;
        final stepActive = isResolvedFlow ? false : i == currentStep;
        final stepFuture = isResolvedFlow ? false : i > currentStep;

        Color fill;
        Widget inner;
        if (stepDone) {
          fill = MukadamDesign.accent;
          inner = const Icon(Icons.check, color: Colors.white, size: 16);
        } else if (stepActive) {
          fill = MukadamDesign.primaryNavy;
          inner = _PulseDot();
        } else {
          fill = MukadamDesign.surfaceContainerHigh;
          inner = const SizedBox.shrink();
        }

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: stepFuture
                      ? Border.all(
                          color: MukadamDesign.onSurfaceVariant
                              .withValues(alpha: 0.35),
                          width: 2,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: stepFuture
                    ? null
                    : inner,
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 2,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: MukadamDesign.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

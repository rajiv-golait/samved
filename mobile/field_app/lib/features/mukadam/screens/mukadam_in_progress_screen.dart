import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../mukadam_formatters.dart';
import '../mukadam_prefs.dart';

class MukadamInProgressScreen extends ConsumerStatefulWidget {
  const MukadamInProgressScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<MukadamInProgressScreen> createState() =>
      _MukadamInProgressScreenState();
}

class _MukadamInProgressScreenState extends ConsumerState<MukadamInProgressScreen> {
  Map<String, dynamic>? _ticket;
  Map<String, dynamic>? _je;
  int? _slaHours;
  List<bool> _check = [false, false, false, false];
  final _notes = TextEditingController();
  Timer? _tick;
  bool _loading = true;
  String? _error;

  static const _items = [
    'Base layer cleared and prepared',
    'Repair material applied to surface',
    'Surface compacted and levelled',
    'Site cleaned and debris removed',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final svc = ref.read(ticketServiceProvider);
    try {
      final t = await svc.fetchMukadamTicketDetail(widget.ticketId);
      if (!mounted) return;
      if (t == null || t['status'] != 'in_progress') {
        setState(() {
          _error = 'This work order is not in progress.';
          _loading = false;
        });
        return;
      }
      final jeId = t['assigned_je'] as String?;
      Map<String, dynamic>? je;
      if (jeId != null) je = await svc.fetchProfileById(jeId);
      final sla = await svc.fetchSlaResolutionHours(t['severity_tier'] as String?);
      final saved = await loadMukadamChecklist(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _je = je;
        _slaHours = sla;
        _check = saved;
        _loading = false;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _notes.dispose();
    super.dispose();
  }

  DateTime? get _started {
    final u = _ticket?['updated_at'] as String?;
    if (u == null) return null;
    return DateTime.tryParse(u);
  }

  Future<void> _persistChecklist() async {
    await saveMukadamChecklist(widget.ticketId, _check);
  }

  Future<void> _callJe() async {
    final phone = _je?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JE phone not available.')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  int get _doneCount => _check.where((b) => b).length;

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
          backgroundColor: MukadamDesign.primaryContainer,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text(_error ?? 'Error')),
      );
    }

    final t = _ticket!;
    final refStr = t['ticket_ref'] as String? ?? '';
    final jeName = _je?['full_name'] as String? ?? 'JE';
    final dims = dimsFromRow(t);
    final workType = t['work_type'] as String? ?? '—';
    final areaStr = dims != null && dims.areaSqm > 0
        ? '${dims.areaSqm.toStringAsFixed(2)} sqm'
        : '—';
    final depthCm = dims != null ? (dims.depthM * 100).round() : null;
    final depthStr = depthCm != null ? '$depthCm cm' : '—';

    final start = _started ?? DateTime.now();
    final elapsed = DateTime.now().difference(start);
    final sla = Duration(hours: _slaHours ?? 48);
    final progress = (elapsed.inSeconds / sla.inSeconds).clamp(0.0, 1.0);
    final estEnd = start.add(sla);

    final canSubmit = _doneCount >= 4;

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      appBar: AppBar(
        backgroundColor: MukadamDesign.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IN PROGRESS',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Text(
              refStr,
              style: mukadamMono(12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MukadamDesign.primaryNavy,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'MUKADAM MODE',
                  style: mukadamMono(9,
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MukadamDesign.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: MukadamDesign.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ACTIVE SESSION',
                            style: mukadamMono(11,
                                color: MukadamDesign.onSurfaceVariant,
                                fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          _RecordingDot(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatDurationHms(elapsed),
                        style: mukadamMono(44,
                            color: MukadamDesign.accent,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: MukadamDesign.surfaceContainerHigh,
                          color: MukadamDesign.accent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'STARTED ${formatTimeHm(start.toLocal())}',
                            style: mukadamMono(10,
                                color: MukadamDesign.onSurfaceVariant),
                          ),
                          Text(
                            'EST. END ${formatTimeHm(estEnd.toLocal())}',
                            style: mukadamMono(10,
                                color: MukadamDesign.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Text(
                        'Started at ${formatTimeHm(start.toLocal())} · Today',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MukadamDesign.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MukadamDesign.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _miniStat('TYPE', workType)),
                      Expanded(child: _miniStat('AREA', areaStr)),
                      Expanded(child: _miniStat('DEPTH', depthStr)),
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
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'SITE CHECKLIST',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: MukadamDesign.primaryNavy,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$_doneCount/4 DONE',
                            style: mukadamMono(11,
                                color: MukadamDesign.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < 4; i++)
                        _ChecklistRow(
                          label: _items[i],
                          value: _check[i],
                          onChanged: (v) {
                            setState(() => _check[i] = v);
                            _persistChecklist();
                          },
                        ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: MukadamDesign.tertiaryFixed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$_doneCount of 4 complete',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: MukadamDesign.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'FIELD NOTES (OPTIONAL)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MukadamDesign.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: MukadamDesign.surfaceContainerLow,
                    hintText: 'Add observations or site conditions...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () =>
                        context.push('/mukadam/issue/${widget.ticketId}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Flag a Blocker or Issue',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: Theme.of(context).colorScheme.error),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: MukadamDesign.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _callJe,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: MukadamDesign.primaryNavy,
                            child: Text(
                              initialsFromName(jeName),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'JUNIOR ENGINEER',
                                  style: mukadamMono(10,
                                      color: MukadamDesign.onSurfaceVariant),
                                ),
                                Text(
                                  'Contact JE $jeName',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: MukadamDesign.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.phone, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              decoration: BoxDecoration(
                color: MukadamDesign.surfaceContainerLowest.withValues(alpha: 0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: canSubmit
                          ? MukadamDesign.primaryGradient
                          : null,
                      color: canSubmit ? null : MukadamDesign.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canSubmit
                            ? () {
                                context.push(
                                  '/mukadam/camera/${widget.ticketId}',
                                  extra: {
                                    'fieldNotes': _notes.text.trim().isEmpty
                                        ? null
                                        : _notes.text.trim(),
                                  },
                                );
                              }
                            : null,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Submit Completion Proof →',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: canSubmit
                                      ? Colors.white
                                      : MukadamDesign.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submitting proof is final. Ensure all repairs are complete.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MukadamDesign.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MukadamDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: mukadamMono(9, color: MukadamDesign.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MukadamDesign.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: value ? MukadamDesign.accent : Colors.transparent,
                  border: Border.all(
                    color: value
                        ? MukadamDesign.accent
                        : MukadamDesign.onSurfaceVariant.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: value
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MukadamDesign.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MukadamDesign.accent.withValues(alpha: 0.4 + _c.value * 0.6),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/citizen_design.dart';
import '../../../providers/citizen_providers.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../../../services/citizen_ai_service.dart';

class AIDetectionResultScreen extends ConsumerStatefulWidget {
  const AIDetectionResultScreen({
    super.key,
    required this.imageFile,
    required this.gpsPosition,
  });

  final File imageFile;
  final Position gpsPosition;

  @override
  ConsumerState<AIDetectionResultScreen> createState() => _AIDetectionResultScreenState();
}

class _AIDetectionResultScreenState extends ConsumerState<AIDetectionResultScreen> {
  static const _damageOptions = [
    ('Pothole', 'pothole'),
    ('Crack', 'crack'),
    ('Flooding', 'cave_in'),
    ('Surface', 'surface_failure'),
  ];

  bool _loading = true;
  String? _loadError;
  String? _aiError;
  String? _photoPublicUrl;
  DetectOutcome? _detect;
  SeverityOutcome? _severity;
  late String _selectedDbDamage;
  final Set<String> _quality = {'lighting', 'full', 'steady'};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDbDamage = 'pothole';
    _runPipeline();
  }

  Future<void> _runPipeline() async {
    final net = await Connectivity().checkConnectivity();
    if (net.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CitizenDesign.error,
            content: const Text('No internet connection. Please check your network.'),
          ),
        );
        setState(() {
          _loading = false;
          _loadError = 'offline';
        });
      }
      return;
    }

    final ai = ref.read(citizenAiServiceProvider);
    try {
      final url = await ai.uploadScanImage(widget.imageFile);
      _photoPublicUrl = url;

      DetectOutcome det;
      SeverityOutcome sev;
      try {
        det = await ai.detectRoadDamage(url);
        if (!det.success || det.errors.isNotEmpty) {
          _aiError = det.errors.join('\n');
          det = DetectOutcome(success: false, errors: det.errors);
        }
      } catch (_) {
        _aiError = 'Detection unreachable';
        det = const DetectOutcome(success: false, errors: ['Detection unreachable']);
      }

      final dmg = det.detected ? det.damageType : 'pothole';
      final mapped = _damageDbFromAi(dmg);

      try {
        if (det.success && det.detected) {
          sev = await ai.scoreSeverity(
            damageType: det.damageType,
            aiConfidence: det.aiConfidence,
            totalPotholes: det.totalPotholes,
            aiSeverityIndex: det.aiSeverityIndex,
            lat: widget.gpsPosition.latitude,
            lng: widget.gpsPosition.longitude,
          );
          if (!sev.success) {
            _aiError =
                sev.errors.isNotEmpty ? sev.errors.join('\n') : 'Severity unreachable';
            sev = const SeverityOutcome(success: false, errors: ['Severity unreachable']);
          }
        } else {
          sev = const SeverityOutcome(
            success: true,
            epdoScore: 0,
            severityTier: 'MEDIUM',
            slaHours: 48,
          );
        }
      } catch (_) {
        _aiError = 'Severity unreachable';
        sev = const SeverityOutcome(success: false, errors: ['Severity unreachable']);
      }

      if (mounted) {
        setState(() {
          _detect = det;
          _selectedDbDamage = mapped;
          _severity = sev.success
              ? sev
              : const SeverityOutcome(success: true, epdoScore: 0, severityTier: 'MEDIUM', slaHours: 48);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: CitizenDesign.error, content: Text('Upload failed: $e')),
        );
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  String _damageDbFromAi(String damageType) {
    final d = damageType.toLowerCase();
    if (d.contains('crack')) return 'crack';
    if (d.contains('flood') || d.contains('cave')) return 'cave_in';
    if (d.contains('surface')) return 'surface_failure';
    if (d.contains('pothole')) return 'pothole';
    return 'pothole';
  }

  String _treatmentLine(String db) {
    switch (db) {
      case 'crack':
        return 'Crack sealing / fog seal — approx ₹180–320 / sqm (indicative)';
      case 'cave_in':
        return 'Drainage relief + patch — approx ₹400–900 / sqm (indicative)';
      case 'surface_failure':
        return 'Milling & resurfacing — approx ₹550–1200 / sqm (indicative)';
      default:
        return 'Bituminous / cold-mix patch — approx ₹350–800 / sqm (indicative)';
    }
  }

  Future<void> _submit() async {
    if (_photoPublicUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CitizenDesign.error,
          content: Text('Photo not ready. Please retake or retry.'),
        ),
      );
      return;
    }

    final profile = await ref.read(profileProvider.future);
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final det = _detect;
    final sev = _severity;
    final aiOk = det != null && det.success && det.detected && sev != null && sev.success;

    setState(() => _submitting = true);

    try {
      final lat = widget.gpsPosition.latitude;
      final lng = widget.gpsPosition.longitude;
      final locationEwkt = 'SRID=4326;POINT(${lng.toStringAsFixed(7)} ${lat.toStringAsFixed(7)})';

      final payload = <String, dynamic>{
        'citizen_id': uid,
        'citizen_phone': profile?.phone,
        'source_channel': 'app',
        'latitude': lat,
        'longitude': lng,
        'location': locationEwkt,
        'damage_type': _selectedDbDamage,
        'photo_before': [_photoPublicUrl],
        'status': 'open',
        'department_id': 1,
        'ai_source': aiOk ? det.aiSource : 'OFFLINE_ESTIMATE',
        'ai_confidence': aiOk ? det.aiConfidence : null,
        'ai_severity_index': aiOk ? det.aiSeverityIndex : null,
        'total_potholes': aiOk ? det.totalPotholes : null,
        'epdo_score': aiOk ? sev.epdoScore : null,
        'severity_tier': aiOk ? sev.severityTier : null,
      };

      final result = await client.from('tickets').insert(payload).select().single();

      if (mounted) {
        // Ensure the lists refresh even before realtime callback.
        ref.invalidate(citizenTicketsProvider);
        ref.invalidate(jeInboxProvider);
        context.push('/citizen/confirmation', extra: Map<String, dynamic>.from(result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CitizenDesign.error,
            content: Text('Could not submit: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final detected = _detect?.detected ?? (_loadError != null ? false : true);
    final conf = ((_detect?.aiConfidence ?? 0) * 100).clamp(0, 100).round();
    final potholes = _detect?.totalPotholes ?? 0;
    final epdo = _severity?.epdoScore ?? 0;
    final slaH = _severity?.slaHours ?? 48;
    final tier = (_severity?.severityTier ?? 'HIGH').toUpperCase();

    return Scaffold(
      backgroundColor: CitizenDesign.primary,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (_, __) => const SizedBox.shrink(),
        data: (_) => Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.sizeOf(context).height * 0.4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.cover),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScanFramePainter(),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu_rounded, color: Colors.white),
                            onPressed: () {},
                          ),
                          Expanded(
                            child: Text(
                              'ROAD SCANNER',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.5,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: CitizenDesign.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, -4)),
                    ],
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          children: [
                            if (_aiError != null && _aiError!.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: CitizenDesign.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'AI service issue:\n$_aiError\n\nYou can still submit a report, but detection may show zeros.',
                                  style: GoogleFonts.inter(
                                    color: CitizenDesign.error,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  detected ? Icons.check_circle : Icons.cancel,
                                  color: detected ? CitizenDesign.severityLow : CitizenDesign.error,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    detected ? 'Pothole Detected' : 'No Road Detected',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: CitizenDesign.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: CitizenDesign.tertiaryFixed,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$tier SEVERITY',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: CitizenDesign.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                _StatCard(label: 'POTHOLES', value: '$potholes'),
                                const SizedBox(width: 10),
                                _StatCard(label: 'CONFIDENCE', value: '$conf%'),
                                const SizedBox(width: 10),
                                _StatCard(label: 'EPDO', value: epdo.toStringAsFixed(2)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded, size: 18, color: CitizenDesign.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Response required within $slaH hours',
                                    style: GoogleFonts.inter(
                                      color: CitizenDesign.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _LocationCard(
                              lat: widget.gpsPosition.latitude,
                              lng: widget.gpsPosition.longitude,
                              accuracyM: widget.gpsPosition.accuracy,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'TYPE OF DAMAGE?',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: CitizenDesign.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.8,
                              children: _damageOptions.map((o) {
                                final sel = _selectedDbDamage == o.$2;
                                return Material(
                                  color: sel ? CitizenDesign.primary : CitizenDesign.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => setState(() => _selectedDbDamage = o.$2),
                                    child: Center(
                                      child: Text(
                                        o.$1,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: sel ? Colors.white : CitizenDesign.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'QUALITY CHECKLIST',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: CitizenDesign.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _EmojiPill(
                                  label: '☀️ Good lighting',
                                  selected: _quality.contains('lighting'),
                                  onTap: () => setState(() {
                                    _quality.contains('lighting') ? _quality.remove('lighting') : _quality.add('lighting');
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _EmojiPill(
                                  label: '📐 Full damage',
                                  selected: _quality.contains('full'),
                                  onTap: () => setState(() {
                                    _quality.contains('full') ? _quality.remove('full') : _quality.add('full');
                                  }),
                                ),
                                const SizedBox(width: 8),
                                _EmojiPill(
                                  label: '🎯 Steady shot',
                                  selected: _quality.contains('steady'),
                                  onTap: () => setState(() {
                                    _quality.contains('steady') ? _quality.remove('steady') : _quality.add('steady');
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: CitizenDesign.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: const Border(
                                  left: BorderSide(color: CitizenDesign.accent, width: 4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recommended treatment',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: CitizenDesign.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _treatmentLine(_selectedDbDamage),
                                    style: GoogleFonts.inter(
                                      color: CitizenDesign.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                    onTap: _submitting ? null : _submit,
                                    child: Center(
                                      child: _submitting
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              'Submit Report',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
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
                                onPressed: _submitting
                                    ? null
                                    : () {
                                        context.pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: CitizenDesign.primary,
                                  side: const BorderSide(color: CitizenDesign.outlineVariant),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: Text(
                                  'Retake Photo',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'GPS + photo will be attached',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: CitizenDesign.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: CitizenDesign.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: CitizenDesign.onSurfaceVariant,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: CitizenDesign.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard({
    required this.lat,
    required this.lng,
    required this.accuracyM,
  });

  final double lat;
  final double lng;
  final double accuracyM;

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        return Opacity(opacity: 0.5 + _pulse.value * 0.5, child: child);
                      },
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: CitizenDesign.severityLow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Location Captured',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: CitizenDesign.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.lat.toStringAsFixed(4)}° N, ${widget.lng.toStringAsFixed(4)}° E',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CitizenDesign.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accuracy: ±${widget.accuracyM.toStringAsFixed(0)} metres',
                  style: GoogleFonts.inter(
                    color: CitizenDesign.severityLow,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 72,
              height: 72,
              color: CitizenDesign.surfaceContainerLow,
              child: Icon(Icons.map_rounded, color: CitizenDesign.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiPill extends StatelessWidget {
  const _EmojiPill({
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
        color: selected ? CitizenDesign.tertiaryFixed : CitizenDesign.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CitizenDesign.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final w = size.width * 0.72;
    final h = size.height * 0.45;
    final left = (size.width - w) / 2;
    final top = size.height * 0.12;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(4),
    );
    canvas.drawRRect(r, paint);
    const bracket = 18.0;
    // corners
    for (final corner in [
      Offset(left, top),
      Offset(left + w, top),
      Offset(left, top + h),
      Offset(left + w, top + h),
    ]) {
      final path = Path();
      if (corner.dx == left && corner.dy == top) {
        path.moveTo(corner.dx, corner.dy + bracket);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx + bracket, corner.dy);
      } else if (corner.dx > left && corner.dy == top) {
        path.moveTo(corner.dx - bracket, corner.dy);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx, corner.dy + bracket);
      } else if (corner.dx == left) {
        path.moveTo(corner.dx, corner.dy - bracket);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx + bracket, corner.dy);
      } else {
        path.moveTo(corner.dx - bracket, corner.dy);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx, corner.dy - bracket);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

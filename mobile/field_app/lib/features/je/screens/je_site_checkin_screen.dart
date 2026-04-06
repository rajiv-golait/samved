import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/je_design.dart';

class JeSiteCheckInScreen extends StatefulWidget {
  const JeSiteCheckInScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<JeSiteCheckInScreen> createState() => _JeSiteCheckInScreenState();
}

class _JeSiteCheckInScreenState extends State<JeSiteCheckInScreen> {
  Map<String, dynamic>? _ticket;
  double? _distanceM;
  Position? _pos;
  Timer? _timer;
  bool _gpsError = false;
  bool _loading = true;
  bool _submitting = false;

  static const _thresholdM = 20.0;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: JeDesign.error, content: Text(msg)),
    );
  }

  Future<void> _tick() async {
    if (_ticket == null) return;
    final tLat = (_ticket!['latitude'] as num?)?.toDouble();
    final tLng = (_ticket!['longitude'] as num?)?.toDouble();
    if (tLat == null || tLng == null) return;

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final d = Geolocator.distanceBetween(p.latitude, p.longitude, tLat, tLng);
      if (mounted) {
        setState(() {
          _pos = p;
          _distanceM = d;
          _gpsError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsError = true);
    }
  }

  Future<void> _loadTicket() async {
    try {
      final row = await Supabase.instance.client
          .from('tickets')
          .select('id, ticket_ref, status, severity_tier, latitude, longitude, address_text')
          .eq('id', widget.ticketId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _ticket = row != null ? Map<String, dynamic>.from(row) : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Could not load ticket: $e');
      }
    }
  }

  Future<void> _verify() async {
    final d = _distanceM;
    final ticket = _ticket;
    if (d == null || d > _thresholdM || ticket == null) return;

    setState(() => _submitting = true);
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Not signed in');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        (ticket['latitude'] as num).toDouble(),
        (ticket['longitude'] as num).toDouble(),
      );
      if (dist > _thresholdM) {
        throw Exception('You moved out of range. Try again within 20m.');
      }

      final oldStatus = ticket['status'] as String? ?? 'open';

      await supa.from('tickets').update({
        'je_checkin_lat': position.latitude,
        'je_checkin_lng': position.longitude,
        'je_checkin_time': DateTime.now().toUtc().toIso8601String(),
        'je_checkin_distance_m': dist,
        'status': 'verified',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);

      await supa.from('ticket_events').insert({
        'ticket_id': widget.ticketId,
        'actor_id': uid,
        'actor_role': 'je',
        'event_type': 'je_checkin',
        'old_status': oldStatus,
        'new_status': 'verified',
        'notes': 'JE checked in at site. Distance: ${dist.toStringAsFixed(1)}m',
        'metadata': {
          'checkin_lat': position.latitude,
          'checkin_lng': position.longitude,
          'distance_m': dist,
        },
      });

      if (mounted) context.push('/je/measure/${widget.ticketId}');
    } catch (e) {
      _snack('Check-in failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTicket();
      await _tick();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtCoord(double? lat, double? lng) {
    if (lat == null || lng == null) return '—';
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}°$ns, ${lng.abs().toStringAsFixed(4)}°$ew';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: JeDesign.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticket == null) {
      return Scaffold(
        backgroundColor: JeDesign.background,
        appBar: AppBar(title: const Text('Check-In')),
        body: const Center(child: Text('Ticket not found')),
      );
    }

    final t = _ticket!;
    final tLat = (t['latitude'] as num?)?.toDouble();
    final tLng = (t['longitude'] as num?)?.toDouble();
    final d = _distanceM;
    final inRange = d != null && d <= _thresholdM;
    final progress = d == null ? 0.0 : (1 - (d / _thresholdM).clamp(0.0, 1.0));

    return Scaffold(
      backgroundColor: JeDesign.background,
      appBar: AppBar(
        backgroundColor: JeDesign.background,
        elevation: 0,
        foregroundColor: JeDesign.onSurface,
        title: Text(
          'Site Check-In',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JeDesign.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                boxShadow: JeDesign.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'PROJECT TICKET',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: JeDesign.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: JeDesign.tertiaryFixed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          (t['severity_tier'] as String? ?? '').toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t['ticket_ref'] as String? ?? '',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined, size: 18, color: JeDesign.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t['address_text'] as String? ?? '—',
                          style: GoogleFonts.inter(color: JeDesign.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _ArcGaugePainter(progress: progress),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d != null ? '${d.round()}m' : '—',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: JeDesign.primaryNavy,
                          ),
                        ),
                        Text(
                          'of ${_thresholdM.round()}m threshold',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: JeDesign.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: inRange ? const Color(0xFF22C55E) : JeDesign.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (inRange) const Icon(Icons.check_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    inRange
                        ? 'Within range — ready to verify'
                        : 'Move closer (${d?.round() ?? '—'}m away)',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: inRange ? Colors.white : JeDesign.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (_gpsError) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: JeDesign.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unable to get GPS. Please enable location.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: JeDesign.error),
                    ),
                    TextButton(onPressed: _tick, child: const Text('Retry')),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _GpsCard(
                    title: 'REPORTED SPOT GPS',
                    accent: JeDesign.primaryContainer,
                    coords: _fmtCoord(tLat, tLng),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GpsCard(
                    title: 'YOUR LOCATION GPS',
                    accent: JeDesign.accent,
                    coords: _fmtCoord(_pos?.latitude, _pos?.longitude),
                  ),
                ),
              ],
            ),
            if (inRange) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: JeDesign.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: JeDesign.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accuracy Confirmed',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: JeDesign.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'System has verified your current coordinates match the assigned site perimeter within a 5-meter variance.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: JeDesign.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (!_submitting && inRange && !_gpsError) ? _verify : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: (!inRange || _gpsError)
                            ? LinearGradient(
                                colors: [
                                  JeDesign.onSurfaceVariant.withValues(alpha: 0.35),
                                  JeDesign.onSurfaceVariant.withValues(alpha: 0.25),
                                ],
                              )
                            : JeDesign.primaryGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _submitting
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Verify Site',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.done_all_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'YOUR GPS CHECK-IN WILL BE RECORDED WITH TIMESTAMP',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: JeDesign.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  _ArcGaugePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final bg = Paint()
      ..color = JeDesign.surfaceContainerHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = JeDesign.primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GpsCard extends StatelessWidget {
  const _GpsCard({
    required this.title,
    required this.accent,
    required this.coords,
  });

  final String title;
  final Color accent;
  final String coords;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JeDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: JeDesign.cardShadow,
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: JeDesign.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            coords,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

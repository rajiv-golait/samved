import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/status_labels.dart';
import '../../../core/theme/je_design.dart';
import '../../../models/ticket.dart';
import '../../../providers/providers.dart';
import '../widgets/je_bottom_nav.dart';

class JeHomeScreen extends ConsumerStatefulWidget {
  const JeHomeScreen({super.key});

  @override
  ConsumerState<JeHomeScreen> createState() => _JeHomeScreenState();
}

class _JeHomeScreenState extends ConsumerState<JeHomeScreen> {
  static const _solapur = LatLng(17.6823, 75.9064);
  final _mapController = MapController();

  List<Ticket> _tickets = [];
  bool _loading = true;
  String? _error;
  Position? _pos;
  RealtimeChannel? _channel;
  bool _distanceSort = false;

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'JE';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  void _snack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? JeDesign.error : JeDesign.primaryContainer,
        content: Text(msg),
      ),
    );
  }

  Future<void> _loadGps() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _pos = p);
    } catch (_) {}
  }

  Future<void> _loadTickets(int zoneId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(ticketServiceProvider).fetchJeZoneTickets(zoneId);
      _applySort(list);
      if (mounted) setState(() => _tickets = list);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
        _snack('Could not load tickets: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySort(List<Ticket> list) {
    if (!_distanceSort || _pos == null) return;
    list.sort((a, b) {
      final da = Geolocator.distanceBetween(
        _pos!.latitude,
        _pos!.longitude,
        a.latitude,
        a.longitude,
      );
      final db = Geolocator.distanceBetween(
        _pos!.latitude,
        _pos!.longitude,
        b.latitude,
        b.longitude,
      );
      return da.compareTo(db);
    });
  }

  void _subscribeRealtime(int zoneId) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('je_tickets_zone_$zoneId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tickets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'zone_id',
            value: zoneId.toString(),
          ),
          callback: (_) {
            _loadTickets(zoneId);
          },
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final profile = await ref.read(profileProvider.future);
    final z = profile?.zoneId;
    if (z == null) {
      setState(() {
        _loading = false;
        _error = 'No zone assigned to your profile.';
      });
      return;
    }
    await _loadGps();
    await _loadTickets(z);
    _subscribeRealtime(z);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters['optimize'] == '1') {
        setState(() => _distanceSort = true);
      }
      await _bootstrap();
      if (mounted && uri.queryParameters['tab'] == '1') {
        _mapController.move(_solapur, 13);
      }
    });
  }

  double? _distanceKm(Ticket t) {
    if (_pos == null) return null;
    final m = Geolocator.distanceBetween(
      _pos!.latitude,
      _pos!.longitude,
      t.latitude,
      t.longitude,
    );
    return m / 1000;
  }

  int get _pendingCount =>
      _tickets.where((t) => t.status != 'resolved' && t.status != 'rejected').length;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final uri = GoRouterState.of(context).uri;
    final mapTab = uri.queryParameters['tab'] == '1';
    final mapFraction = mapTab ? 0.58 : 0.42;

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: JeDesign.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: JeDesign.background,
        body: Center(child: Text('$e')),
      ),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(
            backgroundColor: JeDesign.background,
            body: Center(child: Text('No profile')),
          );
        }
        final z = profile.zoneId ?? 0;
        final navIndex = JeBottomNav.indexFromLocation(
          GoRouterState.of(context).uri.path,
          GoRouterState.of(context).uri.toString(),
        );

        return Scaffold(
          backgroundColor: JeDesign.background,
          extendBody: true,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: JeDesign.primaryContainer,
                            child: Text(
                              _initials(profile.fullName),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zone $z Tasks',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: JeDesign.onSurface,
                                  ),
                                ),
                                Text(
                                  profile.fullName.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: JeDesign.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined),
                            color: JeDesign.primaryNavy,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * mapFraction,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _solapur,
                          initialZoom: 13,
                          interactionOptions:
                              const InteractionOptions(flags: InteractiveFlag.all),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'in.solapur.roadnirman.field',
                          ),
                          MarkerLayer(
                            markers: [
                              if (_pos != null)
                                Marker(
                                  point: LatLng(_pos!.latitude, _pos!.longitude),
                                  width: 24,
                                  height: 24,
                                  child: _PulseDot(),
                                ),
                              ..._tickets.map(
                                (t) => Marker(
                                  point: LatLng(t.latitude, t.longitude),
                                  width: 32,
                                  height: 32,
                                  child: GestureDetector(
                                    onTap: () => context.push('/je/ticket/${t.id}'),
                                    child: Icon(
                                      Icons.place,
                                      color: JeDesign.severityBarColor(t.severityTier),
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(color: JeDesign.error),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await _loadGps();
                                  if (profile.zoneId != null) {
                                    await _loadTickets(profile.zoneId!);
                                  }
                                },
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'CURRENT QUEUE',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.6,
                                                  color: JeDesign.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Zonal Tickets',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w800,
                                                  color: JeDesign.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: JeDesign.surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            '$_pendingCount PENDING',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ..._tickets.map((t) => _TicketCard(
                                          ticket: t,
                                          distanceKm: _distanceKm(t),
                                          onTap: () => context.push('/je/ticket/${t.id}'),
                                        )),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8 + 72 + MediaQuery.sizeOf(context).height * mapFraction * 0.06,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: JeDesign.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: JeDesign.cardShadow,
                    ),
                    child: Text(
                      '${_tickets.length} tickets • ${_distanceSort ? 'Nearest first' : 'By EPDO priority'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: JeDesign.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 100,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await _loadGps();
                      setState(() => _distanceSort = true);
                      if (profile.zoneId != null) {
                        await _loadTickets(profile.zoneId!);
                      }
                      _snack('Sorted by distance from your location', error: false);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: JeDesign.primaryGradient,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: JeDesign.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ROUTE OPTIMIZE',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: JeBottomNav(currentIndex: navIndex),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

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
        final v = _c.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 18 + v * 10,
              height: 18 + v * 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.25 * (1 - v)),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.distanceKm,
    required this.onTap,
  });

  final Ticket ticket;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bar = JeDesign.severityBarColor(ticket.severityTier);
    final tier = (ticket.severityTier ?? '').toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: JeDesign.surfaceContainerLowest,
        elevation: 0,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: JeDesign.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: bar),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket.ticketRef,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: JeDesign.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: JeDesign.severityBadgeBg(ticket.severityTier),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tier.isEmpty ? '—' : tier,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: tier == 'CRITICAL'
                                          ? JeDesign.error
                                          : tier == 'HIGH'
                                              ? JeDesign.onTertiaryContainer
                                              : JeDesign.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket.roadName?.trim().isNotEmpty == true
                                  ? ticket.roadName!
                                  : (ticket.addressText ?? '—'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: JeDesign.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.navigation_rounded,
                                    size: 16, color: JeDesign.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  distanceKm != null
                                      ? '${distanceKm!.toStringAsFixed(1)} km away'
                                      : '— km away',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: JeDesign.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.schedule_rounded,
                                    size: 16, color: JeDesign.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel(ticket.status),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: JeDesign.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/citizen_design.dart';
import '../../../providers/citizen_providers.dart';
import '../../../providers/providers.dart';
import '../widgets/citizen_bottom_nav.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  static const _solapur = LatLng(17.6823, 75.9064);
  final _mapController = MapController();
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _loadGps();
  }

  Future<void> _loadGps() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _userPos = p);
    } catch (_) {}
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'C';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  Color _pinColor(String? tier) => CitizenDesign.severityColor(tier);

  double? _distanceKm(double? lat, double? lng) {
    if (_userPos == null || lat == null || lng == null) return null;
    final m = Geolocator.distanceBetween(_userPos!.latitude, _userPos!.longitude, lat, lng);
    return m / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final pinsAsync = ref.watch(citizenMapPinsProvider);
    final nearbyAsync = ref.watch(citizenNearbyTicketsProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile')));
        }
        if (profile.role == 'citizen') {
          final user = Supabase.instance.client.auth.currentUser;
          final regDone = user?.userMetadata?['registration_complete'] == true;
          if (!regDone) {
            final phone = user?.phone ?? profile.phone ?? '';
            if (phone.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.go('/register/details?phone=${Uri.encodeComponent(phone)}');
                }
              });
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
          }
        }
        return Scaffold(
          extendBody: true,
          backgroundColor: CitizenDesign.surfaceContainerLow,
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _solapur,
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'in.solapur.roadnirman.field',
                    ),
                    MarkerLayer(
                      markers: [
                        ...pinsAsync.maybeWhen(
                          data: (rows) => rows.map((m) {
                            final lat = (m['latitude'] as num?)?.toDouble();
                            final lng = (m['longitude'] as num?)?.toDouble();
                            if (lat == null || lng == null) {
                              return null;
                            }
                            final tier = m['severity_tier'] as String?;
                            final c = _pinColor(tier);
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 36,
                              height: 36,
                              child: _SeverityPin(color: c, tier: tier),
                            );
                          }).whereType<Marker>(),
                          orElse: () => <Marker>[],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: CitizenDesign.primaryContainer.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.white,
                            foregroundColor: CitizenDesign.primary,
                            child: Text(
                              _initials(profile.fullName),
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'नमस्कार',
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  profile.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.45,
                minChildSize: 0.16,
                maxChildSize: 0.92,
                builder: (context, scrollController) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          border: Border(
                            top: BorderSide(color: CitizenDesign.outlineVariant.withValues(alpha: 0.35)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: CitizenDesign.outlineVariant,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Complaints near you',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        color: CitizenDesign.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: CitizenDesign.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'SOLAPUR DISTRICT',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: CitizenDesign.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: nearbyAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text('$e')),
                                data: (rows) {
                                  if (rows.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No open complaints in this view.',
                                        style: GoogleFonts.inter(color: CitizenDesign.onSurfaceVariant),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                    itemCount: rows.length,
                                    itemBuilder: (context, i) {
                                      final t = rows[i];
                                      final refStr = t['ticket_ref'] as String? ?? '';
                                      final tier = t['severity_tier'] as String?;
                                      final addr = (t['road_name'] as String?)?.trim().isNotEmpty == true
                                          ? t['road_name'] as String
                                          : (t['address_text'] as String? ?? 'Location on map');
                                      final photos = t['photo_before'];
                                      String? thumb;
                                      if (photos is List && photos.isNotEmpty) {
                                        thumb = photos.first.toString();
                                      }
                                      final lat = (t['latitude'] as num?)?.toDouble();
                                      final lng = (t['longitude'] as num?)?.toDouble();
                                      final dKm = _distanceKm(lat, lng);
                                      final distLabel = dKm != null
                                          ? '${dKm.toStringAsFixed(1)} km away • $addr'
                                          : addr;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Material(
                                          color: Colors.white,
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
                                          borderRadius: BorderRadius.circular(16),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () => context.push(
                                              '/citizen/tracker?ticketId=${t['id']}',
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
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
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: SizedBox(
                                                      width: 72,
                                                      height: 72,
                                                      child: thumb != null
                                                          ? CachedNetworkImage(
                                                              imageUrl: thumb,
                                                              fit: BoxFit.cover,
                                                              errorWidget: (_, __, ___) => Container(
                                                                color: CitizenDesign.surfaceContainerLow,
                                                                child: const Icon(Icons.image_not_supported),
                                                              ),
                                                            )
                                                          : Container(
                                                              color: CitizenDesign.surfaceContainerLow,
                                                              child: const Icon(Icons.add_road_rounded),
                                                            ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          refStr,
                                                          style: GoogleFonts.jetBrainsMono(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 12,
                                                            color: CitizenDesign.primary,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        _SeverityLine(tier: tier),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.place_outlined,
                                                              size: 14,
                                                              color: CitizenDesign.onSurfaceVariant,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                distLabel,
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 12,
                                                                  color: CitizenDesign.onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: MediaQuery.paddingOf(context).bottom + 88,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: CitizenDesign.orangeCtaGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: CitizenDesign.accent.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/citizen/report'),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, color: CitizenDesign.accent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '+ Report Road Damage',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: CitizenBottomNav(currentIndex: 0),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeverityPin extends StatelessWidget {
  const _SeverityPin({required this.color, this.tier});

  final Color color;
  final String? tier;

  @override
  Widget build(BuildContext context) {
    final pulse = (tier ?? '').toUpperCase() == 'CRITICAL';
    return pulse
        ? _PulsingPin(color: color)
        : Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.place, color: Colors.white, size: 20),
          );
  }
}

class _PulsingPin extends StatefulWidget {
  const _PulsingPin({required this.color});
  final Color color;

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final s = 1.0 + _c.value * 0.12;
        return Transform.scale(
          scale: s,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.place, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SeverityLine extends StatelessWidget {
  const _SeverityLine({this.tier});
  final String? tier;

  @override
  Widget build(BuildContext context) {
    final t = (tier ?? 'HIGH').toUpperCase();
    final c = CitizenDesign.severityColor(t);
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: c),
        const SizedBox(width: 4),
        Text(
          t == 'CRITICAL' ? 'CRITICAL REPAIR' : '$t PRIORITY',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ],
    );
  }
}

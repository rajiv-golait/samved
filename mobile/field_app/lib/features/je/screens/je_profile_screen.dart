import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/je_design.dart';
import '../../../providers/providers.dart';
import '../widgets/je_bottom_nav.dart';

class JeProfileScreen extends ConsumerWidget {
  const JeProfileScreen({super.key});

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'JE';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
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
        return Scaffold(
          backgroundColor: JeDesign.background,
          appBar: AppBar(
            backgroundColor: JeDesign.background,
            foregroundColor: JeDesign.onSurface,
            elevation: 0,
            title: Text(
              'Profile',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: JeDesign.primaryContainer,
                  child: Text(
                    _initials(profile.fullName),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.fullName,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: JeDesign.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JUNIOR ENGINEER · ZONE ${profile.zoneId ?? '—'}',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: JeDesign.onSurfaceVariant,
                ),
              ),
              if (profile.phone != null) ...[
                const SizedBox(height: 8),
                Text(
                  profile.phone!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: JeDesign.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) context.go('/login');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: JeDesign.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  'Log out',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const JeBottomNav(currentIndex: 3),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/auth_brand_header.dart';
import '../../core/constants/role_config.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (!mounted) return;
    if (session == null) {
      context.go('/login');
      return;
    }

    final profile = await ref.read(authServiceProvider).fetchProfile();
    if (!mounted) return;

    if (profile == null) {
      context.go('/blocked', extra: 'No profile row for this account.');
      return;
    }
    if (!profile.isActive) {
      context.go('/blocked', extra: 'This account is inactive.');
      return;
    }
    if (!isMobileRole(profile.role) && !isWebHandoffRole(profile.role)) {
      context.go('/blocked', extra: 'Unknown role: ${profile.role}');
      return;
    }

    if (profile.role == 'citizen') {
      final user = Supabase.instance.client.auth.currentUser;
      final regDone = user?.userMetadata?['registration_complete'] == true;
      if (!regDone) {
        final phone = user?.phone?.trim();
        final fallback = profile.phone?.trim();
        final p = (phone != null && phone.isNotEmpty) ? phone : (fallback ?? '');
        if (p.isNotEmpty) {
          context.go('/register/details?phone=${Uri.encodeComponent(p)}');
          return;
        }
      }
    }

    ref.invalidate(profileProvider);

    if (isWebHandoffRole(profile.role)) {
      context.go('/handoff');
      return;
    }

    switch (profile.role) {
      case 'citizen':
        context.go('/citizen/home');
        break;
      case 'je':
        context.go('/je');
        break;
      case 'mukadam':
        context.go('/mukadam');
        break;
      case 'contractor':
        context.go('/contractor');
        break;
      default:
        context.go('/blocked', extra: 'Unsupported role.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          const AuthBrandHeader(bottomPadding: 44, compactLogo: true),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your workspace…',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
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
}

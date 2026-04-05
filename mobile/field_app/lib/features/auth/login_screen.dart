import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/auth_brand_header.dart';
import '../../core/widgets/gradient_primary_button.dart';
import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _CitizenAuthMode { signIn, register }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _digits = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _loading = false;
  String? _error;
  _CitizenAuthMode _mode = _CitizenAuthMode.signIn;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _digits.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  String get _e164 {
    final d = _digits.text.replaceAll(RegExp(r'\D'), '');
    return '+91$d';
  }

  Future<void> _sendOtp() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final d = _digits.text.replaceAll(RegExp(r'\D'), '');
    if (d.length != 10) {
      setState(() {
        _error = 'Enter a valid 10-digit mobile number.';
        _loading = false;
      });
      return;
    }
    try {
      final registered =
          await ref.read(authServiceProvider).citizenPhoneRegistered(_e164);
      if (!mounted) return;
      if (registered != null) {
        if (_mode == _CitizenAuthMode.signIn && !registered) {
          setState(() {
            _error =
                'No account for this number. Choose “Create account” to register first.';
            _loading = false;
          });
          return;
        }
        if (_mode == _CitizenAuthMode.register && registered) {
          setState(() {
            _error =
                'This number is already registered. Choose “Sign in” to get an OTP.';
            _loading = false;
          });
          return;
        }
      }

      await ref.read(authServiceProvider).signInWithOtp(phoneE164: _e164);
      if (!mounted) return;
      context.push('/otp', extra: _e164);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBrandHeader(),
              Transform.translate(
                offset: const Offset(0, -48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: cs.surface,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: cs.surface,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A1C1E).withValues(alpha: 0.06),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<_CitizenAuthMode>(
                            segments: const [
                              ButtonSegment(
                                value: _CitizenAuthMode.signIn,
                                label: Text('Sign in'),
                                icon: Icon(Icons.login_rounded, size: 18),
                              ),
                              ButtonSegment(
                                value: _CitizenAuthMode.register,
                                label: Text('Create account'),
                                icon: Icon(Icons.person_add_outlined, size: 18),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: (s) {
                              setState(() {
                                _mode = s.first;
                                _error = null;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _mode == _CitizenAuthMode.signIn
                                ? 'Sign in with your registered mobile'
                                : 'Register with your mobile number',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mode == _CitizenAuthMode.signIn
                                ? 'We send an OTP only if this number already has an account.'
                                : 'We’ll send an OTP, then ask for your name to finish setup.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _phoneFocus.hasFocus
                                      ? cs.surface
                                      : cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: _phoneFocus.hasFocus
                                      ? [
                                          BoxShadow(
                                            color: cs.primary.withValues(alpha: 0.12),
                                            blurRadius: 0,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '+91',
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      width: 1,
                                      height: 28,
                                      color: cs.outlineVariant.withValues(alpha: 0.45),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _digits,
                                        focusNode: _phoneFocus,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 10,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: tt.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurface,
                                        ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          counterText: '',
                                          hintText: '99999 99999',
                                          hintStyle: tt.titleMedium?.copyWith(
                                            color: cs.onSurfaceVariant
                                                .withValues(alpha: 0.35),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 22,
                                right: 22,
                                bottom: -2,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  height: _phoneFocus.hasFocus ? 3 : 0,
                                  decoration: BoxDecoration(
                                    color: cs.onTertiaryContainer,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: cs.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: GradientPrimaryButton(
                              onPressed: _loading ? null : _sendOtp,
                              label: _mode == _CitizenAuthMode.signIn
                                  ? 'Send OTP to sign in'
                                  : 'Send OTP to register',
                              icon: Icons.arrow_forward_rounded,
                              loading: _loading,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => context.push('/official-login'),
                            icon: const Icon(Icons.badge_outlined),
                            label: const Text('Official Login (JE/Mukadam/Contractor)'),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'You will receive a 6-digit OTP via SMS',
                            textAlign: TextAlign.center,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
                child: Text(
                  'By continuing, you agree to SMC\'s privacy and digital service terms.',
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'मराठी',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 16,
                        color: cs.outlineVariant,
                      ),
                      Text(
                        'English',
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
                  const SizedBox(height: 6),
                  Text(
                    'OFFICIAL APP OF SOLAPUR MUNICIPAL CORPORATION',
                    textAlign: TextAlign.center,
                    style: tt.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

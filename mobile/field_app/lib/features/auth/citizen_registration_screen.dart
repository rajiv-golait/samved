import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/citizen_design.dart';
import '../../core/widgets/auth_brand_header.dart';
import '../../providers/providers.dart';

/// Step 2 — minimal citizen profile after phone + OTP (under 30 seconds).
class CitizenRegistrationScreen extends ConsumerStatefulWidget {
  const CitizenRegistrationScreen({super.key, required this.phoneE164});

  /// E.164, e.g. +919876543210
  final String phoneE164;

  @override
  ConsumerState<CitizenRegistrationScreen> createState() =>
      _CitizenRegistrationScreenState();
}

class _CitizenRegistrationScreenState extends ConsumerState<CitizenRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  bool _termsAccepted = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  void _showTermsDialog(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_termsAccepted) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    final name = _fullNameController.text.trim();
    final now = DateTime.now().toUtc().toIso8601String();

    setState(() => _submitting = true);
    try {
      // Auth trigger (016) already inserted this row. Use UPDATE only: upsert sends INSERT
      // ... ON CONFLICT, which needs INSERT on profiles — 014 only grants SELECT,UPDATE.
      final updated = await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': name,
            'phone': widget.phoneE164,
            'updated_at': now,
          })
          .eq('id', uid)
          .select('id');
      if (updated.isEmpty) {
        throw Exception(
          'No profile row yet. Apply migration 016 (auth trigger) or retry after a moment.',
        );
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: const {'registration_complete': true},
        ),
      );

      ref.invalidate(profileProvider);
      if (!mounted) return;
      context.go('/splash');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CitizenDesign.error,
            content: Text('Could not create account: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool get _canSubmit {
    final nameOk = _fullNameController.text.trim().length >= 2;
    return nameOk && _termsAccepted && !_submitting;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHeader(
                    bottomPadding: 56,
                    compactLogo: true,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -36),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Material(
                        color: cs.surface,
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Almost there',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your name to finish creating your account.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _fullNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'Your Name',
                                    hintText: 'e.g. Ramesh Patil',
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final t = v?.trim() ?? '';
                                    if (t.isEmpty) return 'Please enter your name';
                                    if (t.length < 2) return 'Name must be at least 2 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _termsAccepted,
                                        onChanged: _submitting
                                            ? null
                                            : (v) => setState(() => _termsAccepted = v ?? false),
                                        activeColor: cs.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'I agree to ',
                                            style: tt.bodyMedium?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _submitting
                                                ? null
                                                : () => _showTermsDialog(
                                                      'Terms of Use',
                                                      'Placeholder: Solapur Municipal Corporation Terms of Use. '
                                                      'Replace with official SMC legal text before production.',
                                                    ),
                                            child: Text(
                                              'Terms of Use',
                                              style: tt.bodyMedium?.copyWith(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w700,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            ' and ',
                                            style: tt.bodyMedium?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _submitting
                                                ? null
                                                : () => _showTermsDialog(
                                                      'Privacy Policy',
                                                      'Placeholder: SMC Privacy Policy for रोड NIRMAN. '
                                                      'Replace with official policy before production.',
                                                    ),
                                            child: Text(
                                              'Privacy Policy',
                                              style: tt.bodyMedium?.copyWith(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w700,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
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
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _canSubmit ? _submit : null,
                                      borderRadius: BorderRadius.circular(999),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          gradient: _canSubmit
                                              ? CitizenDesign.orangeCtaGradient
                                              : LinearGradient(
                                                  colors: [
                                                    CitizenDesign.accent.withValues(alpha: 0.35),
                                                    CitizenDesign.accent.withValues(alpha: 0.25),
                                                  ],
                                                ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                                    'Create Account',
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: _submitting ? null : () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

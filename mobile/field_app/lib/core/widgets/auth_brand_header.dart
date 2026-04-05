import 'package:flutter/material.dart';

/// Stitch screen1 — navy brand band with shield + road motif and bilingual title.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.bottomPadding = 80,
    this.compactLogo = false,
  });

  final double bottomPadding;
  final bool compactLogo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 48, 24, bottomPadding),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        cs.primary.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: compactLogo ? 72 : 88,
                height: compactLogo ? 72 : 88,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 4,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: EdgeInsets.all(compactLogo ? 6 : 8),
                  child: Image.asset(
                    'assets/images/solapur_mnc_logo.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'Solapur Municipal Corporation emblem',
                  ),
                ),
              ),
              SizedBox(height: compactLogo ? 14 : 20),
              Text(
                'रोड NIRMAN',
                textAlign: TextAlign.center,
                style: (compactLogo ? tt.titleLarge : tt.headlineMedium)?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'SOLAPUR SMART ROADS',
                textAlign: TextAlign.center,
                style: (compactLogo ? tt.labelSmall : tt.labelMedium)?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w600,
                  letterSpacing: compactLogo ? 2.0 : 2.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

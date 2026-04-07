import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';

class ContractorBottomNav extends StatelessWidget {
  const ContractorBottomNav({
    super.key,
    required this.currentIndex,
    this.pendingCount = 0,
  });

  final int currentIndex;
  final int pendingCount;

  static const _items = [
    _Spec('ORDERS', Icons.assignment_rounded, Icons.assignment_outlined, '/contractor/home'),
    _Spec('MAP', Icons.map_rounded, Icons.map_outlined, '/contractor/home'),
    _Spec('BILLING', Icons.receipt_long_rounded, Icons.receipt_long_outlined, '/contractor/home'),
    _Spec('PROFILE', Icons.person_rounded, Icons.person_outline_rounded, '/contractor/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, MediaQuery.paddingOf(context).bottom + 10),
          color: MukadamDesign.primaryContainer.withValues(alpha: 0.9),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (i == 2) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Coming soon')));
                    }
                    context.go(item.path);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? MukadamDesign.tertiaryFixed : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                active ? item.filled : item.outlined,
                                color: active ? MukadamDesign.primaryNavy : Colors.white70,
                              ),
                            ),
                            if (i == 2 && pendingCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: MukadamDesign.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active ? MukadamDesign.primaryNavy : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Spec {
  const _Spec(this.label, this.filled, this.outlined, this.path);
  final String label;
  final IconData filled;
  final IconData outlined;
  final String path;
}

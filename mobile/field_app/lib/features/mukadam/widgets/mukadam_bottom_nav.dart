import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';

/// 0 Orders, 1 Map, 2 History, 3 Profile
class MukadamBottomNav extends StatelessWidget {
  const MukadamBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavSpec('ORDERS', Icons.assignment_rounded, Icons.assignment_outlined, '/mukadam/home'),
    _NavSpec('MAP', Icons.map_rounded, Icons.map_outlined, '/mukadam/home'),
    _NavSpec('HISTORY', Icons.history_rounded, Icons.history_outlined, '/mukadam/home'),
    _NavSpec('PROFILE', Icons.person_rounded, Icons.person_outline_rounded, '/mukadam/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8,
            10,
            8,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          decoration: BoxDecoration(
            color: MukadamDesign.primaryContainer.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => context.go(item.path),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? MukadamDesign.primaryNavy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            active ? item.filled : item.outlined,
                            size: 22,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.65),
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

class _NavSpec {
  const _NavSpec(this.label, this.filled, this.outlined, this.path);
  final String label;
  final IconData filled;
  final IconData outlined;
  final String path;
}

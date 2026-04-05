import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/citizen_design.dart';

/// 0 = Home, 1 = Report, 2 = Track, 3 = Profile
class CitizenBottomNav extends StatelessWidget {
  const CitizenBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavSpec('HOME', Icons.home_rounded, Icons.home_outlined, '/citizen/home'),
    _NavSpec('REPORT', Icons.add_road_rounded, Icons.add_road_outlined, '/citizen/report'),
    _NavSpec('TRACK', Icons.bar_chart_rounded, Icons.bar_chart_outlined, '/citizen/my-complaints'),
    _NavSpec('PROFILE', Icons.person_rounded, Icons.person_outline_rounded, '/citizen/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.fromLTRB(8, 10, 8, MediaQuery.paddingOf(context).bottom + 10),
          decoration: BoxDecoration(
            color: CitizenDesign.primaryContainer.withValues(alpha: 0.92),
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
                  onTap: () {
                    if (i == 1) {
                      context.push('/citizen/report');
                      return;
                    }
                    context.go(item.path);
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? CitizenDesign.tertiaryFixed : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            active ? item.filled : item.outlined,
                            size: 22,
                            color: active ? CitizenDesign.primary : Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: active ? CitizenDesign.primary : Colors.white.withValues(alpha: 0.72),
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

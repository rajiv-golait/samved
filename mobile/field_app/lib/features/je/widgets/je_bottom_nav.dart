import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/je_design.dart';

class JeBottomNav extends StatelessWidget {
  const JeBottomNav({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;

  static int indexFromLocation(String path, [String? fullUri]) {
    if (path.startsWith('/je/profile')) return 3;
    if (path == '/je/home' || path == '/je') {
      final q = fullUri ?? '';
      if (q.contains('tab=1')) return 1;
      if (q.contains('optimize=1')) return 2;
      return 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: const BoxDecoration(
        color: JeDesign.primaryContainer,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(context, 0, Icons.assignment_outlined, Icons.assignment, 'TASKS', () {
              context.go('/je/home');
            }),
            _item(context, 1, Icons.map_outlined, Icons.map, 'MAP', () {
              context.go('/je/home?tab=1');
            }),
            _item(context, 2, Icons.route_outlined, Icons.route, 'ROUTES', () {
              context.go('/je/home?optimize=1');
            }),
            _item(context, 3, Icons.person_outline, Icons.person, 'PROFILE', () {
              context.go('/je/profile');
            }),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData outline,
    IconData filled,
    String label,
    VoidCallback onTap,
  ) {
    final active = currentIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: active ? JeDesign.primaryNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? filled : outline,
                    size: 20,
                    color: active ? Colors.white : Colors.white.withValues(alpha: 0.65),
                  ),
                  if (active) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!active)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

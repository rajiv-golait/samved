import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../mukadam_formatters.dart';
import '../mukadam_prefs.dart';
import '../widgets/mukadam_bottom_nav.dart';

class MukadamProfileScreen extends ConsumerStatefulWidget {
  const MukadamProfileScreen({super.key});

  @override
  ConsumerState<MukadamProfileScreen> createState() =>
      _MukadamProfileScreenState();
}

class _MukadamProfileScreenState extends ConsumerState<MukadamProfileScreen> {
  String _lang = 'en';
  bool _nAssign = true;
  bool _nJe = true;
  bool _nComplete = false;
  int _weekCount = 0;
  String? _zoneName;
  bool _prefsReady = false;

  @override
  void initState() {
    super.initState();
    _loadPrefsAndStats();
  }

  Future<void> _loadPrefsAndStats() async {
    final lang = await loadMukadamLanguage();
    final n = await loadMukadamNotificationPrefs();
    final week = await ref.read(ticketServiceProvider).countMukadamJobsThisWeek();
    final profile = await ref.read(profileProvider.future);
    String? zname;
    if (profile?.zoneId != null) {
      final z = await ref.read(authServiceProvider).fetchZone(profile!.zoneId!);
      zname = z?.name;
    }
    if (!mounted) return;
    setState(() {
      _lang = lang;
      _nAssign = n['assignment'] ?? true;
      _nJe = n['je'] ?? true;
      _nComplete = n['completion'] ?? false;
      _weekCount = week;
      _zoneName = zname;
      _prefsReady = true;
    });
  }

  Future<void> _setLang(String code) async {
    await saveMukadamLanguage(code);
    setState(() => _lang = code);
  }

  Future<void> _persistNotif() async {
    await saveMukadamNotificationPrefs(
      assignment: _nAssign,
      je: _nJe,
      completion: _nComplete,
    );
  }

  Future<void> _callSupervisingJe() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.zoneId == null) return;
    final svc = ref.read(ticketServiceProvider);
    final snap = await svc.fetchMukadamHomeSnapshot();
    final jeIds = snap.jeNames.keys.toList();
    if (jeIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No supervising JE on current tickets.')),
        );
      }
      return;
    }
    final je = await svc.fetchProfileById(jeIds.first);
    final phone = je?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JE phone not available.')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: MukadamDesign.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile'));
          }
          final zoneLabel = _zoneName ?? 'Zone';
          final emp = profile.employeeId;
          final empBadge = emp != null && emp.isNotEmpty ? emp : '—';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: MukadamDesign.primaryNavy,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/mukadam/home'),
                ),
                title: Text(
                  'Mukadam Profile',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
                centerTitle: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: MukadamDesign.primaryNavy,
                    padding: const EdgeInsets.fromLTRB(24, 88, 24, 20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            initialsFromName(profile.fullName),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: MukadamDesign.primaryNavy,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile.fullName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          profile.phone ?? '—',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'GANG LEADER · ${zoneLabel.toUpperCase()}',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'SMC Employee · Roads Department',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile editing is not available yet.'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'GANG ASSIGNMENT',
                                    style: mukadamMono(10,
                                        color: MukadamDesign.onSurfaceVariant,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: MukadamDesign.secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'EMP-$empBadge',
                                      style: mukadamMono(11,
                                          color: MukadamDesign.primaryNavy,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _grid2(
                                'ZONE',
                                zoneLabel,
                                'GANG SIZE',
                                '8 Workers',
                              ),
                              const SizedBox(height: 10),
                              _grid2(
                                'DEPARTMENT',
                                'Roads Dept',
                                'THIS WEEK',
                                '$_weekCount Jobs Done',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LANGUAGE / भाषा',
                                style: mukadamMono(10,
                                    color: MukadamDesign.onSurfaceVariant,
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              if (_prefsReady)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _LangChip(
                                        label: 'English',
                                        selected: _lang == 'en',
                                        onTap: () => _setLang('en'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _LangChip(
                                        label: 'Marathi',
                                        selected: _lang == 'mr',
                                        onTap: () => _setLang('mr'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NOTIFICATIONS',
                                style: mukadamMono(10,
                                    color: MukadamDesign.onSurfaceVariant,
                                    fontWeight: FontWeight.w700),
                              ),
                              if (_prefsReady) ...[
                                _notifRow(
                                  Icons.notifications_outlined,
                                  'New Assignment Alerts',
                                  _nAssign,
                                  (v) {
                                    setState(() => _nAssign = v);
                                    _persistNotif();
                                  },
                                ),
                                _notifRow(
                                  Icons.person_outline,
                                  'JE Messages',
                                  _nJe,
                                  (v) {
                                    setState(() => _nJe = v);
                                    _persistNotif();
                                  },
                                ),
                                _notifRow(
                                  Icons.check_circle_outline,
                                  'Work Order Completion',
                                  _nComplete,
                                  (v) {
                                    setState(() => _nComplete = v);
                                    _persistNotif();
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUPPORT & INFO',
                                style: mukadamMono(10,
                                    color: MukadamDesign.onSurfaceVariant,
                                    fontWeight: FontWeight.w700),
                              ),
                              _helpRow(
                                Icons.phone_outlined,
                                'Contact Supervising JE',
                                _callSupervisingJe,
                              ),
                              _helpRow(
                                Icons.bug_report_outlined,
                                'Report App Issue',
                                () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Report issue'),
                                    content: const Text(
                                      'Please contact SMC IT support with a screenshot of this screen.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              _helpRow(
                                Icons.shield_outlined,
                                'Privacy Policy',
                                () => showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Privacy'),
                                    content: const Text(
                                      'Official SMC field app — data is processed per municipal policy.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () async {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) context.go('/login');
                          },
                          child: Text(
                            'Sign Out',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: MukadamDesign.accent,
                            ),
                          ),
                        ),
                        Text(
                          'रोड NIRMAN v1.0.0 · Official SMC App',
                          textAlign: TextAlign.center,
                          style: mukadamMono(10,
                              color: MukadamDesign.onSurfaceVariant),
                        ),
                        Text(
                          'SMC-SYS-9921-X',
                          textAlign: TextAlign.center,
                          style: mukadamMono(9, color: MukadamDesign.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const MukadamBottomNav(currentIndex: 3),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MukadamDesign.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MukadamDesign.cardShadow,
      ),
      child: child,
    );
  }

  Widget _grid2(String l1, String v1, String l2, String v2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _gridCell(l1, v1)),
        const SizedBox(width: 12),
        Expanded(child: _gridCell(l2, v2)),
      ],
    );
  }

  Widget _gridCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: mukadamMono(9, color: MukadamDesign.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: MukadamDesign.primaryNavy,
          ),
        ),
      ],
    );
  }

  Widget _notifRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: MukadamDesign.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: MukadamDesign.primaryNavy,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _helpRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: MukadamDesign.onSurfaceVariant),
      title: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: MukadamDesign.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MukadamDesign.primaryNavy : MukadamDesign.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : MukadamDesign.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

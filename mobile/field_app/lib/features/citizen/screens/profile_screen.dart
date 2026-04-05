import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/citizen_design.dart';
import '../../../providers/providers.dart';
import '../widgets/citizen_bottom_nav.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _langEnglish = true;
  bool _nStatus = true;
  bool _nJe = true;
  bool _nResolved = false;
  String? _zoneLabel;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _langEnglish = p.getBool('citizen_lang_english') ?? true;
      _nStatus = p.getBool('citizen_notif_status') ?? true;
      _nJe = p.getBool('citizen_notif_je') ?? true;
      _nResolved = p.getBool('citizen_notif_resolved') ?? false;
    });
  }

  Future<void> _saveLang(bool english) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('citizen_lang_english', english);
    setState(() => _langEnglish = english);
  }

  Future<void> _saveNotif(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return 'C';
    if (p.length == 1) return p[0].substring(0, 1).toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  Future<void> _loadZoneName(int? zoneId) async {
    if (zoneId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('zones')
          .select('name')
          .eq('id', zoneId)
          .maybeSingle();
      if (mounted) setState(() => _zoneLabel = row?['name'] as String?);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile')));
        }
        if (_zoneLabel == null && profile.zoneId != null) {
          _loadZoneName(profile.zoneId);
        }

        final zonePart = profile.zoneId != null
            ? 'ZONE ${profile.zoneId}${_zoneLabel != null ? ' — ${_zoneLabel!.toUpperCase()}' : ''}'
            : 'SOLAPUR';

        return Scaffold(
          backgroundColor: CitizenDesign.surfaceContainerLow,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 8, 8, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [CitizenDesign.primary, CitizenDesign.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.go('/citizen/home'),
                        ),
                        Expanded(
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Log out',
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                          onPressed: _signOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      foregroundColor: CitizenDesign.primary,
                      child: Text(
                        _initials(profile.fullName),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone != null ? '+91 ${profile.phone}' : '—',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CITIZEN · $zonePart',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Edit Profile',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _CardBlock(
                        title: 'LANGUAGE / भाषा',
                        child: Row(
                          children: [
                            Expanded(
                              child: _LangChip(
                                label: 'English',
                                selected: _langEnglish,
                                onTap: () => _saveLang(true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _LangChip(
                                label: 'मराठी',
                                selected: !_langEnglish,
                                onTap: () => _saveLang(false),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardBlock(
                        title: 'NOTIFICATIONS',
                        child: Column(
                          children: [
                            _ToggleRow(
                              icon: Icons.notifications_active_outlined,
                              label: 'Status Updates',
                              value: _nStatus,
                              onChanged: (v) async {
                                setState(() => _nStatus = v);
                                await _saveNotif('citizen_notif_status', v);
                              },
                            ),
                            _ToggleRow(
                              icon: Icons.person_pin_circle_outlined,
                              label: 'JE Dispatched',
                              value: _nJe,
                              onChanged: (v) async {
                                setState(() => _nJe = v);
                                await _saveNotif('citizen_notif_je', v);
                              },
                            ),
                            _ToggleRow(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Complaint Resolved',
                              value: _nResolved,
                              onChanged: (v) async {
                                setState(() => _nResolved = v);
                                await _saveNotif('citizen_notif_resolved', v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CardBlock(
                        title: 'HELP',
                        child: Column(
                          children: [
                            _HelpTile(
                              icon: Icons.help_outline_rounded,
                              label: 'How to report damage',
                              onTap: () {},
                            ),
                            _HelpTile(
                              icon: Icons.phone_in_talk_rounded,
                              label: 'Contact Zone ${profile.zoneId ?? 4} Office',
                              onTap: () => launchUrl(Uri.parse('tel:+912172400000')),
                            ),
                            _HelpTile(
                              icon: Icons.shield_outlined,
                              label: 'Privacy Policy',
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout_rounded, color: CitizenDesign.accent),
                          label: Text(
                            'Log out',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: CitizenDesign.accent,
                              fontSize: 16,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CitizenDesign.accent,
                            side: const BorderSide(color: CitizenDesign.accent, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'रोड NIRMAN v1.0.0 · Official SMC App',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CitizenDesign.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SMC-SYS-9921-X',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: CitizenDesign.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const CitizenBottomNav(currentIndex: 3),
        );
      },
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: CitizenDesign.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
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
      color: selected ? CitizenDesign.primary : CitizenDesign.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : CitizenDesign.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CitizenDesign.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: CitizenDesign.onSurfaceVariant, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: CitizenDesign.primary,
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: CitizenDesign.onSurfaceVariant),
      title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/je_design.dart';
import '../../../providers/providers.dart';

class _RateRow {
  _RateRow({
    required this.id,
    required this.workType,
    this.workTypeMarathi,
    required this.unit,
    required this.ratePerUnit,
  });

  final String id;
  final String workType;
  final String? workTypeMarathi;
  final String unit;
  final double ratePerUnit;
}

class _DamageOption {
  const _DamageOption(this.label, this.dotColor, this.dbValue);
  final String label;
  final Color dotColor;
  final String dbValue;
}

class JeMeasureEstimateScreen extends ConsumerStatefulWidget {
  const JeMeasureEstimateScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<JeMeasureEstimateScreen> createState() => _JeMeasureEstimateScreenState();
}

class _JeMeasureEstimateScreenState extends ConsumerState<JeMeasureEstimateScreen> {
  final _len = TextEditingController();
  final _wid = TextEditingController();
  final _depth = TextEditingController();

  Map<String, dynamic>? _ticket;
  List<_RateRow> _rates = [];
  _RateRow? _selectedRate;
  String? _damage;
  bool _loading = true;
  bool _submitting = false;

  static const _damageOptions = [
    _DamageOption('Roads', Color(0xFFBA1A1A), 'poor_construction'),
    _DamageOption('Water Supply', Color(0xFF2563EB), 'utility_water'),
    _DamageOption('Drainage', Color(0xFF38BDF8), 'utility_drainage'),
    _DamageOption('MSEDCL', Color(0xFFEAB308), 'utility_electricity'),
  ];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: JeDesign.error, content: Text(msg)),
    );
  }

  double? get _lengthM => double.tryParse(_len.text.trim());
  double? get _widthM => double.tryParse(_wid.text.trim());
  double? get _depthCm => double.tryParse(_depth.text.trim());

  double get _areaSqm {
    final l = _lengthM ?? 0;
    final w = _widthM ?? 0;
    return l * w;
  }

  double get _estimatedCost {
    final r = _selectedRate?.ratePerUnit ?? 0;
    return _areaSqm * r;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ref.read(profileProvider.future);
      final z = profile?.zoneId;
      if (z == null) throw Exception('No zone on profile');

      final supa = Supabase.instance.client;
      final t = await supa
          .from('tickets')
          .select('id, ticket_ref, status')
          .eq('id', widget.ticketId)
          .maybeSingle();

      final rows = await supa
          .from('rate_cards')
          .select('id, work_type, work_type_marathi, unit, rate_per_unit')
          .eq('is_active', true)
          .eq('fiscal_year', '2025-26')
          .or('zone_id.is.null,zone_id.eq.$z');

      final list = (rows as List<dynamic>)
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return _RateRow(
              id: m['id'] as String,
              workType: m['work_type'] as String? ?? '',
              workTypeMarathi: m['work_type_marathi'] as String?,
              unit: m['unit'] as String? ?? 'sqm',
              ratePerUnit: (m['rate_per_unit'] as num).toDouble(),
            );
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _ticket = t != null ? Map<String, dynamic>.from(t) : null;
        _rates = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Load failed: $e');
      }
    }
  }

  Future<void> _submit() async {
    final l = _lengthM;
    final w = _widthM;
    final dCm = _depthCm ?? 0;
    final rate = _selectedRate;
    final dmg = _damage;

    if (l == null || l <= 0) {
      _snack('Enter length (metres)');
      return;
    }
    if (w == null || w <= 0) {
      _snack('Enter width (metres)');
      return;
    }
    if (rate == null) {
      _snack('Select work type');
      return;
    }
    if (dmg == null) {
      _snack('Select primary cause of damage');
      return;
    }

    setState(() => _submitting = true);
    try {
      final supa = Supabase.instance.client;
      final uid = supa.auth.currentUser?.id;
      if (uid == null) throw Exception('Not signed in');

      final area = _areaSqm;
      final cost = _estimatedCost;

      await supa.from('tickets').update({
        'dimensions': {
          'length_m': l,
          'width_m': w,
          'depth_m': dCm / 100,
          'area_sqm': area,
        },
        'work_type': rate.workType,
        'rate_card_id': rate.id,
        'rate_per_unit': rate.ratePerUnit,
        'estimated_cost': cost,
        'damage_cause': dmg,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.ticketId);

      await supa.from('ticket_events').insert({
        'ticket_id': widget.ticketId,
        'actor_id': uid,
        'actor_role': 'je',
        'event_type': 'measurement_recorded',
        'notes':
            'JE recorded dimensions: ${l}m × ${w}m = ${area.toStringAsFixed(2)}sqm. Cost: ₹${cost.toStringAsFixed(2)}',
      });

      if (mounted) context.push('/je/assign/${widget.ticketId}');
    } catch (e) {
      _snack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _refSuffix(String? ref) {
    if (ref == null || ref.length < 4) return ref ?? '—';
    return ref.length > 4 ? ref.substring(ref.length - 4) : ref;
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_len, _wid, _depth]) {
      c.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _len.dispose();
    _wid.dispose();
    _depth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refStr = _ticket?['ticket_ref'] as String?;
    final canSubmit = _rates.isNotEmpty;

    return Scaffold(
      backgroundColor: JeDesign.background,
      appBar: AppBar(
        backgroundColor: JeDesign.primaryContainer,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Measurement & Estimation',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No active rate cards found for this zone. Contact City Engineer.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: JeDesign.error),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pothole Dimensions',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Enter the physical survey measurements',
                                  style: GoogleFonts.inter(color: JeDesign.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: JeDesign.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#R-${_refSuffix(refStr)}',
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _dimField('LENGTH', _len, 'M')),
                          const SizedBox(width: 8),
                          Expanded(child: _dimField('WIDTH', _wid, 'M')),
                          const SizedBox(width: 8),
                          Expanded(child: _dimField('DEPTH', _depth, 'CM')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: JeDesign.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten_rounded, size: 18, color: JeDesign.primaryContainer),
                              const SizedBox(width: 8),
                              Text(
                                'Area: ${_areaSqm.toStringAsFixed(2)} sqm',
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Work Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: JeDesign.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showModalBottomSheet<_RateRow>(
                              context: context,
                              builder: (ctx) => ListView(
                                children: _rates
                                    .map(
                                      (r) => ListTile(
                                        title: Text(r.workType),
                                        subtitle: r.workTypeMarathi != null
                                            ? Text(r.workTypeMarathi!)
                                            : null,
                                        trailing: Text('₹${r.ratePerUnit} / ${r.unit}'),
                                        onTap: () => Navigator.pop(ctx, r),
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                            if (picked != null) setState(() => _selectedRate = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.engineering_outlined, color: JeDesign.primaryContainer),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedRate?.workType ?? 'Select work type',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: JeDesign.tertiaryFixed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: -8,
                              top: -8,
                              child: Opacity(
                                opacity: 0.08,
                                child: Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 120,
                                    fontWeight: FontWeight.w900,
                                    color: JeDesign.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lock_outline, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RATE CARD FY 2025-26',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    _selectedRate != null
                                        ? '₹${_selectedRate!.ratePerUnit.toStringAsFixed(0)} / ${_selectedRate!.unit}'
                                        : '—',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: JeDesign.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.verified_rounded, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Approved by City Engineer • Cannot be modified',
                                        style: GoogleFonts.inter(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Primary Cause of Damage',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _damageOptions.map((o) {
                          final sel = _damage == o.dbValue;
                          return Material(
                            color: sel ? JeDesign.primaryNavy : JeDesign.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              onTap: () => setState(() => _damage = o.dbValue),
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: o.dotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      o.label,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: sel ? Colors.white : JeDesign.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'ESTIMATED COST',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w700,
                          color: JeDesign.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₹${_estimatedCost.toStringAsFixed(2)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.lock_outline, color: JeDesign.onSurfaceVariant, size: 22),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: JeDesign.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_areaSqm.toStringAsFixed(2)} sqm × ₹${_selectedRate?.ratePerUnit.toStringAsFixed(0) ?? '—'} = ₹${_estimatedCost.toStringAsFixed(2)}',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (!canSubmit || _submitting) ? null : _submit,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: canSubmit ? JeDesign.primaryGradient : null,
                  color: canSubmit ? null : JeDesign.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: canSubmit ? JeDesign.cardShadow : null,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _submitting
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Approve & Assign Executor',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dimField(String label, TextEditingController c, String unit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JeDesign.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: JeDesign.accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: JeDesign.onSurfaceVariant,
            ),
          ),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              suffixText: unit,
              suffixStyle: GoogleFonts.inter(fontSize: 12, color: JeDesign.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

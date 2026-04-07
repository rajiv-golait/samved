import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../contractor_formatters.dart';

class ContractorGhostCameraScreen extends ConsumerStatefulWidget {
  const ContractorGhostCameraScreen({super.key, required this.ticketId, this.fieldNotes});
  final String ticketId;
  final String? fieldNotes;

  @override
  ConsumerState<ContractorGhostCameraScreen> createState() => _ContractorGhostCameraScreenState();
}

class _ContractorGhostCameraScreenState extends ConsumerState<ContractorGhostCameraScreen> {
  CameraController? _cam;
  Map<String, dynamic>? _t;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Permission.camera.request();
    final t = await ref.read(ticketServiceProvider).fetchContractorTicketDetail(widget.ticketId);
    final cams = await availableCameras();
    final c = CameraController(cams.first, ResolutionPreset.high, enableAudio: false);
    await c.initialize();
    if (!mounted) return;
    _t = t;
    _cam = c;
    setState(() {});
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final c = _cam;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    try {
      final pic = await c.takePicture();
      final bytes = await pic.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      await ref.read(ticketServiceProvider).contractorUploadProof(ticketId: widget.ticketId, imageBytes: bytes, hash: hash);
      ref.invalidate(contractorHomeProvider);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Container(
                color: MukadamDesign.success.withValues(alpha: 0.9),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_user, size: 80, color: Colors.white),
                    Text('REPAIR VERIFIED ✓', style: GoogleFonts.plusJakartaSans(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('${hash.substring(0, 16)}...', style: contractorMono(10, color: Colors.white70)),
                  ]),
                ),
              ));
      if (!mounted) return;
      context.go('/contractor/submitted', extra: {'ticketId': widget.ticketId, 'hash': hash, 'submittedAt': DateTime.now()});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Check your connection and try again.')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    final t = _t;
    if (c == null || !c.value.isInitialized || t == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final before = t['photo_before'];
    final ghost = before is List && before.isNotEmpty ? before.first.toString() : null;
    final ref = (t['job_order_ref'] ?? t['ticket_ref']).toString();
    final viewH = MediaQuery.sizeOf(context).height * 0.72;
    return Scaffold(
      backgroundColor: MukadamDesign.primaryNavy,
      body: Stack(children: [
        Column(children: [
          SizedBox(
            height: viewH,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              CameraPreview(c),
              if (ghost != null) Opacity(opacity: 0.4, child: Image.network(ghost, fit: BoxFit.cover)),
              CustomPaint(painter: _GuidePainter(), child: const SizedBox.expand()),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: MukadamDesign.primaryNavy.withValues(alpha: 0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(children: [
                const SizedBox(height: 12),
                Text('SHA-256: CALCULATING...', style: contractorMono(10, color: Colors.white54)),
                const Spacer(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.flash_off, color: Colors.white)),
                  GestureDetector(onTap: _busy ? null : _capture, child: Container(width: 88, height: 88, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                  Text('1×', style: contractorMono(16, color: Colors.white70)),
                ]),
                const SizedBox(height: 8),
                Text('Photo will be cryptographically signed and cannot be altered.', style: GoogleFonts.inter(fontSize: 11, color: Colors.white60)),
                Text('ID: $ref', style: contractorMono(9, color: Colors.white38)),
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
              ]),
            ),
          )
        ]),
        SafeArea(
          child: Row(children: [
            IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back, color: Colors.white)),
            Expanded(child: Text('PROOF OF REPAIR', textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline, color: Colors.white)),
          ]),
        ),
      ]),
    );
  }
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width * 0.72, height: size.height * 0.55),
      const Radius.circular(20),
    );
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawRRect(r, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

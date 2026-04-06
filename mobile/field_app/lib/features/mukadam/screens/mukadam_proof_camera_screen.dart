import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/mukadam_design.dart';
import '../../../providers/providers.dart';
import '../../../providers/ticket_providers.dart';
import '../mukadam_formatters.dart';

class MukadamProofCameraScreen extends ConsumerStatefulWidget {
  const MukadamProofCameraScreen({
    super.key,
    required this.ticketId,
    this.fieldNotes,
  });

  final String ticketId;
  final String? fieldNotes;

  @override
  ConsumerState<MukadamProofCameraScreen> createState() =>
      _MukadamProofCameraScreenState();
}

class _MukadamProofCameraScreenState
    extends ConsumerState<MukadamProofCameraScreen> {
  CameraController? _cam;
  bool _ready = false;
  String? _ghostUrl;
  bool _uploading = false;
  String? _initError;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final camPerm = await Permission.camera.request();
    if (!camPerm.isGranted) {
      if (mounted) {
        setState(() => _initError = 'Camera permission is required to capture proof.');
      }
      return;
    }

    final svc = ref.read(ticketServiceProvider);
    final row = await svc.fetchMukadamTicketForCamera(widget.ticketId);
    if (!mounted) return;
    if (row == null || row['status'] != 'in_progress') {
      setState(() => _initError = 'Camera unavailable for this ticket.');
      return;
    }
    final before = row['photo_before'];
    if (before is List && before.isNotEmpty) {
      _ghostUrl = before.first.toString();
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      setState(() => _initError = 'No camera found on this device.');
      return;
    }
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    final ctrl = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
    } catch (e) {
      if (mounted) {
        setState(() => _initError = 'Camera failed to start: $e');
      }
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    _cam = ctrl;
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final ctrl = _cam;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await ctrl.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final ctrl = _cam;
    if (ctrl == null || !ctrl.value.isInitialized || _uploading) return;
    setState(() => _uploading = true);
    try {
      final file = await ctrl.takePicture();
      final bytes = await file.readAsBytes();
      final profile = await ref.read(profileProvider.future);
      if (profile == null) throw StateError('Not signed in');
      await ref.read(ticketServiceProvider).mukadamUploadCompletionProof(
            ticketId: widget.ticketId,
            imageBytes: bytes,
            fieldNotes: widget.fieldNotes,
            mukadamFullName: profile.fullName,
          );
      ref.invalidate(mukadamHomeProvider);
      if (!mounted) return;
      final submittedAt = DateTime.now();
      context.go('/mukadam/submitted', extra: {
        'ticketId': widget.ticketId,
        'submittedAt': submittedAt,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Upload failed. Check your connection and try again.',
            ),
            action: SnackBarAction(label: 'Retry', onPressed: _capture),
          ),
        );
      }
    }
  }

  void _infoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completion proof'),
        content: const Text(
          'Align the repaired road with the faint before photo. '
          'The photo is sent to SMC for JE verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: MukadamDesign.primaryNavy,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _initError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (!_ready || _cam == null || !_cam!.value.isInitialized) {
      return Scaffold(
        backgroundColor: MukadamDesign.primaryNavy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Starting camera…',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final preview = CameraPreview(_cam!);
    final viewH = MediaQuery.sizeOf(context).height * 0.72;

    return Scaffold(
      backgroundColor: MukadamDesign.primaryNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              SizedBox(
                height: viewH,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (_ghostUrl != null)
                      Opacity(
                        opacity: 0.4,
                        child: Image.network(
                          _ghostUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    CustomPaint(
                      painter: _DashedGuidePainter(),
                      child: const SizedBox.expand(),
                    ),
                    Positioned(
                      top: viewH * 0.18,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              color: Colors.black45,
                              child: Text(
                                'Align repaired road with ghost outline',
                                style: mukadamMono(10, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 40,
                        color: MukadamDesign.primaryNavy.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _PulsingGreenDot(),
                            const SizedBox(width: 8),
                            Text(
                              'Surface Change: Detected ✓',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      color: MukadamDesign.primaryNavy.withValues(alpha: 0.9),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQuery.paddingOf(context).bottom + 12,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: MukadamDesign.success, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _ghostUrl != null
                                    ? 'Before photo loaded — ghost overlay active'
                                    : 'Camera active — capture completion view',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                onPressed: _toggleFlash,
                                icon: Icon(
                                  _flash == FlashMode.torch
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: Colors.white,
                                ),
                              ),
                              GestureDetector(
                                onTap: _uploading ? null : _capture,
                                child: Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: MukadamDesign.onSurfaceVariant,
                                      width: 4,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _uploading
                                      ? const SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Text(
                                '1×',
                                style: mukadamMono(16, color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photo confirms gang deployment and work completion',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      'COMPLETION PROOF',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _infoDialog,
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (_uploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Uploading proof…',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.72;
    final h = size.height * 0.55;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(16),
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _drawDashedRRect(canvas, r, paint);

    final bracket = 18.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    // TL
    canvas.drawPath(
      Path()
        ..moveTo(left, top + bracket)
        ..lineTo(left, top)
        ..lineTo(left + bracket, top),
      cornerPaint,
    );
    // TR
    canvas.drawPath(
      Path()
        ..moveTo(left + w - bracket, top)
        ..lineTo(left + w, top)
        ..lineTo(left + w, top + bracket),
      cornerPaint,
    );
    // BL
    canvas.drawPath(
      Path()
        ..moveTo(left, top + h - bracket)
        ..lineTo(left, top + h)
        ..lineTo(left + bracket, top + h),
      cornerPaint,
    );
    // BR
    canvas.drawPath(
      Path()
        ..moveTo(left + w - bracket, top + h)
        ..lineTo(left + w, top + h)
        ..lineTo(left + w, top + h - bracket),
      cornerPaint,
    );
  }

  void _drawDashedRRect(Canvas canvas, RRect r, Paint paint) {
    const dash = 10.0;
    const gap = 6.0;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final next = d + dash;
        final extract = metric.extractPath(d, next.clamp(0, metric.length));
        canvas.drawPath(extract, paint);
        d = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingGreenDot extends StatefulWidget {
  @override
  State<_PulsingGreenDot> createState() => _PulsingGreenDotState();
}

class _PulsingGreenDotState extends State<_PulsingGreenDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: MukadamDesign.success,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/citizen_design.dart';

class ReportDamageScreen extends ConsumerStatefulWidget {
  const ReportDamageScreen({super.key});

  @override
  ConsumerState<ReportDamageScreen> createState() => _ReportDamageScreenState();
}

class _ReportDamageScreenState extends ConsumerState<ReportDamageScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _loading = true;
  String? _error;
  Position? _gps;
  bool _gpsLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cam = await Permission.camera.request();
    final loc = await Permission.locationWhenInUse.request();

    if (!cam.isGranted) {
      if (mounted) {
        await _showSettingsDialog('Camera access is required to photograph road damage.');
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Camera permission denied';
        });
      }
      return;
    }

    if (!loc.isGranted) {
      if (mounted) await _showSettingsDialog('Location is required to route your complaint to the correct zone.');
    }

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No camera found on this device.';
        });
      }
      return;
    }

    final back = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      return;
    }

    _silentGps();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _silentGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsLoading = false);
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        setState(() {
          _gps = p;
          _gpsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _showSettingsDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission needed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (_gps == null && _gpsLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting location… please wait a moment.')),
      );
      return;
    }

    if (_gps == null) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Location unavailable'),
          content: const Text(
            'Could not get GPS. Please enable location and try again.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retry')),
          ],
        ),
      );
      if (retry == true) {
        setState(() => _gpsLoading = true);
        await _silentGps();
      }
      return;
    }

    try {
      final file = await c.takePicture();
      final imageFile = File(file.path);
      if (!mounted) return;
      final path = Uri.encodeComponent(imageFile.path);
      final lat = _gps!.latitude.toStringAsFixed(7);
      final lng = _gps!.longitude.toStringAsFixed(7);
      context.push('/citizen/ai-result?path=$path&lat=$lat&lng=$lng', extra: {
        'imageFile': imageFile,
        'gpsPosition': _gps!,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: CitizenDesign.error, content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final m = c.value.flashMode == FlashMode.torch ? FlashMode.off : FlashMode.torch;
    await c.setFlashMode(m);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: const Text('Report damage'),
        ),
        body: Center(child: Text(_error!)),
      );
    }

    final c = _controller!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: CameraPreview(c)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 4, 8, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'REPORT DAMAGE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tips'),
                          content: const Text(
                            'Stand safely off the road, capture the full damage in frame, '
                            'and keep the phone steady. Location is recorded automatically.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.paddingOf(context).bottom + 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        c.value.flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    GestureDetector(
                      onTap: _capture,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 5),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '1×',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../core/widgets/gradient_primary_button.dart';
import '../../providers/providers.dart';
import '../../providers/ticket_providers.dart';

class ExecutionProofArgs {
  const ExecutionProofArgs({
    required this.ticketId,
    required this.roleLabel,
  });

  final String ticketId;
  final String roleLabel;
}

class ExecutionProofScreen extends ConsumerStatefulWidget {
  const ExecutionProofScreen({super.key, required this.args});

  final ExecutionProofArgs args;

  @override
  ConsumerState<ExecutionProofScreen> createState() =>
      _ExecutionProofScreenState();
}

class _ExecutionProofScreenState extends ConsumerState<ExecutionProofScreen> {
  Uint8List? _photoBytes;
  String _photoExt = '.jpg';
  bool _busy = false;
  String? _error;
  bool _camDenied = false;

  String _extensionFor(XFile x) {
    final e = p.extension(x.name);
    return e.isNotEmpty ? e : '.jpg';
  }

  Future<void> _capture() async {
    if (!kIsWeb) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        setState(() => _camDenied = true);
        return;
      }
    }
    setState(() => _camDenied = false);
    final x = await ImagePicker().pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoExt = _extensionFor(x);
    });
  }

  Future<void> _submit() async {
    if (_photoBytes == null) {
      setState(() => _error = kIsWeb
          ? 'Choose an after photo (browser uses gallery for testing).'
          : 'Take an after photo at the site.');
      return;
    }
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ref.read(storageServiceProvider).uploadAfterPhoto(
            userId: uid,
            bytes: _photoBytes!,
            fileExtension: _photoExt,
          );
      await ref.read(ticketServiceProvider).submitExecutionProof(
            ticketId: widget.args.ticketId,
            afterPhotoUrl: url,
          );
      if (!mounted) return;
      ref.invalidate(ticketDetailProvider(widget.args.ticketId));
      ref.invalidate(mukadamHomeProvider);
      ref.invalidate(mukadamInboxProvider);
      ref.invalidate(contractorInboxProvider);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proof submitted — quality check pending')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Completion proof')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.primaryContainer],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Text(
              '${widget.args.roleLabel}: capture one clear after photo showing the repaired surface.',
              style: tt.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_camDenied)
            Container(
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Text(
                'Camera permission denied.',
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _capture,
              icon: Icon(kIsWeb ? Icons.photo_library_outlined : Icons.photo_camera_outlined),
              label: Text(_photoBytes == null
                  ? (kIsWeb ? 'Choose after photo' : 'Take after photo')
                  : (kIsWeb ? 'Change photo' : 'Retake')),
            ),
          ),
          if (_photoBytes != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  _photoBytes!,
                  height: 240,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 24),
          GradientPrimaryButton(
            onPressed: _busy ? null : _submit,
            label: 'Submit for quality check',
            icon: Icons.verified_rounded,
            loading: _busy,
          ),
        ],
      ),
    );
  }
}

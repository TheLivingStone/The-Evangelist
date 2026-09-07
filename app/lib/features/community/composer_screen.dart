import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/glass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth_account.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class ComposerScreen extends ConsumerStatefulWidget {
  final String initialType;
  final String? prefill;
  const ComposerScreen({
    super.key,
    this.initialType = 'testimony',
    this.prefill,
  });

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  late String _type = widget.initialType;
  late final _body = TextEditingController(text: widget.prefill ?? '');
  bool _busy = false;

  // Picked-but-not-yet-uploaded photo. Bytes are read eagerly so the same
  // path works on web (no File) and the preview can render immediately.
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  static const _types = [
    'testimony',
    'outreach',
    'prayer',
    'salvation',
    'update',
  ];

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  /// Attach a photo — straight from the camera (in-app, no app switch) or
  /// from the library. Camera capture is the primary path: you're out on the
  /// street, something happens, you shoot it and post.
  Future<void> _pickPhoto(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied =
          e.code == 'camera_access_denied' || e.code == 'photo_access_denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            denied
                ? 'Allow ${source == ImageSource.camera ? 'camera' : 'photo'} '
                      'access in Settings to attach a photo.'
                : source == ImageSource.camera
                ? 'The camera isn\'t available on this device.'
                : 'Could not open your photos.',
          ),
        ),
      );
      return;
    }
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoExt = ext;
    });
  }

  String _contentTypeFor(String ext) => switch (ext) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };

  Future<void> _post() async {
    if (_body.text.trim().isEmpty) return;
    // Guests must create an account before posting publicly.
    if (!await requireAccount(context, ref)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final profile = ref.read(myProfileProvider).value;
      final repo = ref.read(feedRepoProvider);
      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await repo.uploadPostPhoto(
          _photoBytes!,
          contentType: _contentTypeFor(_photoExt),
          ext: _photoExt,
        );
      }
      await repo.create(
        _type,
        _body.text.trim(),
        city: profile?.city,
        photoUrl: photoUrl,
      );
      ref.invalidate(allFeedProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish post: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Share what God did'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _post,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: _types
                  .map(
                    (t) => ChoiceChip(
                      label: Text(t[0].toUpperCase() + t.substring(1)),
                      selected: _type == t,
                      selectedColor: AppColors.accent.withValues(alpha: 0.25),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Share what God did today…',
                ),
              ),
            ),
            if (_photoBytes != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _photoBytes!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _photoBytes = null),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    _photoBytes == null ? 'Take photo' : 'Retake',
                    style: const TextStyle(color: AppColors.accent),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(
                    Icons.image_outlined,
                    color: AppColors.accent,
                  ),
                  label: Text(
                    _photoBytes == null ? 'Library' : 'Change',
                    style: const TextStyle(color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

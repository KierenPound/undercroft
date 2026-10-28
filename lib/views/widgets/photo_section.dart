import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/attachment.dart';
import '../../repositories/sections_repository.dart';
import '../../services/estate_service.dart';
import 'attachments_section.dart';

/// A reusable photo section that can be added to any section.
///
/// Cloned from the Memory section in [WhatToDoFirstDashboard]. Shows a
/// default asset image that the estate owner can replace with their own
/// upload (persisted to Supabase storage via the attachments mechanism).
///
/// The photo is resolved before anything is painted, so only one image is
/// ever shown:
///
/// 1. While the user's role is unknown, a neutral placeholder.
/// 2. No role (a brand-new signup who has not joined an estate): the bundled
///    default, without querying Supabase at all.
/// 3. A role: whatever is stored for the section, falling back to the
///    bundled default when nothing has been uploaded.
class PhotoSection extends ConsumerStatefulWidget {
  final String sectionId;
  final String estateId;
  final bool isOwner;
  final String defaultAsset;
  final String sectionTitle;

  const PhotoSection({
    super.key,
    required this.sectionId,
    required this.estateId,
    required this.isOwner,
    required this.defaultAsset,
    required this.sectionTitle,
  });

  @override
  ConsumerState<PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends ConsumerState<PhotoSection> {
  bool _uploading = false;

  Attachment? _findPhotoAttachment(List<Attachment> attachments) {
    Attachment? latest;
    for (final a in attachments) {
      if (!a.fileName.toLowerCase().startsWith('photo_')) continue;
      if (latest == null || a.createdAt.isAfter(latest.createdAt)) {
        latest = a;
      }
    }
    return latest;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    try {
      // Remove any previously stored photo so we never keep stale duplicates.
      final existing =
          ref.read(attachmentsProvider(widget.sectionId)).valueOrNull ??
              <Attachment>[];
      for (final a in existing) {
        if (a.fileName.toLowerCase().startsWith('photo_')) {
          await repo.deleteAttachment(a);
        }
      }

      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      await repo.uploadAttachment(
        sectionId: widget.sectionId,
        estateId: widget.estateId,
        fileName: 'photo_image.jpg',
        type: AttachmentType.photo,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) {
        // ignore: unused_result
        ref.refresh(attachmentsProvider(widget.sectionId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _viewFullscreen(Attachment? photoAttachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoViewer(
          photoAttachment: photoAttachment,
          defaultAsset: widget.defaultAsset,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A user with no role at all has not joined an estate yet, so there is
    // nothing stored for them: the bundled default is the final answer and
    // Supabase is never queried.
    final asyncRole = ref.watch(estateRoleProvider);
    final hasRole = (asyncRole.valueOrNull ?? '').isNotEmpty;

    Attachment? photoAttachment;
    // True while the photo's source is still unknown, so we can hold a
    // neutral placeholder instead of painting an image about to be replaced.
    var resolving = !asyncRole.hasValue;
    if (asyncRole.hasValue && hasRole) {
      final asyncAttachments =
          ref.watch(attachmentsProvider(widget.sectionId));
      // Keep previously-loaded data during background re-fetches so a stored
      // photo doesn't momentarily fall back to the default (flicker).
      if (asyncAttachments.hasValue) {
        photoAttachment = _findPhotoAttachment(
          asyncAttachments.valueOrNull ?? const <Attachment>[],
        );
      } else {
        resolving = asyncAttachments.isLoading;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Memory',
          icon: Icons.photo_library,
          tint: Colors.blue,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _viewFullscreen(photoAttachment),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: resolving
                          ? const MemoryPhotoPlaceholder()
                          : _photoImage(photoAttachment),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.open_in_full,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      resolving
                          ? ''
                          : photoAttachment != null
                              ? 'Tap to expand'
                              : '${widget.sectionTitle} photograph',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ],
                ),
                if (widget.isOwner) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.edit),
                      label: Text(
                          _uploading ? 'Uploading...' : 'Replace photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoImage(Attachment? photoAttachment) {
    if (photoAttachment == null || photoAttachment.downloadUrl.isEmpty) {
      return _defaultImage();
    }
    return Image.network(
      photoAttachment.downloadUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      gaplessPlayback: true,
      // Hold the placeholder until the stored photo has pixels: returning the
      // default asset here paints a second image that then fades out.
      loadingBuilder: (context, child, loadingProgress) =>
          loadingProgress == null ? child : const MemoryPhotoPlaceholder(),
      errorBuilder: (_, __, ___) => _defaultImage(),
    );
  }

  Widget _defaultImage() {
    return Image.asset(
      widget.defaultAsset,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required Color tint,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tint, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

/// Neutral stand-in shown while a Memory photo's source is still being
/// resolved, or while a stored photo is downloading.
///
/// Deliberately not the default asset: painting the bundled default first and
/// then swapping in the stored photo reads as two images loading in sequence.
class MemoryPhotoPlaceholder extends StatelessWidget {
  const MemoryPhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// Fullscreen viewer for the photo (asset or uploaded).
class _FullscreenPhotoViewer extends StatelessWidget {
  final Attachment? photoAttachment;
  final String defaultAsset;

  const _FullscreenPhotoViewer({
    required this.photoAttachment,
    required this.defaultAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Memory',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: photoAttachment != null &&
                  photoAttachment!.downloadUrl.isNotEmpty
              ? Image.network(
                  photoAttachment!.downloadUrl,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    );
                  },
                  errorBuilder: (_, __, ___) => Image.asset(
                    defaultAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              : Image.asset(
                  defaultAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}

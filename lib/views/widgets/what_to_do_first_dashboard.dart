import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../repositories/sections_repository.dart';
import 'attachments_section.dart';
import 'song_for_the_page_section.dart';

/// What To Do First rich-media dashboard.
///
/// Cloned from the FamilyPrep (iOS) `WhatToDoFirstDashboardView`. Contains:
/// 1. Memory — a replaceable photo (defaults to asset `wtdl_1`), persisted to
///    Supabase storage via the existing attachments mechanism.
/// 2. Immediate things you need to do
/// 3. Medical certificate
/// 4. Death certificate
class WhatToDoFirstDashboard extends ConsumerStatefulWidget {
  final String sectionId;
  final String estateId;
  final bool isOwner;
  final String youtubeUrl;

  const WhatToDoFirstDashboard({
    super.key,
    required this.sectionId,
    required this.estateId,
    required this.isOwner,
    required this.youtubeUrl,
  });

  @override
  ConsumerState<WhatToDoFirstDashboard> createState() =>
      _WhatToDoFirstDashboardState();
}

class _WhatToDoFirstDashboardState
    extends ConsumerState<WhatToDoFirstDashboard> {
  bool _uploading = false;

  Attachment? _findMemoryAttachment(List<Attachment> attachments) {
    Attachment? latest;
    for (final a in attachments) {
      if (!a.fileName.toLowerCase().startsWith('memory_')) continue;
      if (latest == null || a.createdAt.isAfter(latest.createdAt)) {
        latest = a;
      }
    }
    return latest;
  }

  Future<void> _pickMemoryImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    try {
      // Remove any previously stored memory photo so we never keep stale
      // duplicates (the upload path is timestamped, so each upload creates a
      // new row + storage object).
      final existing = ref
              .read(attachmentsProvider(widget.sectionId))
              .valueOrNull ??
          <Attachment>[];
      for (final a in existing) {
        if (a.fileName.toLowerCase().startsWith('memory_')) {
          await repo.deleteAttachment(a);
        }
      }

      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      await repo.uploadAttachment(
        sectionId: widget.sectionId,
        estateId: widget.estateId,
        fileName: 'memory_photo.jpg',
        type: AttachmentType.photo,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (mounted) {
        // ignore: unused_result
        ref.refresh(attachmentsProvider(widget.sectionId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory photo updated')),
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

  void _viewFullscreen(Attachment? memoryAttachment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenPhotoViewer(
          memoryAttachment: memoryAttachment,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncAttachments =
        ref.watch(attachmentsProvider(widget.sectionId));
    final memoryAttachment = asyncAttachments.maybeWhen(
      data: _findMemoryAttachment,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMemorySection(memoryAttachment),
        const SizedBox(height: 28),
        _buildImmediateSection(),
        const SizedBox(height: 28),
        _buildMedicalCertificateSection(),
        const SizedBox(height: 28),
        _buildDeathCertificateSection(),
        const SizedBox(height: 28),
        SongForThePageSection(youtubeUrl: widget.youtubeUrl),
      ],
    );
  }

  // MARK: - Section helpers

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

  // MARK: - Memory

  Widget _buildMemorySection(Attachment? memoryAttachment) {
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
                  onTap: () => _viewFullscreen(memoryAttachment),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: memoryAttachment != null &&
                              memoryAttachment.downloadUrl.isNotEmpty
                          ? Image.network(
                              memoryAttachment.downloadUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                                  _defaultMemoryImage(),
                            )
                          : _defaultMemoryImage(),
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
                      memoryAttachment != null
                          ? 'Tap to expand'
                          : 'Family photograph',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                  ],
                ),
                if (widget.isOwner) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _pickMemoryImage,
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
                      label: Text(_uploading
                          ? 'Uploading...'
                          : 'Replace memory photo'),
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

  Widget _defaultMemoryImage() {
    return Image.asset(
      'assets/images/wtdl_1.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
    );
  }

  // MARK: - Immediate things you need to do

  Widget _buildImmediateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Immediate things you need to do',
          icon: Icons.flag,
          tint: Colors.red,
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "You don't need to do these all at once.  Take your time!  "
            "It's not like we are going anywhere!",
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  // MARK: - Medical certificate

  Widget _buildMedicalCertificateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Medical certificate',
          icon: Icons.medical_services,
          tint: Colors.red,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contact the GP or hospital doctor to get the '
                  'Medical Certificate of Cause of Death (MCCD).',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Local Process',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The doctor will email this certificate directly to '
                  'Perth & Kinross Council. They will also pass your name '
                  'and phone number to the registration team so they know '
                  'who to contact.',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Death certificate

  Widget _buildDeathCertificateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Death certificate',
          icon: Icons.description,
          tint: Colors.blue,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Once you know the MCCD has been sent over by the medical '
                  'team, contact the Perth Registrars to schedule your '
                  'formal phone appointment:',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _pillButton(
                        icon: Icons.phone,
                        label: '01738 475121',
                        tint: Colors.green,
                        onTap: () => _launch('tel:01738475121'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _pillButton(
                        icon: Icons.email,
                        label: 'perth-registrars@pkc.gov.uk',
                        tint: Colors.blue,
                        onTap: () =>
                            _launch('mailto:perth-registrars@pkc.gov.uk'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                const Text(
                  'It helps to gather a few details about the person who '
                  'passed away before the registrar calls you.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Because the appointment is done over the phone, '
                        'you do not need the physical, original documents. '
                        'The registrar just needs you to read out the '
                        'information or confirm the details.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

/// Fullscreen viewer for the memory photo (asset or uploaded).
class _FullscreenPhotoViewer extends StatelessWidget {
  final Attachment? memoryAttachment;

  const _FullscreenPhotoViewer({required this.memoryAttachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Family photograph',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: memoryAttachment != null &&
                  memoryAttachment!.downloadUrl.isNotEmpty
              ? Image.network(
                  memoryAttachment!.downloadUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/wtdl_1.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox.shrink(),
                  ),
                )
              : Image.asset(
                  'assets/images/wtdl_1.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
      ),
    );
  }
}

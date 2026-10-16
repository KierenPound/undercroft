import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../repositories/sections_repository.dart';

final attachmentsProvider = FutureProvider.autoDispose
    .family<List<Attachment>, String>((ref, sectionId) async {
  final repo = ref.watch(sectionsRepositoryProvider);
  final attachments = await repo.fetchAttachments(sectionId);

  // Hold the result for a few minutes after the last widget stops listening,
  // so returning to a section renders its photo straight away instead of
  // re-running the query and re-showing the placeholder. An upload still
  // refetches immediately: those paths call ref.refresh/invalidate.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  return attachments;
});

class AttachmentsSection extends ConsumerStatefulWidget {
  final String sectionId;
  final String estateId;
  final bool isOwner;

  const AttachmentsSection({
    super.key,
    required this.sectionId,
    required this.estateId,
    required this.isOwner,
  });

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  bool _uploading = false;

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    for (final file in picked) {
      try {
        final bytes = await file.readAsBytes();
        final mimeType = file.mimeType ?? 'image/jpeg';
        await repo.uploadAttachment(
          sectionId: widget.sectionId,
          estateId: widget.estateId,
          fileName: file.name,
          type: AttachmentType.photo,
          bytes: bytes,
          mimeType: mimeType,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}')),
          );
        }
      }
    }

    ref.refresh(attachmentsProvider(widget.sectionId));
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    for (final file in result.files) {
      try {
        final bytes = file.bytes ?? Uint8List(0);
        final ext = file.extension?.toLowerCase() ?? '';
        final type = ext == 'pdf' ? AttachmentType.pdf : AttachmentType.photo;
        final mime = ext == 'pdf'
            ? 'application/pdf'
            : ext == 'png'
                ? 'image/png'
                : 'image/jpeg';
        await repo.uploadAttachment(
          sectionId: widget.sectionId,
          estateId: widget.estateId,
          fileName: file.name,
          type: type,
          bytes: bytes,
          mimeType: mime,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}')),
          );
        }
      }
    }

    ref.refresh(attachmentsProvider(widget.sectionId));
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _openAttachment(Attachment attachment) async {
    if (attachment.downloadUrl.isEmpty) return;
    final uri = Uri.parse(attachment.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attachment?'),
        content:
            const Text('This will permanently remove the file from storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(sectionsRepositoryProvider);
      try {
        await repo.deleteAttachment(attachment);
        ref.refresh(attachmentsProvider(widget.sectionId));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete attachment')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncAttachments = ref.watch(attachmentsProvider(widget.sectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.attach_file, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2E),
              ),
            ),
            if (!widget.isOwner) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Read-only',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
            const Spacer(),
            if (_uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.isOwner)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickPhotos,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Add Photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickFiles,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Add PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        if (widget.isOwner) const SizedBox(height: 12),
        asyncAttachments.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) =>
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
          data: (attachments) {
            if (attachments.isEmpty) {
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.attach_file,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          widget.isOwner
                              ? 'Upload photos or PDFs here to store them securely.'
                              : 'Estate Owner hasn\'t uploaded any attachments yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _AttachmentCard(
                    attachment: attachments[index],
                    onTap: () => _openAttachment(attachments[index]),
                    onDelete: widget.isOwner
                        ? () => _deleteAttachment(attachments[index])
                        : null,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AttachmentCard({
    required this.attachment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: attachment.type == AttachmentType.pdf
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: attachment.type == AttachmentType.pdf
                      ? (attachment.downloadUrl.isNotEmpty
                          ? _PdfThumbnail(
                              url: attachment.downloadUrl,
                              width: 140,
                              height: 140,
                            )
                          : const Center(
                              child: Icon(Icons.picture_as_pdf,
                                  size: 48, color: Colors.orange),
                            ))
                      : (attachment.downloadUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                attachment.downloadUrl,
                                fit: BoxFit.cover,
                                width: 140,
                                height: 140,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.photo,
                                      size: 48, color: Colors.grey),
                                ),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.photo,
                                  size: 48, color: Colors.grey),
                            )),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: attachment.type == AttachmentType.pdf
                        ? Colors.orange
                        : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    attachment.type == AttachmentType.pdf
                        ? Icons.picture_as_pdf
                        : Icons.photo,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
              if (onDelete != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            attachment.fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C2C2E),
            ),
          ),
          if (attachment.formattedSize.isNotEmpty)
            Text(
              attachment.formattedSize,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }
}

class _PdfThumbnail extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const _PdfThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  Uint8List? _imageBytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    debugPrint('PDF thumbnail: rendering from url=${widget.url}');
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final bytes = response.bodyBytes;
      debugPrint('PDF thumbnail: downloaded ${bytes.length} bytes');

      PdfDocument doc;
      if (kIsWeb) {
        doc = await PdfDocument.openData(bytes);
      } else {
        final tempFile = File(
            '${Directory.systemTemp.path}/pdf_thumb_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(bytes);
        doc = await PdfDocument.openFile(tempFile.path);
      }

      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: 280,
        height: 400,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      await doc.close();
      debugPrint('PDF thumbnail: rendered ${pageImage?.bytes.length} bytes');

      if (mounted && pageImage?.bytes != null) {
        setState(() => _imageBytes = pageImage!.bytes);
      }
    } catch (e) {
      debugPrint('PDF thumbnail FAILED: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _imageBytes == null) {
      return Container(
        color: Colors.orange.withValues(alpha: 0.15),
        child: const Center(
          child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.orange),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      ),
    );
  }
}

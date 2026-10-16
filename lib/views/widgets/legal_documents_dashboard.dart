import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/attachment.dart';
import '../../repositories/sections_repository.dart';
import 'attachments_section.dart';
import 'song_for_the_page_section.dart';

/// Legal Documents rich-media dashboard.
///
/// Cloned from the FamilyPrep (iOS) `LegalDocumentsDashboardView`. Contains
/// (from the Wills section up to just before "Song for the page"):
/// 1. Wills — Solicitor contact (editable phone/email/URL) + Will documents
///    gallery (up to 2 PDFs).
/// 2. Title Deeds (House Deeds) — gallery of up to 5 PDFs.
class LegalDocumentsDashboard extends ConsumerStatefulWidget {
  final String sectionId;
  final String estateId;
  final bool isOwner;
  final String youtubeUrl;

  const LegalDocumentsDashboard({
    super.key,
    required this.sectionId,
    required this.estateId,
    required this.isOwner,
    required this.youtubeUrl,
  });

  @override
  ConsumerState<LegalDocumentsDashboard> createState() =>
      _LegalDocumentsDashboardState();
}

class _LegalDocumentsDashboardState
    extends ConsumerState<LegalDocumentsDashboard> {
  bool _uploading = false;

  // Default solicitor contact details.
  static const String _defaultSolicitorPhone = '01738231178';
  static const String _defaultSolicitorPhoneDisplay = '01738 231178';
  static const String _defaultSolicitorEmail = 'AHoggan@solicitor-law.co.uk';
  static const String _defaultSolicitorUrl = 'https://www.solicitor-law.co.uk';

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _urlController = TextEditingController();
  bool _initialized = false;
  Timer? _saveTimer;
  String _lastSavedPhone = '';
  String _lastSavedEmail = '';
  String _lastSavedUrl = '';

  static const int _maxWills = 2;
  static const int _maxDeeds = 5;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _phoneController.dispose();
    _emailController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String get _effectivePhone => _phoneController.text.trim().isNotEmpty
      ? _phoneController.text.trim()
      : _defaultSolicitorPhone;

  String get _effectiveEmail => _emailController.text.trim().isNotEmpty
      ? _emailController.text.trim()
      : _defaultSolicitorEmail;

  String get _effectiveUrl => _urlController.text.trim().isNotEmpty
      ? _urlController.text.trim()
      : _defaultSolicitorUrl;

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveContact);
  }

  Future<void> _saveContact() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final url = _urlController.text.trim();
    if (phone == _lastSavedPhone &&
        email == _lastSavedEmail &&
        url == _lastSavedUrl) {
      return;
    }

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(
          section.copyWith(
            solicitorPhone: phone,
            solicitorEmail: email,
            solicitorUrl: url,
          ),
        );
        _lastSavedPhone = phone;
        _lastSavedEmail = email;
        _lastSavedUrl = url;
        ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save contact details')),
        );
      }
    }
  }

  List<Attachment> _filterAttachments(
    List<Attachment> attachments,
    String prefix,
  ) {
    final list = attachments
        .where((a) => a.fileName.toLowerCase().startsWith(prefix))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  Future<void> _pickPdfs({
    required String prefix,
    required int maxCount,
  }) async {
    final existing =
        ref.read(attachmentsProvider(widget.sectionId)).valueOrNull ??
            <Attachment>[];
    final currentCount = existing
        .where((a) => a.fileName.toLowerCase().startsWith(prefix))
        .length;

    if (currentCount >= maxCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can upload up to $maxCount PDFs'),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _uploading = true);
    final repo = ref.read(sectionsRepositoryProvider);

    final availableSlots = maxCount - currentCount;
    final toUpload = result.files.take(availableSlots).toList();

    for (var i = 0; i < toUpload.length; i++) {
      final file = toUpload[i];
      try {
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) continue;
        await repo.uploadAttachment(
          sectionId: widget.sectionId,
          estateId: widget.estateId,
          fileName: '$prefix${currentCount + i + 1}_${file.name}',
          type: AttachmentType.pdf,
          bytes: bytes,
          mimeType: 'application/pdf',
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      ref.invalidate(attachmentsProvider(widget.sectionId));
    }
  }

  Future<void> _deleteAttachment(Attachment attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PDF?'),
        content: const Text('This will permanently remove the file.'),
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
    if (confirmed != true) return;

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      await repo.deleteAttachment(attachment);
      ref.invalidate(attachmentsProvider(widget.sectionId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete PDF')),
        );
      }
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSection = ref.watch(sectionProvider(widget.sectionId));
    asyncSection.maybeWhen(
      data: (section) {
        if (!_initialized) {
          _phoneController.text = section.solicitorPhone;
          _emailController.text = section.solicitorEmail;
          _urlController.text = section.solicitorUrl;
          _lastSavedPhone = section.solicitorPhone;
          _lastSavedEmail = section.solicitorEmail;
          _lastSavedUrl = section.solicitorUrl;
          _initialized = true;
        }
      },
      orElse: () {},
    );

    final attachments =
        ref.watch(attachmentsProvider(widget.sectionId)).valueOrNull ??
            <Attachment>[];
    final wills = _filterAttachments(attachments, 'will_');
    final deeds = _filterAttachments(attachments, 'deed_');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWillsSection(wills),
        const SizedBox(height: 28),
        _buildTitleDeedsSection(deeds),
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
            Flexible(
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

  Widget _editableContactField({
    required TextEditingController controller,
    required IconData icon,
    required Color tint,
    required String hint,
    required TextInputType keyboardType,
    required IconData actionIcon,
    required VoidCallback onAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              onChanged: (_) => _scheduleSave(),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ),
          IconButton(
            icon: Icon(actionIcon, size: 18, color: tint),
            onPressed: onAction,
          ),
        ],
      ),
    );
  }

  // MARK: - Wills

  Widget _buildWillsSection(List<Attachment> wills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Wills',
          icon: Icons.draw,
          tint: Colors.purple,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The solicitors hold the master document. There will be paper '
                  'copies in the bureau, in the sitting room.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _buildSubHeading(
                  icon: Icons.account_balance_rounded,
                  title: 'Contact Solicitors',
                  tint: Colors.purple,
                ),
                const SizedBox(height: 10),
                if (widget.isOwner) ...[
                  _editableContactField(
                    controller: _phoneController,
                    icon: Icons.phone,
                    tint: Colors.green,
                    hint: 'Phone (default: $_defaultSolicitorPhoneDisplay)',
                    keyboardType: TextInputType.phone,
                    actionIcon: Icons.call,
                    onAction: () => _launch('tel:$_effectivePhone'),
                  ),
                  const SizedBox(height: 8),
                  _editableContactField(
                    controller: _emailController,
                    icon: Icons.email,
                    tint: Colors.blue,
                    hint: 'Email (default: $_defaultSolicitorEmail)',
                    keyboardType: TextInputType.emailAddress,
                    actionIcon: Icons.send,
                    onAction: () => _launch('mailto:$_effectiveEmail'),
                  ),
                  const SizedBox(height: 8),
                  _editableContactField(
                    controller: _urlController,
                    icon: Icons.language,
                    tint: Colors.teal,
                    hint: 'Website (default: $_defaultSolicitorUrl)',
                    keyboardType: TextInputType.url,
                    actionIcon: Icons.open_in_new_rounded,
                    onAction: () => _launch(_effectiveUrl),
                  ),
                ] else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pillButton(
                        icon: Icons.phone,
                        label: _defaultSolicitorPhoneDisplay,
                        tint: Colors.green,
                        onTap: () => _launch('tel:$_effectivePhone'),
                      ),
                      _pillButton(
                        icon: Icons.email,
                        label: _effectiveEmail,
                        tint: Colors.blue,
                        onTap: () => _launch('mailto:$_effectiveEmail'),
                      ),
                      _pillButton(
                        icon: Icons.language,
                        label: _effectiveUrl.replaceFirst(
                            RegExp(r'^https?://'), ''),
                        tint: Colors.teal,
                        onTap: () => _launch(_effectiveUrl),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _buildSubHeading(
                  icon: Icons.description,
                  title: 'Will documents',
                  tint: Colors.purple,
                ),
                const SizedBox(height: 8),
                _tipRow(
                  'Tap any card below to open and read the full Will PDF.',
                  Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildPdfGrid(
                  attachments: wills,
                  maxCount: _maxWills,
                  tint: Colors.purple,
                  emptyOwnerText: 'Upload up to $_maxWills Will PDFs.',
                  emptyViewerText: 'No Will PDFs uploaded yet.',
                  addLabel: 'Add Will PDFs',
                  prefix: 'will_',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Title Deeds

  Widget _buildTitleDeedsSection(List<Attachment> deeds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Title Deeds',
          icon: Icons.house_rounded,
          tint: Colors.brown,
        ),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Below are the official title sheets and plans from '
                  'Scotland Land Information Service.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _tipRow(
                  'Tap any card below to open and read the full Land '
                  'Registry PDF.',
                  Colors.brown,
                ),
                const SizedBox(height: 12),
                _buildPdfGrid(
                  attachments: deeds,
                  maxCount: _maxDeeds,
                  tint: Colors.brown,
                  emptyOwnerText: 'Upload up to $_maxDeeds Title Deed PDFs.',
                  emptyViewerText: 'No Title Deed PDFs uploaded yet.',
                  addLabel: 'Add Title Deed PDFs',
                  prefix: 'deed_',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - Shared sub-components

  Widget _buildSubHeading({
    required IconData icon,
    required String title,
    required Color tint,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: tint),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: tint,
          ),
        ),
      ],
    );
  }

  Widget _tipRow(String text, Color tint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lightbulb, size: 14, color: Colors.amber.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfGrid({
    required List<Attachment> attachments,
    required int maxCount,
    required Color tint,
    required String emptyOwnerText,
    required String emptyViewerText,
    required String addLabel,
    required String prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attachments.isNotEmpty)
          _pdfTileRow(attachments, tint)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  widget.isOwner ? emptyOwnerText : emptyViewerText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        if (widget.isOwner) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading || attachments.length >= maxCount
                  ? null
                  : () => _pickPdfs(prefix: prefix, maxCount: maxCount),
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add, color: Colors.white),
              label: Text(
                _uploading
                    ? 'Uploading...'
                    : attachments.length >= maxCount
                        ? 'Maximum reached ($maxCount)'
                        : addLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tint,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Renders the PDF tiles in a 2-column grid, matching the iOS layout where
  /// each tile is a square (tileSide x tileSide) thumbnail + title.
  Widget _pdfTileRow(List<Attachment> attachments, Color tint) {
    final rows = <Widget>[];
    for (var i = 0; i < attachments.length; i += 2) {
      final end = (i + 2 > attachments.length) ? attachments.length : i + 2;
      final rowItems = attachments.sublist(i, end);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _pdfTile(rowItems[0], tint)),
            if (rowItems.length > 1) ...[
              const SizedBox(width: 12),
              Expanded(child: _pdfTile(rowItems[1], tint)),
            ] else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      );
      if (i + 2 < attachments.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(children: rows);
  }

  Widget _pdfTile(Attachment attachment, Color tint) {
    // Strip the numeric prefix (e.g. "will_1_") for display.
    final displayName =
        attachment.fileName.replaceFirst(RegExp(r'^(will|deed)_\d+_'), '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _openPdf(attachment),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _PdfThumbnail(url: attachment.downloadUrl),
                  ),
                ),
              ),
              if (widget.isOwner)
                Positioned(
                  top: 4,
                  left: 4,
                  child: GestureDetector(
                    onTap: () => _deleteAttachment(attachment),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2E),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.picture_as_pdf, size: 11, color: tint),
            const SizedBox(width: 3),
            Text(
              'Tap to open PDF',
              style: TextStyle(fontSize: 11, color: tint),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPdf(Attachment attachment) async {
    if (attachment.downloadUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPdfViewer(attachment: attachment),
      ),
    );
  }
}

// MARK: - Fullscreen PDF viewer

class _FullscreenPdfViewer extends StatefulWidget {
  final Attachment attachment;

  const _FullscreenPdfViewer({required this.attachment});

  @override
  State<_FullscreenPdfViewer> createState() => _FullscreenPdfViewerState();
}

class _FullscreenPdfViewerState extends State<_FullscreenPdfViewer> {
  PdfController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(widget.attachment.downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final doc = await PdfDocument.openData(response.bodyBytes);
      if (mounted) {
        setState(() {
          _controller = PdfController(document: Future.value(doc));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.attachment.fileName
              .replaceFirst(RegExp(r'^(will|deed)_\d+_'), ''),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Failed to load PDF: $_error',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : PdfView(
                  controller: _controller!,
                  scrollDirection: Axis.horizontal,
                ),
    );
  }
}

// MARK: - PDF thumbnail renderer

class _PdfThumbnail extends StatefulWidget {
  final String url;

  const _PdfThumbnail({required this.url});

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
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final bytes = response.bodyBytes;

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
        width: 300,
        height: 300,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      await doc.close();

      if (mounted && pageImage?.bytes != null) {
        setState(() => _imageBytes = pageImage!.bytes);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _imageBytes == null) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.orange),
        ),
      );
    }
    return Image.memory(
      _imageBytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

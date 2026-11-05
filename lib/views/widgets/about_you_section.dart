import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/about_you.dart';
import '../../repositories/about_you_repository.dart';

/// Uppercases as the user types, so an NI number reads the same way it is
/// stored. Uppercasing never changes the length, so the caret stays put.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Settings section holding one identity record per estate owner: full name,
/// NI number, CHI number, and a scanned passport and driving licence.
///
/// Any linked member can read these; only owners can add, edit or delete.
class AboutYouSection extends ConsumerWidget {
  final String estateId;
  final bool isOwner;

  const AboutYouSection({
    super.key,
    required this.estateId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(aboutYouListProvider);

    return asyncEntries.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load these records.',
            style: TextStyle(fontSize: 13, color: Colors.red.shade400),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => ref.invalidate(aboutYouListProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (entries) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The personal details an executor needs for each owner. '
              'Only you and your invited people can see these.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text(
                isOwner
                    ? 'No records yet. Add one for each estate owner.'
                    : 'No records have been added yet.',
                style: const TextStyle(fontSize: 14, color: Colors.black45),
              ),
            for (int i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _AboutYouCard(
                key: ValueKey(entries[i].aboutYouId),
                entry: entries[i],
                isOwner: isOwner,
              ),
            ],
            if (isOwner) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add owner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B7C6A),
                    side: const BorderSide(color: Color(0xFF5B7C6A)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    if (estateId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No estate found. Create one first.')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add owner'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Full name',
            hintText: 'e.g. Kieren Pound',
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    final repo = ref.read(aboutYouRepositoryProvider);
    try {
      await repo.insert(AboutYou(
        aboutYouId: '',
        estateId: estateId,
        fullName: result.trim(),
        niNumber: '',
        chiNumber: '',
        createdAt: DateTime.now(),
      ));
      ref.invalidate(aboutYouListProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add this owner')),
        );
      }
    }
  }
}

class _AboutYouCard extends ConsumerStatefulWidget {
  final AboutYou entry;
  final bool isOwner;

  const _AboutYouCard({
    super.key,
    required this.entry,
    required this.isOwner,
  });

  @override
  ConsumerState<_AboutYouCard> createState() => _AboutYouCardState();
}

class _AboutYouCardState extends ConsumerState<_AboutYouCard> {
  static const Color tint = Color(0xFF5B7C6A);

  late TextEditingController _nameController;
  late TextEditingController _niController;
  late TextEditingController _chiController;

  /// Local copy, so uploads and edits render immediately without waiting for a
  /// list refetch (which would rebuild the text fields mid-typing).
  late AboutYou _entry;

  Timer? _debounce;
  String _lastSavedName = '';
  String _lastSavedNi = '';
  String _lastSavedChi = '';
  bool _busy = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _nameController = TextEditingController(text: _entry.fullName);
    _niController = TextEditingController(text: _entry.niNumber);
    _chiController = TextEditingController(text: _entry.chiNumber);
    _lastSavedName = _entry.fullName;
    _lastSavedNi = _entry.niNumber;
    _lastSavedChi = _entry.chiNumber;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _niController.dispose();
    _chiController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveTextFields);
  }

  Future<void> _saveTextFields() async {
    final name = _nameController.text.trim();
    final ni = _niController.text.trim();
    final chi = _chiController.text.trim();
    if (name.isEmpty) return;
    if (name == _lastSavedName && ni == _lastSavedNi && chi == _lastSavedChi) {
      return;
    }

    final repo = ref.read(aboutYouRepositoryProvider);
    try {
      final saved = await repo.update(
        _entry.copyWith(fullName: name, niNumber: ni, chiNumber: chi),
      );
      if (!mounted) return;
      setState(() => _entry = saved);
      _lastSavedName = name;
      _lastSavedNi = ni;
      _lastSavedChi = chi;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save these details')),
        );
      }
    }
  }

  Future<void> _pickDocument(AboutYouDocument doc) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    final repo = ref.read(aboutYouRepositoryProvider);
    try {
      final bytes = await picked.readAsBytes();
      final saved = await repo.uploadDocument(
        entry: _entry,
        doc: doc,
        bytes: bytes,
        mimeType: picked.mimeType ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        _entry = saved;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload ${_label(doc)}')),
      );
    }
  }

  Future<void> _removeDocument(AboutYouDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_label(doc)}?'),
        content: const Text('This will permanently remove the image.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final repo = ref.read(aboutYouRepositoryProvider);
    try {
      final saved = await repo.removeDocument(entry: _entry, doc: doc);
      if (!mounted) return;
      setState(() {
        _entry = saved;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove ${_label(doc)}')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final label =
        _entry.fullName.trim().isEmpty ? 'this record' : '"${_entry.fullName}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
            'This permanently deletes $label, including any scanned images.'),
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

    final repo = ref.read(aboutYouRepositoryProvider);
    try {
      await repo.delete(_entry);
      ref.invalidate(aboutYouListProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this record')),
        );
      }
    }
  }

  static String _label(AboutYouDocument doc) =>
      doc == AboutYouDocument.passport ? 'passport' : 'driving licence';

  void _viewFullscreen(AboutYouDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenDocumentViewer(
          title: '${_entry.fullName} — ${_label(doc)}',
          imageUrl: _entry.downloadUrlFor(doc),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _nameController.text.trim().isEmpty
        ? 'New owner'
        : _nameController.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.badge_outlined, color: tint, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 22,
                  color: Colors.grey.shade600,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                tooltip: _expanded ? 'Hide details' : 'Show details',
              ),
              if (widget.isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: _confirmDelete,
                  tooltip: 'Delete record',
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Full name',
            controller: _nameController,
            hint: 'Full name',
            textCapitalization: TextCapitalization.words,
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            _buildField(
              label: 'NI number',
              controller: _niController,
              hint: 'QQ 12 34 56 C',
              monospace: true,
              inputFormatters: [_UpperCaseFormatter()],
            ),
            const SizedBox(height: 12),
            _buildField(
              label: 'CHI number',
              controller: _chiController,
              hint: '10 digits',
              monospace: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _documentSlot(
                    doc: AboutYouDocument.passport,
                    label: 'Passport',
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _documentSlot(
                    doc: AboutYouDocument.licence,
                    label: 'Driving licence',
                    icon: Icons.directions_car_outlined,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentSlot({
    required AboutYouDocument doc,
    required String label,
    required IconData icon,
  }) {
    final hasImage = _entry.hasDocument(doc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: GestureDetector(
            onTap: hasImage
                ? () => _viewFullscreen(doc)
                : (widget.isOwner && !_busy ? () => _pickDocument(doc) : null),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? Image.network(
                      _entry.downloadUrlFor(doc),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.grey.shade400),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: Colors.grey.shade400, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            widget.isOwner ? 'Add image' : 'Not added',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (hasImage)
          Row(
            children: [
              Expanded(
                child: Text(
                  _formattedSize(_entry.fileSizeFor(doc)),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              if (widget.isOwner)
                TextButton(
                  onPressed: _busy ? null : () => _removeDocument(doc),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Remove',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          )
        else
          Text(
            widget.isOwner ? 'JPG or PNG' : '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
      ],
    );
  }

  static String _formattedSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool monospace = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: widget.isOwner,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontFamily: monospace ? 'monospace' : null,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: widget.isOwner ? Colors.white : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: tint, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          onChanged: (_) {
            setState(() {});
            if (widget.isOwner) _scheduleSave();
          },
          onEditingComplete: () {
            FocusScope.of(context).unfocus();
            _saveTextFields();
          },
        ),
      ],
    );
  }
}

class _FullscreenDocumentViewer extends StatelessWidget {
  final String title;
  final String imageUrl;

  const _FullscreenDocumentViewer({
    required this.title,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'Could not load this image.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

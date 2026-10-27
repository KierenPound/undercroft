import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ad_hoc_data.dart';
import '../repositories/ad_hoc_data_repository.dart';
import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';
import 'widgets/attachments_section.dart';

/// Ad Hoc Data: a free-form list of user-defined records so anything the
/// standard sections do not cover can still live in one place.
///
/// Each record carries a title, email, URL and notes, and is saved or deleted
/// individually — the same interaction as the organisation entries in
/// Who to Notify.
class AdHocDataView extends ConsumerWidget {
  const AdHocDataView({super.key});

  static const _config = SectionConfig(
    title: 'Ad Hoc Data',
    orderIndex: 9,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEstateId = ref.watch(estateIdProvider);
    final asyncIsOwner = ref.watch(isOwnerProvider);
    final asyncSection = ref.watch(sectionByTitleProvider(_config));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Hoc Data'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_config.infoText.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About this page',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Ad Hoc Data'),
                  content: Text(
                    _config.infoText,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F1E8), Color(0xFFEDE6D6)],
          ),
        ),
        child: asyncEstateId.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (estateId) {
            if (estateId.isEmpty) {
              return const Center(child: Text('No estate found.'));
            }
            final isOwner = asyncIsOwner.valueOrNull ?? true;
            final asyncEntries = ref.watch(adHocDataListProvider);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Intro(),
                const SizedBox(height: 20),
                if (isOwner) ...[
                  _AddButton(onAdd: () => _add(ref, estateId)),
                  const SizedBox(height: 16),
                ],
                asyncEntries.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Error: $error', textAlign: TextAlign.center),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(adHocDataListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const _EmptyState();
                    }
                    return Column(
                      children: [
                        for (final entry in entries)
                          _AdHocCard(entry: entry, isOwner: isOwner),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                asyncSection.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Center(
                    child: Text('Error: $error', textAlign: TextAlign.center),
                  ),
                  data: (section) => AttachmentsSection(
                    sectionId: section.id,
                    estateId: estateId,
                    isOwner: isOwner,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _add(WidgetRef ref, String estateId) async {
    final repo = ref.read(adHocDataRepositoryProvider);
    await repo.insert(AdHocData(
      adHocDataId: '',
      estateId: estateId,
      title: '',
      email: '',
      url: '',
      notes: '',
      createdAt: DateTime.now(),
    ));
    ref.invalidate(adHocDataListProvider);
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D5FCD).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: Color(0xFF2D5FCD), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This page is for you to enter your own ad hoc sections of data. '
              'For example, how to operate your robot lawnmower. It\'s to keep '
              'things in one place not already covered. You can add a title, '
              'email, URL and notes.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add Ad Hoc Data'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3A8D5A),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No ad hoc data yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your own sections for anything not already covered.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AdHocCard extends ConsumerStatefulWidget {
  final AdHocData entry;
  final bool isOwner;

  const _AdHocCard({required this.entry, required this.isOwner});

  @override
  ConsumerState<_AdHocCard> createState() => _AdHocCardState();
}

class _AdHocCardState extends ConsumerState<_AdHocCard> {
  static const Color tint = Color(0xFF2D5FCD);

  late TextEditingController _titleController;
  late TextEditingController _emailController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry.title);
    _emailController = TextEditingController(text: widget.entry.email);
    _urlController = TextEditingController(text: widget.entry.url);
    _notesController = TextEditingController(text: widget.entry.notes);
    // A record with no title yet is one that has just been added, so open it
    // straight into edit mode ready to be filled in.
    _editing = widget.isOwner && widget.entry.title.trim().isEmpty;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _emailController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _syncControllers(AdHocData entry) {
    _titleController.text = entry.title;
    _emailController.text = entry.email;
    _urlController.text = entry.url;
    _notesController.text = entry.notes;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this entry a title.')),
      );
      return;
    }

    final repo = ref.read(adHocDataRepositoryProvider);
    await repo.update(widget.entry.copyWith(
      title: title,
      email: _emailController.text.trim(),
      url: _urlController.text.trim(),
      notes: _notesController.text.trim(),
    ));
    ref.invalidate(adHocDataListProvider);
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _confirmDelete() async {
    final label = widget.entry.title.trim().isEmpty
        ? 'this entry'
        : '"${widget.entry.title.trim()}"';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('This will permanently delete $label.'),
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
      final repo = ref.read(adHocDataRepositoryProvider);
      await repo.delete(widget.entry.adHocDataId);
      ref.invalidate(adHocDataListProvider);
    }
  }

  Future<void> _launch(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri =
        Uri.parse(trimmed.startsWith('http') ? trimmed : 'https://$trimmed');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _mailTo(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: trimmed);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _titleController,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        )
                      : Text(
                          widget.entry.title.trim().isEmpty
                              ? 'Untitled'
                              : widget.entry.title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
                if (widget.isOwner)
                  IconButton(
                    icon: Icon(_editing ? Icons.check : Icons.edit, size: 20),
                    tooltip: _editing ? 'Save' : 'Edit details',
                    onPressed: () {
                      if (_editing) {
                        _save();
                      } else {
                        _syncControllers(widget.entry);
                        setState(() => _editing = true);
                      }
                    },
                  ),
                if (widget.isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    tooltip: 'Delete entry',
                    onPressed: _confirmDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow(
              icon: Icons.mail_outline,
              hint: 'Email',
              value: widget.entry.email,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              actionIcon: Icons.send,
              onAction: () => _mailTo(_emailController.text),
            ),
            const SizedBox(height: 12),
            _buildRow(
              icon: Icons.public_rounded,
              hint: 'URL',
              value: widget.entry.url,
              controller: _urlController,
              keyboardType: TextInputType.url,
              actionIcon: Icons.open_in_new_rounded,
              onAction: () => _launch(_urlController.text),
              isUrl: true,
            ),
            const SizedBox(height: 12),
            _buildNotes(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String hint,
    required String value,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required IconData actionIcon,
    required VoidCallback onAction,
    bool isUrl = false,
  }) {
    final text = _editing ? controller.text : value;
    final hasValue = text.trim().isNotEmpty;
    final color = isUrl ? Colors.blue : tint;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: _editing
                ? TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 0,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  )
                : Text(
                    hasValue ? text : hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? color : Colors.grey.shade500,
                    ),
                  ),
          ),
          IconButton(
            icon: Icon(
              actionIcon,
              size: 18,
              color: hasValue ? color : color.withValues(alpha: 0.35),
            ),
            onPressed: hasValue ? onAction : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(Icons.notes, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _editing
              ? TextField(
                  controller: _notesController,
                  maxLines: null,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.entry.notes.trim().isEmpty
                        ? 'Notes'
                        : widget.entry.notes,
                    style: TextStyle(
                      fontSize: 15,
                      color: widget.entry.notes.trim().isEmpty
                          ? Colors.grey.shade400
                          : const Color(0xFF2C2C2E),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/funeral_arrangement.dart';
import '../../repositories/funeral_arrangements_repository.dart';

/// Funeral Arrangements rich-content dashboard.
///
/// Replaces the previous hard-coded "Funeral (Kieren)" / "Funeral (Bren)"
/// sections with a dynamic, owner-editable list. Each arrangement is a separate
/// section titled "Funeral ({name})" with editable name, free-text notes, and URL.
class FuneralArrangementsDashboard extends ConsumerWidget {
  final String estateId;
  final bool isOwner;

  const FuneralArrangementsDashboard({
    super.key,
    required this.estateId,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(funeralArrangementsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOwner)
          _AddArrangementButton(
            onAdd: () => _showAddDialog(context, ref, estateId),
          ),
        const SizedBox(height: 16),
        asyncEntries.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Center(
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text('Error: $error', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(funeralArrangementsListProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return _EmptyState(
                onAdd: isOwner
                    ? () => _showAddDialog(context, ref, estateId)
                    : null,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  _ArrangementCard(
                    entry: entries[i],
                    estateId: estateId,
                    isOwner: isOwner,
                  ),
                  if (i < entries.length - 1) const SizedBox(height: 28),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, WidgetRef ref, String estateId) async {
    if (estateId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No estate found. Create one first.')),
        );
      }
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add funeral arrangement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name (e.g. Kieren, Bren)',
            hintText: 'The section will show "Funeral (name)"',
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

    if (result != null && result.trim().isNotEmpty) {
      final repo = ref.read(funeralArrangementsRepositoryProvider);
      await repo.insert(FuneralArrangement(
        funeralArrangementId: '',
        estateId: estateId,
        name: result.trim(),
        notes: '',
        url: '',
        createdAt: DateTime.now(),
      ));
      ref.invalidate(funeralArrangementsListProvider);
    }
  }
}

// MARK: - Add button

class _AddArrangementButton extends StatelessWidget {
  final VoidCallback onAdd;

  const _AddArrangementButton({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 20),
      label: const Text('Add funeral arrangement'),
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

// MARK: - Empty state

class _EmptyState extends StatelessWidget {
  final VoidCallback? onAdd;

  const _EmptyState({this.onAdd});

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
          Icon(Icons.celebration_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No funeral arrangements yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add one for each estate owner.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add arrangement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A8D5A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// MARK: - Arrangement card (editable inline)

class _ArrangementCard extends ConsumerStatefulWidget {
  final FuneralArrangement entry;
  final String estateId;
  final bool isOwner;

  const _ArrangementCard({
    required this.entry,
    required this.estateId,
    required this.isOwner,
  });

  @override
  ConsumerState<_ArrangementCard> createState() => _ArrangementCardState();
}

class _ArrangementCardState extends ConsumerState<_ArrangementCard> {
  static const Color tint = Colors.indigo;

  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _urlController;
  Timer? _debounce;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _notesController = TextEditingController(text: widget.entry.notes);
    _urlController = TextEditingController(text: widget.entry.url);
    _initialized = true;
  }

  @override
  void didUpdateWidget(covariant _ArrangementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep controllers in sync only when the underlying record id changes
    // (e.g. after a save round-trip) but never clobber in-progress typing.
    if (oldWidget.entry.funeralArrangementId !=
            widget.entry.funeralArrangementId ||
        (_initialized && _nameController.text != widget.entry.name)) {
      _nameController.text = widget.entry.name;
      _notesController.text = widget.entry.notes;
      _urlController.text = widget.entry.url;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _notesController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(funeralArrangementsRepositoryProvider);
    final updated = widget.entry.copyWith(
      name: name,
      notes: _notesController.text,
      url: _urlController.text.trim(),
    );
    await repo.update(updated);
    ref.invalidate(funeralArrangementsListProvider);
  }

  Future<void> _launch(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete arrangement?'),
        content: Text(
            'This will permanently delete "Funeral (${widget.entry.name})".'),
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
      final repo = ref.read(funeralArrangementsRepositoryProvider);
      await repo.delete(widget.entry.funeralArrangementId);
      ref.invalidate(funeralArrangementsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _nameController.text.trim().isEmpty ? '—' : _nameController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person, color: tint, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Funeral ($name)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ),
            if (widget.isOwner)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
                onPressed: _confirmDelete,
                tooltip: 'Delete arrangement',
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _buildField(
                  label: 'Name',
                  controller: _nameController,
                  hint: 'Name',
                  enabled: widget.isOwner,
                ),
                const SizedBox(height: 12),
                // Notes
                _buildField(
                  label: 'Notes',
                  controller: _notesController,
                  hint: 'Funeral wishes, instructions, etc.',
                  maxLines: null,
                  minLines: 4,
                  enabled: widget.isOwner,
                ),
                const SizedBox(height: 12),
                // URL — single blue-styled editable field with open button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'URL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlController,
                      enabled: widget.isOwner,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.normal,
                        ),
                        filled: true,
                        fillColor: widget.isOwner
                            ? Colors.blue.withValues(alpha: 0.04)
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.public_rounded,
                          color: Colors.blue,
                          size: 18,
                        ),
                        suffixIcon: _urlController.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.open_in_new,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    _launch(_urlController.text.trim()),
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.blue.withValues(alpha: 0.25),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.blue,
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                        if (widget.isOwner) _scheduleSave();
                      },
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int? maxLines = 1,
    int? minLines,
    required bool enabled,
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
          enabled: enabled,
          maxLines: maxLines,
          minLines: minLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
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
            if (enabled) _scheduleSave();
          },
        ),
      ],
    );
  }
}

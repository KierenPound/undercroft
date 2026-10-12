import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/prep_section.dart';
import '../../repositories/sections_repository.dart';

class NotesSection extends ConsumerStatefulWidget {
  final String sectionId;
  final bool isOwner;

  const NotesSection({
    super.key,
    required this.sectionId,
    required this.isOwner,
  });

  @override
  ConsumerState<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<NotesSection> {
  final _notesController = TextEditingController();
  bool _initialized = false;
  Timer? _saveTimer;
  String _lastSavedNotes = '';

  @override
  void dispose() {
    _saveTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveNotes);
  }

  Future<void> _saveNotes() async {
    final current = _notesController.text;
    if (current == _lastSavedNotes) return;

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(section.copyWith(notes: current));
        _lastSavedNotes = current;
        ref.invalidate(sectionProvider(widget.sectionId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save notes')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSection = ref.watch(sectionProvider(widget.sectionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sticky_note_2,
                  color: Colors.blueGrey, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Notes',
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
          ],
        ),
        const SizedBox(height: 12),
        asyncSection.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) =>
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
          data: (section) {
            if (!_initialized || _lastSavedNotes != section.notes) {
              _notesController.text = section.notes;
              _lastSavedNotes = section.notes;
              _initialized = true;
            }
            return _buildNotesEditor(section);
          },
        ),
      ],
    );
  }

  Widget _buildNotesEditor(PrepSection section) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: null,
        minLines: 6,
        enabled: widget.isOwner,
        onChanged: widget.isOwner ? (_) => _scheduleSave() : null,
        decoration: InputDecoration(
          hintText: widget.isOwner
              ? 'Type notes, instructions, or important details here...'
              : 'No notes yet.',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
        style: const TextStyle(fontSize: 15, color: Color(0xFF2C2C2E)),
      ),
    );
  }
}

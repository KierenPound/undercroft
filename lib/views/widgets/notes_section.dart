import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class _NotesSectionState extends ConsumerState<NotesSection>
    with WidgetsBindingObserver {
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  Timer? _saveTimer;
  String _lastSavedNotes = '';
  String? _lastAppliedStoredNotes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _flushPendingSave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushPendingSave();
    _notesFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveNotes);
  }

  void _flushPendingSave() {
    if (!(_saveTimer?.isActive ?? false)) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_saveNotes());
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
        if (mounted) ref.invalidate(sectionProvider(widget.sectionId));
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

    // Adopt whatever is stored the first time it arrives, and again whenever it
    // changes underneath us, without stomping on an in-flight edit. While the
    // field has focus the controller is the source of truth, so re-syncing here
    // would overwrite in-progress typing and jump the cursor.
    final storedNotes = asyncSection.valueOrNull?.notes ?? '';
    if (_lastAppliedStoredNotes != storedNotes && !_notesFocusNode.hasFocus) {
      _notesController.text = storedNotes;
      _lastSavedNotes = storedNotes;
      _lastAppliedStoredNotes = storedNotes;
    }

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
        if (asyncSection.isLoading && !asyncSection.hasValue)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (asyncSection.hasError && !asyncSection.hasValue)
          Text('Error: ${asyncSection.error}',
              style: const TextStyle(color: Colors.red))
        else
          _buildNotesEditor(),
      ],
    );
  }

  Widget _buildNotesEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _notesController,
        focusNode: _notesFocusNode,
        maxLines: null,
        minLines: 6,
        enabled: widget.isOwner,
        textCapitalization: TextCapitalization.sentences,
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

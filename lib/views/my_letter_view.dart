import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';

/// "My Letter to You" — a full-page letter the estate owner writes to their
/// family.
///
/// The text is stored on the "My Letter to You" section row
/// (`sections.letter_text`) and is only editable by the estate owner; a
/// co-owner/executor sees the same letter read-only. Written in the [Caveat]
/// handwriting font and scrollable inside its own box, since a letter can run
/// to several thousand characters.
class MyLetterView extends ConsumerWidget {
  final SectionConfig config;

  const MyLetterView({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIsOwner = ref.watch(isOwnerProvider);
    final isOwner = asyncIsOwner.valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(config.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (config.infoText.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About this page',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(config.title),
                  content: Text(
                    config.infoText,
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isOwner) ...[
                  const _ReadOnlyBadge(),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: ref.watch(sectionByTitleProvider(config)).when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Center(
                          child: Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        data: (section) => _LetterEditor(
                          sectionId: section.id,
                          isOwner: isOwner,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  const _ReadOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          'Read-only — only the estate owner can edit this letter.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _LetterEditor extends ConsumerStatefulWidget {
  final String sectionId;
  final bool isOwner;

  const _LetterEditor({required this.sectionId, required this.isOwner});

  @override
  ConsumerState<_LetterEditor> createState() => _LetterEditorState();
}

class _LetterEditorState extends ConsumerState<_LetterEditor> {
  final _letterController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _saveTimer;
  bool _initialized = false;
  String _lastSavedLetter = '';

  @override
  void dispose() {
    _saveTimer?.cancel();
    _letterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveLetter);
  }

  Future<void> _saveLetter() async {
    final current = _letterController.text;
    if (current == _lastSavedLetter) return;

    final repo = ref.read(sectionsRepositoryProvider);
    try {
      final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
      if (section != null) {
        await repo.updateSection(section.copyWith(letterText: current));
        _lastSavedLetter = current;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save letter')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSection = ref.watch(sectionProvider(widget.sectionId));

    return asyncSection.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (section) {
        if (!_initialized || _lastSavedLetter != section.letterText) {
          _letterController.text = section.letterText;
          _lastSavedLetter = section.letterText;
          _initialized = true;
        }
        return _buildLetterBox();
      },
    );
  }

  Widget _buildLetterBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: TextField(
          controller: _letterController,
          scrollController: _scrollController,
          readOnly: !widget.isOwner,
          maxLines: null,
          minLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: widget.isOwner ? (_) => _scheduleSave() : null,
          style: const TextStyle(
            fontFamily: 'Caveat',
            fontSize: 24,
            height: 1.4,
            color: Color(0xFF2C2C2E),
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: widget.isOwner
                ? 'Write your letter here...'
                : 'No letter has been written yet.',
            hintStyle: TextStyle(
              fontFamily: 'Caveat',
              fontSize: 24,
              height: 1.4,
              color: Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/utility_detail.dart';
import '../../repositories/utility_details_repository.dart';

/// One utility card on the Running the Houses page — Gas meter, Electric meter
/// or Stopcock.
///
/// A photo of the meter (or stopcock) sits on the left with the description
/// that explains where to find it and how to read it beside it on the right,
/// matched to the same size. Owners tap the photo to pick a replacement and
/// type straight into the description; everyone else gets a read-only view
/// that opens the photo full screen.
class UtilityDetailSection extends ConsumerStatefulWidget {
  final String estateId;
  final bool isOwner;
  final UtilityKind kind;

  const UtilityDetailSection({
    super.key,
    required this.estateId,
    required this.isOwner,
    required this.kind,
  });

  /// Height shared by the photo and the notes box, so the two read as a pair.
  static const double panelHeight = 200;

  @override
  ConsumerState<UtilityDetailSection> createState() =>
      _UtilityDetailSectionState();
}

class _UtilityDetailSectionState extends ConsumerState<UtilityDetailSection> {
  final _notesController = TextEditingController();
  Timer? _saveTimer;
  String _lastSavedNotes = '';
  bool _uploading = false;

  UtilityKind get _kind => widget.kind;

  @override
  void dispose() {
    _saveTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    final repo = ref.read(utilityDetailsRepositoryProvider);
    try {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      await repo.uploadImage(
        estateId: widget.estateId,
        kind: _kind,
        bytes: bytes,
        mimeType: mimeType,
      );
      ref.invalidate(utilityDetailsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_kind.label} photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNotes);
  }

  Future<void> _saveNotes() async {
    final current = _notesController.text;
    if (current == _lastSavedNotes) return;

    final repo = ref.read(utilityDetailsRepositoryProvider);
    try {
      await repo.saveNotes(
        estateId: widget.estateId,
        kind: _kind,
        notes: current,
      );
      _lastSavedNotes = current;
      ref.invalidate(utilityDetailsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save notes')),
        );
      }
    }
  }

  void _viewFullscreen(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenUtilityPhoto(
          imageUrl: imageUrl,
          title: _kind.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncDetails = ref.watch(utilityDetailsProvider);

    UtilityDetail? detail;
    for (final d in asyncDetails.valueOrNull ?? const <UtilityDetail>[]) {
      if (d.kind == _kind) {
        detail = d;
        break;
      }
    }

    // Adopt whatever is stored the first time it arrives, and again whenever
    // it changes underneath us, without stomping on an in-flight edit.
    final storedNotes = detail?.notes ?? '';
    if (_lastSavedNotes != storedNotes) {
      _notesController.text = storedNotes;
      _lastSavedNotes = storedNotes;
    }

    final resolving = !asyncDetails.hasValue;
    final imageUrl = detail?.imageUrl ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 14),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: UtilityDetailSection.panelHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _imagePanel(resolving, imageUrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _notesPanel(resolving)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kind.tint.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_kind.icon, color: _kind.tint, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _kind.label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2C2E),
            ),
          ),
        ),
        if (!widget.isOwner)
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

  /// The photo, sized to fill its half of the card. Owners tap to choose a
  /// replacement; anyone can tap the corner button to open it full screen.
  Widget _imagePanel(bool resolving, String imageUrl) {
    final hasImage = imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: widget.isOwner
          ? (_uploading ? null : _pickImage)
          : (hasImage ? () => _viewFullscreen(imageUrl) : null),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: _kind.tint.withValues(alpha: 0.08),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (resolving)
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (hasImage)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              else
                _placeholder(),
              if (hasImage && !resolving)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _circleButton(
                    icon: Icons.open_in_full,
                    onTap: () => _viewFullscreen(imageUrl),
                  ),
                ),
              if (widget.isOwner && !_uploading)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _circleButton(
                    icon: hasImage ? Icons.photo_camera : Icons.add_a_photo,
                    onTap: _pickImage,
                  ),
                ),
              if (_uploading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_kind.icon, size: 34, color: _kind.tint.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            widget.isOwner ? 'Tap to add a photo' : 'No photo yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  /// The description beside the photo, matched to the same size: a wrapped
  /// multi-line field for owners, plain text for everyone else.
  Widget _notesPanel(bool resolving) {
    const color = Colors.blueGrey;
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 14),
            child: Icon(Icons.notes, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: resolving
                ? const SizedBox.shrink()
                : widget.isOwner
                    ? TextField(
                        controller: _notesController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (_) => _scheduleSave(),
                        decoration: InputDecoration(
                          hintText: _notesHint,
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.fromLTRB(
                            0,
                            12,
                            12,
                            12,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFF2C2C2E),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                        child: Text(
                          _lastSavedNotes.trim().isEmpty
                              ? 'No notes yet'
                              : _lastSavedNotes,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: _lastSavedNotes.trim().isEmpty
                                ? Colors.grey.shade500
                                : const Color(0xFF2C2C2E),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  String get _notesHint {
    switch (_kind) {
      case UtilityKind.gasMeter:
        return 'Where the gas meter is and how to read it.';
      case UtilityKind.electricMeter:
        return 'Where the electric meter is and how to read it.';
      case UtilityKind.stopcock:
        return 'Where the stopcock is and how to turn the water off.';
    }
  }
}

/// Fullscreen view of a utility photo, pinch-zoomable.
class _FullscreenUtilityPhoto extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _FullscreenUtilityPhoto({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              );
            },
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../repositories/sections_repository.dart';
import '../services/estate_service.dart';
import '../services/video_compression_service.dart';
import 'biometric_lock_gate.dart';

/// "My Letter to You" — a full-page letter the estate owner writes to their
/// family, with an optional "My Video to You" clip underneath.
///
/// The text is stored on the "My Letter to You" section row
/// (`sections.letter_text`) and is only editable by the estate owner; a
/// co-owner/executor sees the same letter read-only. Written in the [Caveat]
/// handwriting font and scrollable inside its own box, since a letter can run
/// to several thousand characters.
///
/// The video is stored as a file in the private `estate-documents` bucket and
/// referenced from the same row, so it inherits the letter's access rules.
class MyLetterView extends ConsumerWidget {
  final SectionConfig config;

  const MyLetterView({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIsOwner = ref.watch(isOwnerProvider);
    final isOwner = asyncIsOwner.valueOrNull ?? true;
    final asyncSection = ref.watch(sectionByTitleProvider(config));
    final section = asyncSection.valueOrNull;

    // Keep the editor mounted across background refreshes so an in-progress
    // letter is never torn down underneath the caret.
    final Widget letterBody;
    if (section != null) {
      letterBody = _LetterEditor(sectionId: section.id, isOwner: isOwner);
    } else if (asyncSection.hasError) {
      letterBody = Center(
        child: Text(
          'Error: ${asyncSection.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    } else {
      letterBody = const Center(child: CircularProgressIndicator());
    }

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The letter keeps most of the screen, the clip sits below it,
              // and the page scrolls when both do not fit. A fixed fraction
              // rather than a fixed height is what stops the video box from
              // being squeezed off a small phone or lost on a tall tablet.
              final letterHeight =
                  math.max(280.0, constraints.maxHeight * 0.55);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isOwner) ...[
                      const _ReadOnlyBadge(),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(height: letterHeight, child: letterBody),
                    if (section != null) ...[
                      const SizedBox(height: 20),
                      _VideoToYouSection(
                        sectionId: section.id,
                        isOwner: isOwner,
                      ),
                    ],
                  ],
                ),
              );
            },
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

class _LetterEditorState extends ConsumerState<_LetterEditor>
    with WidgetsBindingObserver {
  final _letterController = TextEditingController();
  final _letterFocusNode = FocusNode();
  final _scrollController = ScrollController();
  Timer? _saveTimer;
  String _lastSavedLetter = '';
  String? _lastAppliedStoredLetter;

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
    _letterFocusNode.dispose();
    _letterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveLetter);
  }

  void _flushPendingSave() {
    if (!(_saveTimer?.isActive ?? false)) return;
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_saveLetter());
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

    // Adopt whatever is stored the first time it arrives, and again whenever it
    // changes underneath us, without stomping on an in-flight edit. While the
    // field has focus the controller is the source of truth, so re-syncing here
    // would overwrite in-progress typing and jump the cursor.
    final storedLetter = asyncSection.valueOrNull?.letterText ?? '';
    if (_lastAppliedStoredLetter != storedLetter &&
        !_letterFocusNode.hasFocus) {
      _letterController.text = storedLetter;
      _lastSavedLetter = storedLetter;
      _lastAppliedStoredLetter = storedLetter;
    }

    if (asyncSection.isLoading && !asyncSection.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (asyncSection.hasError && !asyncSection.hasValue) {
      return Center(
        child: Text(
          'Error: ${asyncSection.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return _buildLetterBox();
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
          focusNode: _letterFocusNode,
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

/// "My Video to You" — an optional short clip stored with the letter.
///
/// The owner can record one with the device camera or pick one already on the
/// device; an executor sees the same clip read-only. Files live in the private
/// `estate-documents` bucket and are played back through a short-lived signed
/// URL, so nothing is publicly reachable.
class _VideoToYouSection extends ConsumerStatefulWidget {
  final String sectionId;
  final bool isOwner;

  const _VideoToYouSection({required this.sectionId, required this.isOwner});

  @override
  ConsumerState<_VideoToYouSection> createState() => _VideoToYouSectionState();
}

class _VideoToYouSectionState extends ConsumerState<_VideoToYouSection> {
  bool _busy = false;

  /// True while a clip is being compressed, which is separate from [_busy]
  /// because it has its own progress and a Cancel button.
  bool _compressing = false;

  /// 0..1 while [_compressing]; 0 means "no reading yet", shown as an
  /// indeterminate bar.
  double _compressProgress = 0;

  /// The run currently compressing, so Cancel can reach it.
  VideoCompressionService? _compressor;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Picks a clip from the camera or the photo library and stores it.
  ///
  /// A clip over the small threshold is compressed on the device first, so a
  /// longer message can still fit the bucket's 50 MB limit — what has to fit is
  /// the number of bytes that reach Storage, not how long the recording is.
  Future<void> _addVideo(ImageSource source) async {
    final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
    if (section == null) return;

    XFile? picked;
    try {
      picked = await BiometricLockGate.suppressCoverWhile(
        () => ImagePicker().pickVideo(
          source: source,
          // A rough ceiling only: size is what actually decides whether a clip
          // fits, and compression gives a long recording a chance.
          maxDuration: const Duration(minutes: 10),
        ),
      );
    } catch (_) {
      _showMessage(
        source == ImageSource.camera
            ? 'Could not open the camera.'
            : 'Could not open your videos.',
      );
      return;
    }
    if (picked == null) return;

    // Measure on disk rather than by reading the clip into memory: reading a
    // large video just to weigh it would hold the whole thing in RAM for
    // nothing.
    final int pickedSize;
    try {
      pickedSize = await File(picked.path).length();
    } catch (_) {
      _showMessage('Could not read that video.');
      return;
    }
    if (!mounted) return;

    // The picker hands back its own scratch copy: on both iOS and Android the
    // path it returns already sits in the app's cache/tmp directory, never at
    // the user's original location. So this file is ours to delete when we are
    // done, and no second copy is needed.
    final originalPath = picked.path;

    VideoCompressionResult? prepared;
    try {
      final compressor = VideoCompressionService();
      setState(() {
        _compressing = true;
        _compressProgress = 0;
        _compressor = compressor;
      });

      prepared = await compressor.prepare(
        sourcePath: originalPath,
        sourceSizeBytes: pickedSize,
        onProgress: (progress) {
          if (mounted) setState(() => _compressProgress = progress);
        },
      );

      if (!mounted) return;
      setState(() {
        _compressing = false;
        _compressor = null;
      });

      if (prepared.status == VideoCompressionStatus.cancelled) {
        _showMessage('Video not saved.');
        return;
      }

      if (!prepared.canUpload) {
        // The "too long" wording belongs to the service, alongside the rule
        // that produced it.
        _showMessage(
          prepared.failureMessage ??
              'Sorry, the video could not be saved. Please try again.',
        );
        return;
      }

      // Only the file that is actually going up is read into memory.
      final finalFile = XFile(prepared.path);
      final Uint8List bytes;
      try {
        bytes = await finalFile.readAsBytes();
      } catch (_) {
        _showMessage('Could not read that video.');
        return;
      }
      if (!mounted) return;

      final mimeType = _resolveMimeType(finalFile);

      setState(() => _busy = true);
      try {
        await ref.read(sectionsRepositoryProvider).uploadSectionVideo(
              section: section,
              bytes: bytes,
              mimeType: mimeType,
              fileExtension: _resolveExtension(finalFile, mimeType),
            );
        ref.invalidate(sectionProvider(widget.sectionId));
        _showMessage('Your video has been saved.');
      } on StorageException catch (error) {
        if (error.statusCode == '413') {
          _showMessage(
            'Supabase rejected that video because it is too large. Keep it '
            'under 50 MB, or try a shorter clip.',
          );
        } else {
          _showMessage('Sorry, the video could not be saved. Please try again.');
        }
      } catch (_) {
        _showMessage('Sorry, the video could not be saved. Please try again.');
      }
    } finally {
      // Whatever happened — saved, failed, too long or cancelled — the picked
      // copy and any compressed output are of no further use.
      await _deleteQuietly(originalPath);
      final outputPath = prepared?.path;
      if (prepared != null && prepared.compressed && outputPath != null) {
        await _deleteQuietly(outputPath);
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _compressing = false;
          _compressor = null;
        });
      }
    }
  }

  void _cancelCompression() => _compressor?.cancel();

  Future<void> _removeVideo() async {
    final section = ref.read(sectionProvider(widget.sectionId)).valueOrNull;
    if (section == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your video?'),
        content: const Text(
          'This deletes the video for everyone with access to this estate. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(sectionsRepositoryProvider).deleteSectionVideo(section);
      ref.invalidate(sectionProvider(widget.sectionId));
      _showMessage('Video removed.');
    } catch (_) {
      _showMessage('Sorry, the video could not be removed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSection = ref.watch(sectionProvider(widget.sectionId));
    final videoPath = asyncSection.valueOrNull?.videoPath ?? '';
    final hasVideo = videoPath.isNotEmpty;

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.videocam_outlined,
                  size: 20, color: Colors.brown.shade400),
              const SizedBox(width: 8),
              const Text(
                'My Video to You',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // The clip sits on the right in the shape phone cameras use
              // (portrait), with the note beside it on the left. Sharing one
              // row keeps the block short, so more of the letter above stays
              // in view. A floor keeps the player watchable on a narrow
              // phone; a ceiling stops it dominating a desktop window.
              final videoWidth =
                  (constraints.maxWidth * 0.34).clamp(110.0, 180.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: _VideoNote()),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: videoWidth,
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: hasVideo
                          ? _VideoPlayerBox(
                              key: ValueKey(videoPath),
                              storagePath: videoPath,
                            )
                          : const _EmptyVideoBox(),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_compressing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      // 0 means the platform has not reported anything yet;
                      // an indeterminate bar is more honest than a stuck 0%.
                      value: _compressProgress > 0
                          ? _compressProgress.clamp(0.0, 1.0)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Making your video smaller so it fits...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _cancelCompression,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (widget.isOwner) ...[
            const SizedBox(height: 16),
            _VideoButtons(
              hasVideo: hasVideo,
              busy: _busy || _compressing,
              onRecord: () => _addVideo(ImageSource.camera),
              onChoose: () => _addVideo(ImageSource.gallery),
              onRemove: _removeVideo,
            ),
          ],
        ],
      ),
    );
  }
}

/// The explanatory note beside the "My Video to You" clip.
class _VideoNote extends StatelessWidget {
  const _VideoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEADFC3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.brown.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Say something in your own voice. Record a short message, or '
              'choose one from this device — it stays private with your '
              'estate, so your family can watch it alongside your letter. '
              'Up to 50 MB; maybe 5 minutes if sitting still.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.brown.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoButtons extends StatelessWidget {
  final bool hasVideo;
  final bool busy;
  final VoidCallback onRecord;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  const _VideoButtons({
    required this.hasVideo,
    required this.busy,
    required this.onRecord,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: busy ? null : onRecord,
          icon: const Icon(Icons.videocam_outlined, size: 18),
          label: Text(hasVideo ? 'Replace video' : 'Record video'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onChoose,
          icon: const Icon(Icons.video_library_outlined, size: 18),
          label: const Text('Choose video'),
        ),
        if (hasVideo)
          TextButton.icon(
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remove'),
          ),
      ],
    );
  }
}

class _EmptyVideoBox extends StatelessWidget {
  const _EmptyVideoBox();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6C6)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_creation_outlined,
                size: 28, color: Colors.grey.shade500),
            const SizedBox(height: 6),
            Text(
              'No video yet',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plays the stored clip inline, fetching a signed URL for its private
/// Storage object on first build. Keyed by storage path, so replacing the
/// video builds a fresh state and reloads.
class _VideoPlayerBox extends ConsumerStatefulWidget {
  final String storagePath;

  const _VideoPlayerBox({super.key, required this.storagePath});

  @override
  ConsumerState<_VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends ConsumerState<_VideoPlayerBox> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await ref
          .read(sectionsRepositoryProvider)
          .signedVideoUrl(widget.storagePath);
      if (!mounted) return;
      if (url.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
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

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_loading) {
      return const _VideoFrame(
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_failed || controller == null) {
      return const _VideoFrame(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'This video could not be played on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return _VideoFrame(
      child: GestureDetector(
        onTap: _togglePlayback,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return AnimatedOpacity(
                  opacity: value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 28),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFrame extends StatelessWidget {
  final Widget child;

  const _VideoFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// Cleanup must never surface as the failure the user sees, and the file may
/// already be gone.
Future<void> _deleteQuietly(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}

/// Normalises whatever the picker reports into a content type the bucket
/// allows. Phone cameras report nothing useful for a recorded clip, so the
/// file extension is the reliable signal.
String _resolveMimeType(XFile file) {
  final extension = _extensionOf(file.path);
  switch (extension) {
    case '.mov':
      return 'video/quicktime';
    case '.3gp':
    case '.3gpp':
      return 'video/3gpp';
    case '.webm':
      return 'video/webm';
    case '.m4v':
    case '.mp4':
      return 'video/mp4';
  }
  final reported = file.mimeType;
  if (reported != null && reported.startsWith('video/')) return reported;
  return 'video/mp4';
}

String _resolveExtension(XFile file, String mimeType) {
  const known = {'.mov', '.3gp', '.3gpp', '.webm', '.m4v', '.mp4'};
  final extension = _extensionOf(file.path);
  if (known.contains(extension)) return extension;
  if (mimeType == 'video/quicktime') return '.mov';
  return '.mp4';
}

String _extensionOf(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot == -1) return '';
  return name.substring(dot).toLowerCase();
}

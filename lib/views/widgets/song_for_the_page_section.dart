import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../repositories/sections_repository.dart';

/// A bare 11-character YouTube video ID.
final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Pulls an 11-character video ID out of a pasted link or a bare ID.
final _videoUrlPattern = RegExp(
  r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/|live/|v/)|youtu\.be/)([A-Za-z0-9_-]{11})',
);

String? _extractVideoId(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  if (_videoIdPattern.hasMatch(text)) return text;
  return _videoUrlPattern.firstMatch(text)?.group(1);
}

class SongForThePageSection extends ConsumerStatefulWidget {
  final String youtubeUrl;

  /// The section this song belongs to. Required to persist a replacement.
  final String? sectionId;

  /// Whether the current viewer may replace the song.
  final bool isOwner;

  const SongForThePageSection({
    super.key,
    required this.youtubeUrl,
    this.sectionId,
    this.isOwner = false,
  });

  @override
  ConsumerState<SongForThePageSection> createState() =>
      _SongForThePageSectionState();
}

class _SongForThePageSectionState extends ConsumerState<SongForThePageSection> {
  YoutubePlayerController? _controller;
  late String _currentUrl = widget.youtubeUrl;

  String? get _videoId => _extractVideoId(_currentUrl);

  bool get _canReplace => widget.isOwner && widget.sectionId != null;

  static YoutubePlayerParams _playerParams() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return YoutubePlayerParams(
      showFullscreenButton: true,
      showControls: true,
      mute: false,
      playsInline: true,
      // Use youtube-nocookie.com as the embed host on all platforms.
      // VEVO/music videos restrict embedding on the standard youtube.com
      // host for non-partner domains (e.g. localhost), but play fine via
      // the nocookie host. On Android this also bypasses error 152.
      origin: 'https://www.youtube-nocookie.com',
      // Spoof a desktop Chrome user-agent on Android WebView. YouTube's
      // iframe player refuses playback (error 152) when it detects the
      // default WebView UA (which contains "; wv").
      userAgent: isAndroid
          ? 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    final videoId = _videoId;
    if (videoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: _playerParams(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant SongForThePageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrl != widget.youtubeUrl) {
      _applyUrl(widget.youtubeUrl);
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  /// Swaps in [url], creating the player the first time one is set.
  void _applyUrl(String url) {
    final videoId = _extractVideoId(url);

    YoutubePlayerController? created;
    if (videoId != null) {
      if (_controller == null) {
        created = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: false,
          params: _playerParams(),
        );
      } else {
        _controller!.loadVideoById(videoId: videoId);
      }
    }

    setState(() {
      _currentUrl = url;
      if (created != null) _controller = created;
    });
  }

  void _closeDialog<T>(BuildContext dialogContext, [T? result]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(dialogContext).pop(result);
  }

  /// Prompts for a YouTube link, then stores it against the section and swaps
  /// the player over to it. Mirrors the "Add a song" dialog in My Songs.
  Future<void> _replaceSong() async {
    final sectionId = widget.sectionId;
    if (sectionId == null) return;

    final linkController = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Replace the song'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste a YouTube link to use for this page instead of the '
                'current song.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: linkController,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'YouTube link',
                  hintText: 'Paste a link or video ID',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    error!,
                    style: const TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _closeDialog(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_extractVideoId(linkController.text) == null) {
                  setDialogState(
                    () => error = 'That does not look like a YouTube link.',
                  );
                  return;
                }
                _closeDialog(dialogContext, true);
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      ),
    );

    final videoId = _extractVideoId(linkController.text);
    linkController.dispose();

    if (confirmed != true || videoId == null) return;

    final url = 'https://www.youtube.com/watch?v=$videoId';
    final previousUrl = _currentUrl;
    // Optimistically swap the player, then persist in the background.
    _applyUrl(url);

    try {
      await ref.read(sectionsRepositoryProvider).updateYoutubeUrl(
            sectionId: sectionId,
            youtubeUrl: url,
          );
      ref.invalidate(sectionProvider(sectionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song replaced.')),
        );
      }
    } catch (_) {
      _applyUrl(previousUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to replace the song.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoId = _videoId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note, color: Colors.teal, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Song for the page',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C2C2E),
                ),
              ),
            ),
            if (_canReplace)
              TextButton.icon(
                onPressed: _replaceSong,
                icon: const Icon(Icons.swap_horiz, size: 18, color: Colors.teal),
                label: const Text(
                  'Replace',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A little something for this page — tap play to listen.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (videoId != null && _controller != null)
                  Center(
                    child: SizedBox(
                      width: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: YoutubePlayer(
                            controller: _controller!,
                            keepAlive: true,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Container(
                      width: 260,
                      height: 146,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(Icons.music_off,
                            color: Colors.white54, size: 32),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

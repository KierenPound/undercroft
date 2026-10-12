import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class SongForThePageSection extends StatefulWidget {
  final String youtubeUrl;

  const SongForThePageSection({super.key, required this.youtubeUrl});

  @override
  State<SongForThePageSection> createState() => _SongForThePageSectionState();
}

class _SongForThePageSectionState extends State<SongForThePageSection> {
  YoutubePlayerController? _controller;

  String? get _videoId {
    final url = widget.youtubeUrl.trim();
    if (url.isEmpty) return null;
    final match = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    ).firstMatch(url);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    final videoId = _videoId;
    if (videoId != null) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          showControls: true,
          mute: false,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant SongForThePageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrl != widget.youtubeUrl) {
      final videoId = _videoId;
      if (videoId != null) {
        _controller?.loadVideoById(videoId: videoId);
      }
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
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
            const Text(
              'Song for the page',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C2C2E),
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

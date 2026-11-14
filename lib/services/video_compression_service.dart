import 'dart:io';

import 'package:video_compressor_plus/video_compressor_plus.dart';

import '../repositories/sections_repository.dart';

/// How preparing a "My Video to You" clip for upload ended.
enum VideoCompressionStatus {
  /// The clip was small enough to upload untouched.
  original,

  /// The clip was compressed and the result fits.
  compressed,

  /// Every attempt was still over the limit.
  tooLarge,

  /// The user cancelled while it was compressing.
  cancelled,
}

/// What one compression attempt produced.
class CompressedVideo {
  final String path;
  final int sizeBytes;

  const CompressedVideo({required this.path, required this.sizeBytes});
}

/// A single compression attempt.
///
/// A function type rather than a direct call to the plugin, so the decisions
/// around compression can be tested without a platform channel.
typedef VideoCompressor = Future<CompressedVideo?> Function(
  String sourcePath,
  VideoQuality quality,
);

/// The file to upload, or the reason there isn't one.
class VideoCompressionResult {
  final VideoCompressionStatus status;

  /// The file to upload: the original or the compressed output. Empty when
  /// there is nothing to upload.
  final String path;

  /// Whether [path] is a compressed file rather than the original.
  final bool compressed;

  /// The size of [path] in bytes.
  final int sizeBytes;

  /// Set only when [status] is [VideoCompressionStatus.tooLarge], worded for
  /// the user and ready to show as-is.
  final String? failureMessage;

  const VideoCompressionResult({
    required this.status,
    required this.path,
    required this.compressed,
    required this.sizeBytes,
    this.failureMessage,
  });

  /// Whether [path] is a file worth uploading.
  bool get canUpload =>
      status == VideoCompressionStatus.original ||
      status == VideoCompressionStatus.compressed;
}

/// Fits a picked clip inside the `estate-documents` bucket's 50 MB limit by
/// compressing it on the device.
///
/// The size thresholds are plain Dart so they can be reasoned about and tested
/// on their own; the compression itself is injected through [VideoCompressor].
class VideoCompressionService {
  /// Clips up to this size are uploaded as they are. Compressing something that
  /// already fits spends quality for nothing.
  static const int compressThresholdBytes = 25 * 1024 * 1024;

  /// The ceiling the uploaded file has to fit. Mirrors the bucket's
  /// `file_size_limit` (migration 0034), which would reject anything larger, so
  /// it is checked here rather than relied on.
  static const int maxUploadBytes = SectionsRepository.maxVideoBytes;

  /// Shown when even the lowest quality is still over [maxUploadBytes].
  static const String tooLargeMessage =
      'This video is too long to save. Try recording a shorter message.';

  /// The qualities to try, in order, for a clip of [sizeBytes].
  ///
  /// Empty means the clip can go up untouched. The second entry is only reached
  /// when the first is still over the limit, and it re-runs from the original
  /// rather than from the first output, so a poor medium encode cannot compound
  /// into something worse.
  static List<VideoQuality> qualityLadderFor(int sizeBytes) {
    if (sizeBytes <= compressThresholdBytes) return const [];
    return const [VideoQuality.MediumQuality, VideoQuality.LowQuality];
  }

  final VideoCompressor _compress;
  final int limitBytes;

  /// Set by [cancel] and read after each attempt, so a cancelled run can be told
  /// apart from one that simply failed — the two need opposite handling.
  bool _cancelled = false;

  VideoCompressionService({
    VideoCompressor compress = _compressWithPlugin,
    this.limitBytes = maxUploadBytes,
  }) : _compress = compress;

  /// The file to upload for [sourcePath], compressing it if it is over
  /// [compressThresholdBytes].
  ///
  /// [sourceSizeBytes] is what the clip measures on disk, read by the caller
  /// before it does anything with the bytes. Taking the size as an argument
  /// keeps the decision a pure function of sizes, so the thresholds and the
  /// retry order can be exercised without a filesystem or a platform channel.
  ///
  /// [onProgress] reports 0..1, starting at 0 as soon as an attempt begins, so a
  /// caller can put up a progress indicator and a cancel button. Any output that
  /// does not end up being the answer is deleted here; the file that is returned
  /// is left in place, and is the caller's to remove once it is uploaded.
  Future<VideoCompressionResult> prepare({
    required String sourcePath,
    required int sourceSizeBytes,
    void Function(double progress)? onProgress,
  }) async {
    _cancelled = false;

    final originalSize = sourceSizeBytes;
    final ladder = qualityLadderFor(originalSize);

    if (ladder.isEmpty) {
      return VideoCompressionResult(
        status: VideoCompressionStatus.original,
        path: sourcePath,
        compressed: false,
        sizeBytes: originalSize,
      );
    }

    for (final quality in ladder) {
      if (_cancelled) return _cancelledResult();

      final attempt = await _attempt(sourcePath, quality, onProgress);
      if (_cancelled) {
        // Whatever the abort left behind is not going to be used.
        if (attempt != null) await _deleteQuietly(attempt.path);
        return _cancelledResult();
      }

      // A failed attempt is neither fatal nor final: the original may still fit,
      // and a lower quality is worth a try.
      if (attempt == null) continue;

      if (attempt.sizeBytes <= limitBytes) {
        return VideoCompressionResult(
          status: VideoCompressionStatus.compressed,
          path: attempt.path,
          compressed: true,
          sizeBytes: attempt.sizeBytes,
        );
      }

      // Too big to upload, and nobody has seen it, so drop it before retrying.
      await _deleteQuietly(attempt.path);
    }

    // No compressed output was usable. The original is still a perfectly good
    // upload whenever it fits — the only reason to compress was to make one
    // that does.
    if (originalSize <= limitBytes) {
      return VideoCompressionResult(
        status: VideoCompressionStatus.original,
        path: sourcePath,
        compressed: false,
        sizeBytes: originalSize,
      );
    }

    return VideoCompressionResult(
      status: VideoCompressionStatus.tooLarge,
      path: '',
      compressed: false,
      sizeBytes: originalSize,
      failureMessage: tooLargeMessage,
    );
  }

  /// Stops the run in progress. Safe to call when nothing is running.
  Future<void> cancel() async {
    _cancelled = true;
    await VideoCompress.cancelCompression();
  }

  Future<CompressedVideo?> _attempt(
    String sourcePath,
    VideoQuality quality,
    void Function(double progress)? onProgress,
  ) async {
    // Subscribe before starting: the platform only emits while something is
    // listening.
    final subscription = onProgress == null
        ? null
        : VideoCompress.compressProgress$.subscribe((percent) {
            // The plugin reports a percentage; callers get a fraction.
            onProgress(percent / 100);
          });

    try {
      onProgress?.call(0);
      return await _compress(sourcePath, quality);
    } catch (_) {
      // One attempt failing is not the caller's problem — prepare() decides
      // what, if anything, to do next.
      return null;
    } finally {
      subscription?.unsubscribe();
    }
  }

  VideoCompressionResult _cancelledResult() => const VideoCompressionResult(
        status: VideoCompressionStatus.cancelled,
        path: '',
        compressed: false,
        sizeBytes: 0,
      );

  /// Cleanup must never surface as a failure of the operation itself, and the
  /// file may already be gone.
  static Future<void> _deleteQuietly(String path) async {
    if (path.isEmpty) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

/// The real compressor: hands the file to the platform and reports what came
/// back. Top-level so it can be the default of the injected compressor.
Future<CompressedVideo?> _compressWithPlugin(
  String sourcePath,
  VideoQuality quality,
) async {
  final info = await VideoCompress.compressVideo(
    sourcePath,
    quality: quality,
    // The caller owns the original, and still needs it if this attempt turns out
    // not to be good enough.
    deleteOrigin: false,
    includeAudio: true,
  );
  if (info == null) return null;

  final path = info.path;
  if (path == null) return null;

  // The platform reports the size of what it produced; read it from disk only
  // when it did not.
  final sizeBytes = info.filesize ?? await File(path).length();
  return CompressedVideo(path: path, sizeBytes: sizeBytes);
}

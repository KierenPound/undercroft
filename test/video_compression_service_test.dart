import 'package:flutter_test/flutter_test.dart';
import 'package:undercroft/services/video_compression_service.dart';
import 'package:video_compressor_plus/video_compressor_plus.dart';

const int _mb = 1024 * 1024;

/// Records every attempt and answers with the scripted sizes.
///
/// `null` stands for an attempt that failed, which is how a throwing or
/// unusable platform call reaches the service.
class _FakeCompressor {
  _FakeCompressor(this.outputs);

  final List<CompressedVideo?> outputs;
  final List<({String source, VideoQuality quality})> calls = [];
  int _next = 0;

  Future<CompressedVideo?> call(String sourcePath, VideoQuality quality) async {
    calls.add((source: sourcePath, quality: quality));
    if (_next >= outputs.length) return null;
    return outputs[_next++];
  }
}

CompressedVideo _output(String path, int megabytes) =>
    CompressedVideo(path: path, sizeBytes: megabytes * _mb);

void main() {
  group('qualityLadderFor', () {
    test('leaves a clip at or below the threshold alone', () {
      expect(VideoCompressionService.qualityLadderFor(1 * _mb), isEmpty);
      expect(VideoCompressionService.qualityLadderFor(25 * _mb), isEmpty);
    });

    test('compresses just over the threshold, medium before low', () {
      expect(
        VideoCompressionService.qualityLadderFor(25 * _mb + 1),
        [VideoQuality.MediumQuality, VideoQuality.LowQuality],
      );
    });
  });

  group('prepare', () {
    test('uploads the original untouched when it already fits', () async {
      final fake = _FakeCompressor(const <CompressedVideo?>[]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 20 * _mb,
      );

      expect(result.status, VideoCompressionStatus.original);
      expect(result.path, '/tmp/original.mov');
      expect(result.compressed, isFalse);
      expect(result.sizeBytes, 20 * _mb);
      expect(result.canUpload, isTrue);
      expect(fake.calls, isEmpty);
    });

    test('compresses a large clip at medium when that is enough', () async {
      final fake = _FakeCompressor([_output('/tmp/medium.mp4', 18)]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 30 * _mb,
      );

      expect(result.status, VideoCompressionStatus.compressed);
      expect(result.path, '/tmp/medium.mp4');
      expect(result.compressed, isTrue);
      expect(result.sizeBytes, 18 * _mb);
      expect(fake.calls.map((call) => call.quality),
          [VideoQuality.MediumQuality]);
      expect(fake.calls.single.source, '/tmp/original.mov');
    });

    test('retries at low, from the original, when medium is still too big',
        () async {
      final fake = _FakeCompressor([
        _output('/tmp/medium.mp4', 60),
        _output('/tmp/low.mp4', 20),
      ]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 80 * _mb,
      );

      expect(result.status, VideoCompressionStatus.compressed);
      expect(result.path, '/tmp/low.mp4');
      expect(
        fake.calls.map((call) => call.quality),
        [VideoQuality.MediumQuality, VideoQuality.LowQuality],
      );
      // The retry starts again from the original, so a poor medium encode
      // cannot compound into the low one.
      expect(
        fake.calls.map((call) => call.source),
        ['/tmp/original.mov', '/tmp/original.mov'],
      );
    });

    test('gives up with a friendly message when low is still too big',
        () async {
      final fake = _FakeCompressor([
        _output('/tmp/medium.mp4', 60),
        _output('/tmp/low.mp4', 55),
      ]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 80 * _mb,
      );

      expect(result.status, VideoCompressionStatus.tooLarge);
      expect(result.canUpload, isFalse);
      expect(result.failureMessage, VideoCompressionService.tooLargeMessage);
    });

    test('falls back to the original when compression fails but it fits',
        () async {
      final fake = _FakeCompressor(const <CompressedVideo?>[null, null]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 30 * _mb,
      );

      expect(result.status, VideoCompressionStatus.original);
      expect(result.path, '/tmp/original.mov');
      expect(result.compressed, isFalse);
      expect(result.canUpload, isTrue);
      expect(fake.calls, hasLength(2));
    });

    test('a clip exactly on the upload limit still passes as the original',
        () async {
      final fake = _FakeCompressor(const <CompressedVideo?>[]);
      final service = VideoCompressionService(compress: fake.call);

      final result = await service.prepare(
        sourcePath: '/tmp/original.mov',
        sourceSizeBytes: 50 * _mb,
      );

      expect(fake.calls, hasLength(2));
      expect(result.status, VideoCompressionStatus.original);
      expect(result.sizeBytes, 50 * _mb);
      expect(result.canUpload, isTrue);
    });
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undercroft/services/media_storage_service.dart';

void main() {
  group('MediaStorageService', () {
    test('enforces the 100 MiB client-side upload limit', () {
      expect(
        () => MediaStorageService.validateUploadSize(
          MediaStorageService.maxUploadBytes,
        ),
        returnsNormally,
      );
      expect(
        () => MediaStorageService.validateUploadSize(
          MediaStorageService.maxUploadBytes + 1,
        ),
        throwsArgumentError,
      );
    });

    test('requests a URL then PUTs bytes with the signed content type',
        () async {
      const key = 'estate-id/sections/video.mov';
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      String? putContentType;
      Uint8List? putBytes;
      final httpClient = MockClient((request) async {
        expect(request, isA<http.Request>());
        final putRequest = request;
        putContentType = putRequest.headers['content-type'];
        putBytes = putRequest.bodyBytes;
        expect(request.method, 'PUT');
        expect(request.url.path, '/bucket/$key');
        return http.Response('', 201);
      });
      addTearDown(httpClient.close);

      Map<String, dynamic>? invokedBody;
      final service = MediaStorageService(
        httpClient: httpClient,
        functionInvoker: (name, {body}) async {
          expect(name, 'r2-upload-url');
          invokedBody = body as Map<String, dynamic>;
          return const FunctionResponse(
            data: {
              'key': key,
              'uploadUrl':
                  'https://account.r2.cloudflarestorage.com/bucket/$key?sig=test',
            },
            status: 200,
          );
        },
      );

      final result = await service.uploadBytes(
        estateId: 'estate-id',
        relativePath: 'sections/video.mov',
        contentType: 'video/quicktime',
        bytes: bytes,
      );

      expect(result, key);
      expect(invokedBody, {
        'estateId': 'estate-id',
        'relativePath': 'sections/video.mov',
        'contentType': 'video/quicktime',
        'sizeBytes': bytes.length,
      });
      expect(putContentType, 'video/quicktime');
      expect(putBytes, bytes);
      service.dispose();
    });

    test('throws when the R2 PUT responds with a non-2xx status', () async {
      final httpClient = MockClient((_) async => http.Response('', 413));
      addTearDown(httpClient.close);
      final service = MediaStorageService(
        httpClient: httpClient,
        functionInvoker: (_, {body}) async => const FunctionResponse(
          data: {
            'key': 'estate-id/file.mp4',
            'uploadUrl': 'https://account.r2.cloudflarestorage.com/bucket/file',
          },
          status: 200,
        ),
      );

      await expectLater(
        service.uploadBytes(
          estateId: 'estate-id',
          relativePath: 'file.mp4',
          contentType: 'video/mp4',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(isA<MediaStorageException>()),
      );
      service.dispose();
    });

    test('reuses a signed URL and refreshes it five minutes before expiry',
        () async {
      var now = DateTime.utc(2026, 11, 19);
      var calls = 0;
      final service = MediaStorageService(
        now: () => now,
        functionInvoker: (name, {body}) async {
          expect(name, 'r2-download-url');
          calls++;
          return FunctionResponse(
            data: {'url': 'https://example.test/download/$calls'},
            status: 200,
          );
        },
      );
      addTearDown(service.dispose);

      final first = await service.getDownloadUrl('estate-id/video.mp4');
      expect(
        await service.getDownloadUrl('estate-id/video.mp4'),
        first,
      );
      expect(calls, 1);

      now = now.add(const Duration(minutes: 55, seconds: 1));
      expect(
        await service.getDownloadUrl('estate-id/video.mp4'),
        'https://example.test/download/2',
      );
      expect(calls, 2);
    });

    test('sends delete requests and invalidates estate URL cache', () async {
      var downloadCalls = 0;
      final invoked = <({String name, Object? body})>[];
      final service = MediaStorageService(
        functionInvoker: (name, {body}) async {
          invoked.add((name: name, body: body));
          if (name == 'r2-download-url') {
            downloadCalls++;
            return FunctionResponse(
              data: {'url': 'https://example.test/download/$downloadCalls'},
              status: 200,
            );
          }
          return const FunctionResponse(
            data: {'deleted': 1},
            status: 200,
          );
        },
      );
      addTearDown(service.dispose);

      await service.getDownloadUrl('estate-id/video.mp4');
      await service.deleteKeys(['estate-id/video.mp4']);
      await service.getDownloadUrl('estate-id/video.mp4');
      expect(await service.deleteAllForEstate('estate-id'), 1);
      await service.getDownloadUrl('estate-id/video.mp4');

      expect(downloadCalls, 3);
      expect(invoked[1].name, 'r2-delete');
      expect(invoked[1].body, {
        'keys': ['estate-id/video.mp4']
      });
      expect(invoked[3].name, 'r2-delete');
      expect(invoked[3].body, {
        'estateId': 'estate-id',
        'deleteAll': true,
      });
    });
  });
}

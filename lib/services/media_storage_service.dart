import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

typedef MediaFunctionInvoker = Future<FunctionResponse> Function(
  String functionName, {
  Object? body,
});

class MediaStorageException implements Exception {
  final String message;

  const MediaStorageException(this.message);

  @override
  String toString() => 'MediaStorageException: $message';
}

class MediaStorageService {
  static const int maxUploadBytes = 150 * 1024 * 1024;
  static const Duration _signedUrlTtl = Duration(seconds: 3600);
  static const Duration _signedUrlRenewMargin = Duration(minutes: 5);

  final SupabaseClient? _client;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final MediaFunctionInvoker? _functionInvoker;
  final DateTime Function() _now;

  final Map<String, ({String url, DateTime reuseUntil})> _signedUrls = {};

  MediaStorageService({
    SupabaseClient? client,
    http.Client? httpClient,
    MediaFunctionInvoker? functionInvoker,
    DateTime Function()? now,
  })  : _client = client,
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _functionInvoker = functionInvoker,
        _now = now ?? DateTime.now;

  static void validateUploadSize(int sizeBytes) {
    if (sizeBytes < 0 || sizeBytes > maxUploadBytes) {
      throw ArgumentError.value(
        sizeBytes,
        'sizeBytes',
        'Must be between 0 and $maxUploadBytes bytes.',
      );
    }
  }

  Future<String> uploadBytes({
    required String estateId,
    required String relativePath,
    required String contentType,
    required Uint8List bytes,
  }) async {
    validateUploadSize(bytes.length);

    final response = await _invokeFunction(
      'r2-upload-url',
      body: {
        'estateId': estateId,
        'relativePath': relativePath,
        'contentType': contentType,
        'sizeBytes': bytes.length,
      },
    );

    final data = response.data;
    if (data is! Map ||
        data['key'] is! String ||
        (data['key'] as String).isEmpty ||
        data['uploadUrl'] is! String ||
        (data['uploadUrl'] as String).isEmpty) {
      throw const MediaStorageException(
        'The R2 upload URL response was invalid.',
      );
    }

    final key = data['key'] as String;
    final uploadUrl = data['uploadUrl'] as String;
    final uploadResponse = await _httpClient.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw MediaStorageException(
        'R2 upload failed (HTTP ${uploadResponse.statusCode}).',
      );
    }

    _signedUrls.remove(key);
    return key;
  }

  Future<String> getDownloadUrl(String key) async {
    final cached = _signedUrls[key];
    final now = _now();
    if (cached != null && now.isBefore(cached.reuseUntil)) {
      return cached.url;
    }

    final response = await _invokeFunction(
      'r2-download-url',
      body: {'key': key},
    );

    final data = response.data;
    if (data is! Map ||
        data['url'] is! String ||
        (data['url'] as String).isEmpty) {
      throw const MediaStorageException(
        'The R2 download URL response was invalid.',
      );
    }

    final url = data['url'] as String;
    _signedUrls[key] = (
      url: url,
      reuseUntil: now.add(_signedUrlTtl - _signedUrlRenewMargin),
    );
    return url;
  }

  Future<void> deleteKeys(List<String> keys) async {
    if (keys.isEmpty) return;
    await _invokeFunction('r2-delete', body: {'keys': keys});
    for (final key in keys) {
      _signedUrls.remove(key);
    }
  }

  Future<int> deleteAllForEstate(String estateId) async {
    final response = await _invokeFunction(
      'r2-delete',
      body: {'estateId': estateId, 'deleteAll': true},
    );
    final normalizedEstateId = estateId.toLowerCase();
    _signedUrls.removeWhere(
      (key, _) => key.startsWith('$normalizedEstateId/'),
    );

    final data = response.data;
    if (data is! Map || data['deleted'] is! num) {
      throw const MediaStorageException(
        'The R2 delete response was invalid.',
      );
    }
    return (data['deleted'] as num).toInt();
  }

  Future<FunctionResponse> _invokeFunction(
    String functionName, {
    Object? body,
  }) async {
    final invoker = _functionInvoker;
    final response = invoker != null
        ? await invoker(functionName, body: body)
        : await (_client ?? Supabase.instance.client).functions.invoke(
              functionName,
              body: body,
            );

    if (response.status < 200 || response.status >= 300) {
      throw MediaStorageException(
        '$functionName failed (HTTP ${response.status}).',
      );
    }
    return response;
  }

  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

final mediaStorageServiceProvider = Provider<MediaStorageService>((ref) {
  final service = MediaStorageService();
  ref.onDispose(service.dispose);
  return service;
});

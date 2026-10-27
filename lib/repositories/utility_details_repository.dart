import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/utility_detail.dart';
import '../services/estate_service.dart';

/// Photos of the Gas meter, Electric meter and Stopcock, plus the note that
/// explains where each one is and how to read it.
///
/// Photos live in the private `estate-documents` bucket under
/// `utilities/{kind}/`, so the existing storage policies already allow reads
/// for anyone linked to the estate and writes for owners only.
class UtilityDetailsRepository {
  final SupabaseClient _client;

  UtilityDetailsRepository(this._client);

  static const String _bucket = 'estate-documents';
  static const String _table = 'utility_details';

  /// Signed URLs for the private bucket, keyed by storage path and reused
  /// until shortly before they expire.
  ///
  /// Supabase mints a fresh token on every signing call, so the URL string for
  /// the same object changes between fetches. Flutter's ImageCache is keyed by
  /// URL, so an unstable URL means every visit re-downloads the photo. Handing
  /// back the same string while it is still valid lets repeat visits come
  /// straight from the in-memory image cache.
  final Map<String, ({String url, DateTime reuseUntil})> _signedUrls = {};

  static const Duration _signedUrlTtl = Duration(seconds: 3600);

  /// Re-mint this long before expiry, so a URL already in flight never 400s.
  static const Duration _signedUrlRenewMargin = Duration(minutes: 5);

  Future<List<UtilityDetail>> fetchAll(String estateId) async {
    final data = await _client
        .from(_table)
        .select()
        .eq('estate_id', estateId);

    final details =
        (data as List).map((e) => UtilityDetail.fromJson(e)).toList();

    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      if (detail.storagePath.isEmpty) continue;
      try {
        details[i] = detail.copyWith(
          imageUrl: await _signedUrl(detail.storagePath),
        );
      } catch (_) {}
    }

    return details;
  }

  /// Saves the description for [kind], creating the row if it does not exist
  /// yet. The photo, if there is one, is left untouched.
  Future<void> saveNotes({
    required String estateId,
    required UtilityKind kind,
    required String notes,
  }) async {
    await _client.from(_table).upsert(
      {
        'estate_id': estateId,
        'kind': kind.dbValue,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'estate_id,kind',
    );
  }

  /// Replaces the photo for [kind], removing the one it supersedes so the
  /// bucket never accumulates orphans.
  Future<void> uploadImage({
    required String estateId,
    required UtilityKind kind,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final existing = await _client
        .from(_table)
        .select('storage_path')
        .eq('estate_id', estateId)
        .eq('kind', kind.dbValue)
        .maybeSingle();

    final superseded = (existing?['storage_path'] as String?) ?? '';

    final path = '$_bucket/$estateId/utilities/${kind.dbValue}/'
        '${DateTime.now().millisecondsSinceEpoch}_image.jpg';

    Future<void> writePath(String value) => _client.from(_table).upsert(
          {
            'estate_id': estateId,
            'kind': kind.dbValue,
            'storage_path': value,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'estate_id,kind',
        );

    // Point the row at the new photo *before* uploading it, so a failed upload
    // can leave a row without a file but never a file without a row. An orphan
    // is still billed for and no API can ever reach it, because the Storage API
    // works from the rows.
    await writePath(path);

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
    } catch (_) {
      try {
        await writePath(superseded);
      } catch (_) {}
      rethrow;
    }

    // Only once the replacement is safely uploaded do we drop the old photo.
    if (superseded.isNotEmpty && superseded != path) {
      try {
        await _client.storage.from(_bucket).remove([superseded]);
      } catch (_) {}
    }
  }

  /// A stable signed URL for [storagePath], reused until shortly before it
  /// expires (see [_signedUrls]).
  Future<String> _signedUrl(String storagePath) async {
    final cached = _signedUrls[storagePath];
    final now = DateTime.now();
    if (cached != null && now.isBefore(cached.reuseUntil)) {
      return cached.url;
    }

    final url = await _client.storage
        .from(_bucket)
        .createSignedUrl(storagePath, _signedUrlTtl.inSeconds);
    _signedUrls[storagePath] = (
      url: url,
      reuseUntil: now.add(_signedUrlTtl - _signedUrlRenewMargin),
    );
    return url;
  }
}

final utilityDetailsRepositoryProvider =
    Provider<UtilityDetailsRepository>((ref) {
  return UtilityDetailsRepository(Supabase.instance.client);
});

final utilityDetailsProvider =
    FutureProvider.autoDispose<List<UtilityDetail>>((ref) async {
  final repo = ref.watch(utilityDetailsRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

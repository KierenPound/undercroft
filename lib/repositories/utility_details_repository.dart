import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/media_storage_path.dart';
import '../models/utility_detail.dart';
import '../services/estate_service.dart';
import '../services/media_storage_service.dart';

/// Photos of the Gas meter, Electric meter and Stopcock, plus the note that
/// explains where each one is and how to read it.
///
/// Photos use R2 keys under `utilities/{kind}/`.
class UtilityDetailsRepository {
  final SupabaseClient _client;
  final MediaStorageService _mediaStorage;

  UtilityDetailsRepository(this._client, this._mediaStorage);

  static const String _table = 'utility_details';

  Future<List<UtilityDetail>> fetchAll(String estateId) async {
    final data = await _client.from(_table).select().eq('estate_id', estateId);

    final details =
        (data as List).map((e) => UtilityDetail.fromJson(e)).toList();

    for (var i = 0; i < details.length; i++) {
      final detail = details[i];
      if (detail.storagePath.isEmpty) continue;
      try {
        details[i] = detail.copyWith(
          imageUrl: await _mediaStorage.getDownloadUrl(detail.storagePath),
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

  /// Replaces the photo for [kind], removing the R2 object it supersedes.
  Future<void> uploadImage({
    required String estateId,
    required UtilityKind kind,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final existing = await _client
        .from(_table)
        .select('storage_path, file_size')
        .eq('estate_id', estateId)
        .eq('kind', kind.dbValue)
        .maybeSingle();

    final superseded =
        normalizeMediaStoragePath(existing?['storage_path'] as String?);
    final supersededSize =
        superseded.isEmpty ? 0 : (existing?['file_size'] as int?) ?? 0;

    final relativePath = 'utilities/${kind.dbValue}/'
        '${DateTime.now().millisecondsSinceEpoch}_image.jpg';
    final path = '$estateId/$relativePath';

    Future<void> writePath(String value, int size) =>
        _client.from(_table).upsert(
          {
            'estate_id': estateId,
            'kind': kind.dbValue,
            'storage_path': value,
            'file_size': size,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'estate_id,kind',
        );

    // Point the row at the new key first; restore the old key if upload fails.
    await writePath(path, bytes.length);

    try {
      await _mediaStorage.uploadBytes(
        estateId: estateId,
        relativePath: relativePath,
        contentType: mimeType,
        bytes: bytes,
      );
    } catch (_) {
      try {
        await writePath(superseded, supersededSize);
      } catch (_) {}
      rethrow;
    }

    // Only once the replacement is safely uploaded do we drop the old object.
    if (superseded.isNotEmpty && superseded != path) {
      try {
        await _mediaStorage.deleteKeys([superseded]);
      } catch (_) {}
    }
  }
}

final utilityDetailsRepositoryProvider =
    Provider<UtilityDetailsRepository>((ref) {
  return UtilityDetailsRepository(
    Supabase.instance.client,
    ref.watch(mediaStorageServiceProvider),
  );
});

final utilityDetailsProvider =
    FutureProvider.autoDispose<List<UtilityDetail>>((ref) async {
  final repo = ref.watch(utilityDetailsRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/about_you.dart';
import '../services/estate_service.dart';

class AboutYouRepository {
  final SupabaseClient _client;

  AboutYouRepository(this._client);

  Future<List<AboutYou>> fetchAll(String estateId) async {
    final data = await _client
        .from('about_you')
        .select()
        .eq('estate_id', estateId)
        .order('created_at', ascending: true);

    final entries = (data as List).map((e) => AboutYou.fromJson(e)).toList();

    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i];

      if (entry.passportStoragePath.isNotEmpty) {
        try {
          entry = entry.copyWith(
            passportDownloadUrl:
                await _signedUrl(entry.passportStoragePath),
          );
        } catch (_) {}
      }

      if (entry.licenceStoragePath.isNotEmpty) {
        try {
          entry = entry.copyWith(
            licenceDownloadUrl: await _signedUrl(entry.licenceStoragePath),
          );
        } catch (_) {}
      }

      entries[i] = entry;
    }

    return entries;
  }

  Future<AboutYou> insert(AboutYou entry) async {
    final data = await _client
        .from('about_you')
        .insert(entry.toInsertJson())
        .select()
        .single();
    return AboutYou.fromJson(data);
  }

  Future<AboutYou> update(AboutYou entry) async {
    final data = await _client
        .from('about_you')
        .update(entry.toUpdateJson())
        .eq('about_you_id', entry.aboutYouId)
        .select()
        .single();
    return AboutYou.fromJson(data);
  }

  /// Removes the record and any scanned images it owns.
  Future<void> delete(AboutYou entry) async {
    await _deleteObjects([
      entry.passportStoragePath,
      entry.licenceStoragePath,
    ]);
    await _client.from('about_you').delete().eq('about_you_id', entry.aboutYouId);
  }

  /// Uploads a replacement scan into the given slot.
  ///
  /// The row is updated with the new path *before* the bytes go up, and rolled
  /// back if the upload fails — the same ordering used for section
  /// attachments, so the bucket can never end up holding a file that no row
  /// points at. The previous object is removed once the new one lands.
  Future<AboutYou> uploadDocument({
    required AboutYou entry,
    required AboutYouDocument doc,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final previousPath = entry.storagePathFor(doc);
    final path = 'estate-documents/${entry.estateId}/about-you/'
        '${entry.aboutYouId}/${doc.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final downloadUrl =
        _client.storage.from('estate-documents').getPublicUrl(path);

    final updated = await update(entry.withDocument(
      doc,
      storagePath: path,
      downloadUrl: downloadUrl,
      fileSize: bytes.length,
    ));

    try {
      await _client.storage.from('estate-documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
    } catch (_) {
      try {
        await update(entry);
      } catch (_) {}
      rethrow;
    }

    if (previousPath.isNotEmpty && previousPath != path) {
      await _deleteObjects([previousPath]);
    }

    final signedUrl = await _signedUrl(path);
    return doc == AboutYouDocument.passport
        ? updated.copyWith(passportDownloadUrl: signedUrl)
        : updated.copyWith(licenceDownloadUrl: signedUrl);
  }

  /// Clears a document slot and removes the stored object.
  Future<AboutYou> removeDocument({
    required AboutYou entry,
    required AboutYouDocument doc,
  }) async {
    final path = entry.storagePathFor(doc);
    final updated = await update(entry.withoutDocument(doc));
    await _deleteObjects([path]);
    return updated;
  }

  Future<void> _deleteObjects(List<String> paths) async {
    final targets = paths.where((p) => p.isNotEmpty).toList();
    if (targets.isEmpty) return;
    try {
      await _client.storage.from('estate-documents').remove(targets);
    } catch (_) {}
  }

  Future<String> _signedUrl(String storagePath) {
    return _client.storage
        .from('estate-documents')
        .createSignedUrl(storagePath, 3600);
  }
}

final aboutYouRepositoryProvider = Provider<AboutYouRepository>((ref) {
  return AboutYouRepository(Supabase.instance.client);
});

final aboutYouListProvider =
    FutureProvider.autoDispose<List<AboutYou>>((ref) async {
  final repo = ref.watch(aboutYouRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

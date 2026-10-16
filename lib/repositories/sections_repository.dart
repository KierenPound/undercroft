import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/seed_data.dart';
import '../models/attachment.dart';
import '../models/checklist_item.dart';
import '../models/prep_section.dart';
import '../services/estate_service.dart';

class SectionsRepository {
  final SupabaseClient _client;

  SectionsRepository(this._client);

  /// Signed URLs for the private `estate-documents` bucket, keyed by storage
  /// path, with the moment each one stops being reused.
  ///
  /// Supabase mints a fresh token on every signing call, so the URL string for
  /// the same object changes between fetches. Flutter's ImageCache is keyed by
  /// URL, so an unstable URL means every visit to a section re-downloads the
  /// photo. Handing back the same string while it is still valid lets repeat
  /// visits come straight from the in-memory image cache.
  final Map<String, ({String url, DateTime reuseUntil})> _signedUrls = {};

  static const Duration _signedUrlTtl = Duration(seconds: 3600);

  /// Re-mint this long before expiry, so a URL already in flight never 400s.
  static const Duration _signedUrlRenewMargin = Duration(minutes: 5);

  Future<PrepSection> getOrCreateSection({
    required String estateId,
    required String title,
    int orderIndex = 0,
    bool isStandard = false,
    String youtubeUrl = '',
  }) async {
    final existing = await _client
        .from('sections')
        .select()
        .eq('estate_id', estateId)
        .eq('title', title)
        .maybeSingle();

    if (existing != null) {
      final currentYoutube = existing['youtube_url'] as String? ?? '';
      final currentOrder = existing['order_index'] as int? ?? 0;
      if (currentYoutube != youtubeUrl || currentOrder != orderIndex) {
        // Executors can read sections but not write them (RLS:
        // sections_owner_update), so for them this update matches no rows.
        // Read the result back locally instead of asking PostgREST to coerce
        // the updated row — an empty result set raises
        // "Cannot coerce the result to a single JSON object".
        await _client
            .from('sections')
            .update({
              'youtube_url': youtubeUrl,
              'order_index': orderIndex,
            })
            .eq('id', existing['id']);

        return PrepSection.fromJson({
          ...existing,
          'youtube_url': youtubeUrl,
          'order_index': orderIndex,
        });
      }
      return PrepSection.fromJson(existing);
    }

    final data = await _client
        .from('sections')
        .insert({
          'estate_id': estateId,
          'title': title,
          'order_index': orderIndex,
          'is_standard': isStandard,
          'youtube_url': youtubeUrl,
        })
        .select()
        .single();

    return PrepSection.fromJson(data);
  }

  Future<PrepSection> updateSection(PrepSection section) async {
    final data = await _client
        .from('sections')
        .update(section.toUpdateJson())
        .eq('id', section.id)
        .select()
        .single();
    return PrepSection.fromJson(data);
  }

  Future<PrepSection> fetchSection(String sectionId) async {
    final data =
        await _client.from('sections').select().eq('id', sectionId).single();
    return PrepSection.fromJson(data);
  }

  Future<List<ChecklistItem>> fetchChecklistItems(String sectionId) async {
    final data = await _client
        .from('checklist_items')
        .select()
        .eq('section_id', sectionId)
        .order('order_index', ascending: true);

    return (data as List).map((e) => ChecklistItem.fromJson(e)).toList();
  }

  Future<ChecklistItem> addChecklistItem({
    required String sectionId,
    required String text,
    required int orderIndex,
  }) async {
    final data = await _client
        .from('checklist_items')
        .insert({
          'section_id': sectionId,
          'text': text,
          'is_completed': false,
          'order_index': orderIndex,
        })
        .select()
        .single();
    return ChecklistItem.fromJson(data);
  }

  Future<ChecklistItem> updateChecklistItem(ChecklistItem item) async {
    final data = await _client
        .from('checklist_items')
        .update(item.toUpdateJson())
        .eq('id', item.id)
        .select()
        .single();
    return ChecklistItem.fromJson(data);
  }

  Future<void> deleteChecklistItem(String id) async {
    await _client.from('checklist_items').delete().eq('id', id);
  }

  Future<List<Attachment>> fetchAttachments(String sectionId) async {
    final data = await _client
        .from('attachments')
        .select()
        .eq('section_id', sectionId)
        .order('created_at', ascending: true);

    final attachments =
        (data as List).map((e) => Attachment.fromJson(e)).toList();

    for (var i = 0; i < attachments.length; i++) {
      final a = attachments[i];
      if (a.storagePath.isNotEmpty) {
        try {
          attachments[i] =
              a.copyWith(downloadUrl: await _signedUrl(a.storagePath));
        } catch (_) {}
      }
    }

    return attachments;
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
        .from('estate-documents')
        .createSignedUrl(storagePath, _signedUrlTtl.inSeconds);
    _signedUrls[storagePath] = (
      url: url,
      reuseUntil: now.add(_signedUrlTtl - _signedUrlRenewMargin),
    );
    return url;
  }

  Future<Attachment> uploadAttachment({
    required String sectionId,
    required String estateId,
    required String fileName,
    required AttachmentType type,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final path =
        'estate-documents/$estateId/sections/$sectionId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('estate-documents').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    final downloadUrl =
        _client.storage.from('estate-documents').getPublicUrl(path);

    final data = await _client
        .from('attachments')
        .insert({
          'section_id': sectionId,
          'file_name': fileName,
          'type': type.name,
          'storage_path': path,
          'download_url': downloadUrl,
          'file_size': bytes.length,
        })
        .select()
        .single();

    return Attachment.fromJson(data);
  }

  Future<void> deleteAttachment(Attachment attachment) async {
    if (attachment.storagePath.isNotEmpty) {
      try {
        await _client.storage
            .from('estate-documents')
            .remove([attachment.storagePath]);
      } catch (_) {}
    }
    await _client.from('attachments').delete().eq('id', attachment.id);
  }

  /// Seeds a freshly created estate with the default sections and their
  /// starter checklist items.
  ///
  /// Safe to call multiple times — a section's checklist items are only
  /// inserted if that section currently has none, so existing user data is
  /// never overwritten.
  Future<void> seedDefaults(String estateId) async {
    for (final section in defaultSections) {
      final created = await getOrCreateSection(
        estateId: estateId,
        title: section.title,
        orderIndex: section.orderIndex,
        isStandard: true,
        youtubeUrl: section.youtubeUrl,
      );

      final existing = await fetchChecklistItems(created.id);
      if (existing.isNotEmpty) continue;

      for (var i = 0; i < section.checklistItems.length; i++) {
        await addChecklistItem(
          sectionId: created.id,
          text: section.checklistItems[i],
          orderIndex: i,
        );
      }
    }
  }
}

final sectionsRepositoryProvider = Provider<SectionsRepository>((ref) {
  return SectionsRepository(Supabase.instance.client);
});

final sectionProvider = FutureProvider.autoDispose
    .family<PrepSection, String>((ref, sectionId) async {
  final repo = ref.watch(sectionsRepositoryProvider);
  return repo.fetchSection(sectionId);
});

final wtnSectionProvider = FutureProvider.autoDispose
    .family<PrepSection, String>((ref, estateId) async {
  final repo = ref.watch(sectionsRepositoryProvider);
  return repo.getOrCreateSection(
    estateId: estateId,
    title: 'Who to Notify',
    orderIndex: 3,
    isStandard: true,
    youtubeUrl: 'https://www.youtube.com/watch?v=tuyBCSYTs5A',
  );
});

class SectionConfig {
  final String title;
  final int orderIndex;
  final String youtubeUrl;

  const SectionConfig({
    required this.title,
    required this.orderIndex,
    this.youtubeUrl = '',
  });
}

/// All known sections with their configs. Used both by the home dashboard
/// grid and by the `/section/:title` route so the section can be looked up
/// by title (survives browser refreshes, unlike `go_router`'s `extra`).
const List<SectionConfig> allSectionConfigs = [
  SectionConfig(
    title: 'My Letter to You',
    orderIndex: 0,
  ),
  SectionConfig(
    title: 'What to Do First',
    orderIndex: 1,
    youtubeUrl: 'https://www.youtube.com/watch?v=b4ZypVnbYHM',
  ),
  SectionConfig(
    title: 'Legal Documents',
    orderIndex: 2,
    youtubeUrl: 'https://www.youtube.com/watch?v=GaZp4fJVHmQ',
  ),
  SectionConfig(
    title: 'Who to Notify',
    orderIndex: 3,
    youtubeUrl: 'https://www.youtube.com/watch?v=tuyBCSYTs5A',
  ),
  SectionConfig(
    title: 'Running the Houses',
    orderIndex: 4,
    youtubeUrl: 'https://www.youtube.com/watch?v=jqpAgMxhx30',
  ),
  SectionConfig(
    title: 'Funeral Arrangements',
    orderIndex: 5,
    youtubeUrl: 'https://www.youtube.com/watch?v=02T6xLNXEE0',
  ),
  SectionConfig(
    title: 'Cars',
    orderIndex: 6,
    youtubeUrl: 'https://www.youtube.com/watch?v=rbgiJu7YFvo',
  ),
  SectionConfig(
    title: 'Confirmation',
    orderIndex: 7,
    youtubeUrl: 'https://www.youtube.com/watch?v=lHzhH_tJ7ak',
  ),
  SectionConfig(
    title: 'My Songs',
    orderIndex: 8,
  ),
];

SectionConfig? sectionConfigByTitle(String title) =>
    allSectionConfigs.where((c) => c.title == title).firstOrNull;

final sectionByTitleProvider = FutureProvider.autoDispose
    .family<PrepSection, SectionConfig>((ref, config) async {
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) {
    throw Exception('No estate found');
  }
  final repo = ref.watch(sectionsRepositoryProvider);
  return repo.getOrCreateSection(
    estateId: estateId,
    title: config.title,
    orderIndex: config.orderIndex,
    isStandard: true,
    youtubeUrl: config.youtubeUrl,
  );
});

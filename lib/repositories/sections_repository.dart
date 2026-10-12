import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attachment.dart';
import '../models/checklist_item.dart';
import '../models/prep_section.dart';
import '../services/estate_service.dart';

class SectionsRepository {
  final SupabaseClient _client;

  SectionsRepository(this._client);

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
        final updated = await _client
            .from('sections')
            .update({
              'youtube_url': youtubeUrl,
              'order_index': orderIndex,
            })
            .eq('id', existing['id'])
            .select()
            .single();
        return PrepSection.fromJson(updated);
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
          final signedUrl = await _client.storage
              .from('estate-documents')
              .createSignedUrl(a.storagePath, 3600);
          attachments[i] = a.copyWith(downloadUrl: signedUrl);
        } catch (_) {}
      }
    }

    return attachments;
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
    orderIndex: 2,
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

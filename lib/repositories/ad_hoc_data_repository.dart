import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ad_hoc_data.dart';
import '../services/estate_service.dart';

class AdHocDataRepository {
  final SupabaseClient _client;

  AdHocDataRepository(this._client);

  Future<List<AdHocData>> fetchAll(String estateId) async {
    final data = await _client
        .from('ad_hoc_data')
        .select()
        .eq('estate_id', estateId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => AdHocData.fromJson(e)).toList();
  }

  Future<AdHocData> insert(AdHocData entry) async {
    final data = await _client
        .from('ad_hoc_data')
        .insert(entry.toInsertJson())
        .select()
        .single();
    return AdHocData.fromJson(data);
  }

  Future<AdHocData> update(AdHocData entry) async {
    final data = await _client
        .from('ad_hoc_data')
        .update(entry.toUpdateJson())
        .eq('ad_hoc_data_id', entry.adHocDataId)
        .select()
        .single();
    return AdHocData.fromJson(data);
  }

  Future<void> delete(String adHocDataId) async {
    await _client.from('ad_hoc_data').delete().eq('ad_hoc_data_id', adHocDataId);
  }
}

final adHocDataRepositoryProvider = Provider<AdHocDataRepository>((ref) {
  return AdHocDataRepository(Supabase.instance.client);
});

final adHocDataListProvider =
    FutureProvider.autoDispose<List<AdHocData>>((ref) async {
  final repo = ref.watch(adHocDataRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

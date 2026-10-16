import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/funeral_arrangement.dart';
import '../services/estate_service.dart';

class FuneralArrangementsRepository {
  final SupabaseClient _client;

  FuneralArrangementsRepository(this._client);

  Future<List<FuneralArrangement>> fetchAll(String estateId) async {
    final data = await _client
        .from('funeral_arrangements')
        .select()
        .eq('estate_id', estateId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => FuneralArrangement.fromJson(e))
        .toList();
  }

  Future<FuneralArrangement> insert(FuneralArrangement entry) async {
    final data = await _client
        .from('funeral_arrangements')
        .insert(entry.toInsertJson())
        .select()
        .single();
    return FuneralArrangement.fromJson(data);
  }

  Future<FuneralArrangement> update(FuneralArrangement entry) async {
    final data = await _client
        .from('funeral_arrangements')
        .update(entry.toUpdateJson())
        .eq('funeral_arrangement_id', entry.funeralArrangementId)
        .select()
        .single();
    return FuneralArrangement.fromJson(data);
  }

  Future<void> delete(String funeralArrangementId) async {
    await _client
        .from('funeral_arrangements')
        .delete()
        .eq('funeral_arrangement_id', funeralArrangementId);
  }
}

final funeralArrangementsRepositoryProvider =
    Provider<FuneralArrangementsRepository>((ref) {
  return FuneralArrangementsRepository(Supabase.instance.client);
});

final funeralArrangementsListProvider =
    FutureProvider.autoDispose<List<FuneralArrangement>>((ref) async {
  final repo = ref.watch(funeralArrangementsRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

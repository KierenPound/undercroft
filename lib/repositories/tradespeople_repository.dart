import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/tradesperson.dart';
import '../services/estate_service.dart';

class TradespeopleRepository {
  final SupabaseClient _client;

  TradespeopleRepository(this._client);

  Future<List<Tradesperson>> fetchAll(String estateId) async {
    final data = await _client
        .from('tradespeople')
        .select()
        .eq('estate_id', estateId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => Tradesperson.fromJson(e)).toList();
  }

  Future<Tradesperson> insert(Tradesperson tradesperson) async {
    final data = await _client
        .from('tradespeople')
        .insert(tradesperson.toInsertJson())
        .select()
        .single();
    return Tradesperson.fromJson(data);
  }

  Future<Tradesperson> update(Tradesperson tradesperson) async {
    final data = await _client
        .from('tradespeople')
        .update(tradesperson.toUpdateJson())
        .eq('tradesperson_id', tradesperson.tradespersonId)
        .select()
        .single();
    return Tradesperson.fromJson(data);
  }

  Future<void> delete(String tradespersonId) async {
    await _client
        .from('tradespeople')
        .delete()
        .eq('tradesperson_id', tradespersonId);
  }
}

final tradespeopleRepositoryProvider = Provider<TradespeopleRepository>((ref) {
  return TradespeopleRepository(Supabase.instance.client);
});

final tradespeopleListProvider =
    FutureProvider.autoDispose<List<Tradesperson>>((ref) async {
  final repo = ref.watch(tradespeopleRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

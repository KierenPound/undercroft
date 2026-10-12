import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notify_account_details.dart';
import '../models/who_to_notify.dart';

class WhoToNotifyRepository {
  final SupabaseClient _client;

  WhoToNotifyRepository(this._client);

  Future<List<WhoToNotify>> fetchAll(String estateId) async {
    final data = await _client
        .from('who_to_notify')
        .select()
        .eq('estate_id', estateId)
        .order('company_name', ascending: true);

    return (data as List).map((e) => WhoToNotify.fromJson(e)).toList();
  }

  Future<WhoToNotify> fetchById(String whoToNotifyId) async {
    final data = await _client
        .from('who_to_notify')
        .select()
        .eq('who_to_notify_id', whoToNotifyId)
        .single();
    return WhoToNotify.fromJson(data);
  }

  Future<WhoToNotify> insert(WhoToNotify entry) async {
    final data = await _client
        .from('who_to_notify')
        .insert(entry.toInsertJson())
        .select()
        .single();
    return WhoToNotify.fromJson(data);
  }

  Future<WhoToNotify> update(WhoToNotify entry) async {
    final data = await _client
        .from('who_to_notify')
        .update(entry.toUpdateJson())
        .eq('who_to_notify_id', entry.whoToNotifyId)
        .select()
        .single();
    return WhoToNotify.fromJson(data);
  }

  Future<void> delete(String whoToNotifyId) async {
    await _client
        .from('who_to_notify')
        .delete()
        .eq('who_to_notify_id', whoToNotifyId);
  }

  Future<List<NotifyAccountDetails>> fetchAccountDetails(
      String whoToNotifyId) async {
    final data = await _client
        .from('notify_account_details')
        .select()
        .eq('who_to_notify_id', whoToNotifyId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => NotifyAccountDetails.fromJson(e)).toList();
  }

  Future<NotifyAccountDetails> insertAccountDetails(
      NotifyAccountDetails details) async {
    final data = await _client
        .from('notify_account_details')
        .insert(details.toInsertJson())
        .select()
        .single();
    return NotifyAccountDetails.fromJson(data);
  }

  Future<NotifyAccountDetails> updateAccountDetails(
      NotifyAccountDetails details) async {
    final data = await _client
        .from('notify_account_details')
        .update(details.toUpdateJson())
        .eq('notify_account_details_id', details.notifyAccountDetailsId)
        .select()
        .single();
    return NotifyAccountDetails.fromJson(data);
  }

  Future<void> deleteAccountDetails(String notifyAccountDetailsId) async {
    await _client
        .from('notify_account_details')
        .delete()
        .eq('notify_account_details_id', notifyAccountDetailsId);
  }
}

final whoToNotifyRepositoryProvider = Provider<WhoToNotifyRepository>((ref) {
  return WhoToNotifyRepository(Supabase.instance.client);
});

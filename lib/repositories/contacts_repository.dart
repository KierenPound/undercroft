import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact.dart';
import '../services/estate_service.dart';

class ContactsRepository {
  final SupabaseClient _client;

  ContactsRepository(this._client);

  Future<List<Contact>> fetchAll(String estateId) async {
    final data = await _client
        .from('contacts')
        .select()
        .eq('estate_id', estateId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => Contact.fromJson(e)).toList();
  }

  Future<Contact> insert(Contact contact) async {
    final data = await _client
        .from('contacts')
        .insert(contact.toInsertJson())
        .select()
        .single();
    return Contact.fromJson(data);
  }

  Future<Contact> update(Contact contact) async {
    final data = await _client
        .from('contacts')
        .update(contact.toUpdateJson())
        .eq('contact_id', contact.contactId)
        .select()
        .single();
    return Contact.fromJson(data);
  }

  Future<void> delete(String contactId) async {
    await _client.from('contacts').delete().eq('contact_id', contactId);
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(Supabase.instance.client);
});

final contactsListProvider =
    FutureProvider.autoDispose<List<Contact>>((ref) async {
  final repo = ref.watch(contactsRepositoryProvider);
  final estateId = await ref.watch(estateIdProvider.future);
  if (estateId.isEmpty) return [];
  return repo.fetchAll(estateId);
});

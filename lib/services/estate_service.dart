import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final estateIdProvider = FutureProvider<String>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return '';

  try {
    final row = await client
        .from('estate_access')
        .select('estate_id')
        .eq('user_id', user.id)
        .eq('status', 'accepted')
        .maybeSingle();

    if (row == null) return '';
    return row['estate_id'] as String;
  } catch (_) {
    return '';
  }
});

final hasEstateProvider = FutureProvider<bool>((ref) async {
  final estateId = await ref.watch(estateIdProvider.future);
  return estateId.isNotEmpty;
});

final estateRoleProvider = FutureProvider<String>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return '';

  try {
    final row = await client
        .from('estate_access')
        .select('role')
        .eq('user_id', user.id)
        .eq('status', 'accepted')
        .maybeSingle();

    if (row == null) return '';
    return row['role'] as String? ?? '';
  } catch (_) {
    return '';
  }
});

final isOwnerProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(estateRoleProvider.future);
  return role == 'owner';
});

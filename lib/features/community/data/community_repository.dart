import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityRepository {
  const CommunityRepository(this.db);

  final SupabaseClient? db;

  SupabaseClient get _client {
    final client = db;
    if (client == null) {
      throw StateError('هذه العملية تتطلب اتصالاً بخادم MARSA.');
    }
    return client;
  }

  String get uid =>
      _client.auth.currentUser?.id ?? (throw StateError('Sign in required'));

  Future<List<Map<String, dynamic>>> favorites() async {
    if (db == null) return const [];

    return (await _client
            .from('favorites')
            .select(
              'listing_id,listings(id,title_ar,status,sale_type,currency_code,'
              'listing_images(storage_path),direct_sale_details(unit_price))',
            )
            .eq('user_id', uid))
        .cast<Map<String, dynamic>>();
  }

  Future<bool> isFavorite(String listing) async {
    if (db == null) return false;

    return await _client
            .from('favorites')
            .select('listing_id')
            .eq('user_id', uid)
            .eq('listing_id', listing)
            .maybeSingle() !=
        null;
  }

  Future<void> toggleFavorite(String listing, bool currentlySaved) async {
    final client = _client;
    final userId = uid;

    if (currentlySaved) {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('listing_id', listing);
    } else {
      await client.from('favorites').insert({
        'user_id': userId,
        'listing_id': listing,
      });
    }
  }

  Future<void> review(
    String order,
    String seller,
    int stars,
    String comment,
  ) async {
    await _client.from('reviews').insert({
      'order_id': order,
      'buyer_id': uid,
      'seller_id': seller,
      'rating': stars,
      'comment': comment,
    });
  }

  Future<void> report(String target, String id, String reason) async {
    await _client.from('reports').insert({
      'reporter_id': uid,
      'target_type': target,
      'target_id': id,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    if (db == null) return const [];

    return (await _client
            .from('notifications')
            .select('id,type,payload,read_at,created_at')
            .eq('recipient_id', uid)
            .order('created_at', ascending: false)
            .limit(100))
        .cast<Map<String, dynamic>>();
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId);
  }
}

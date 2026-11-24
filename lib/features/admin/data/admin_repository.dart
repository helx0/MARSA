import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  const AdminRepository(this.db);

  final SupabaseClient? db;

  SupabaseClient get _client {
    final client = db;
    if (client == null) {
      throw StateError('إدارة النظام تتطلب اتصالاً بخادم MARSA.');
    }
    return client;
  }

  Future<bool> isAdmin() async {
    if (db == null) return false;
    return await _client.rpc('is_admin') == true;
  }

  Future<List<Map<String, dynamic>>> pendingSellers() async {
    if (db == null) return const [];
    return (await _client
            .from('seller_profiles')
            .select(
              'user_id,business_name,description,verification_status',
            )
            .eq('verification_status', 'PENDING'))
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> pendingListings() async {
    if (db == null) return const [];
    return (await _client
            .from('listings')
            .select('id,title_ar,seller_id,sale_type,status')
            .eq('status', 'PENDING_REVIEW'))
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> reports() async {
    if (db == null) return const [];
    return (await _client
            .from('reports')
            .select('id,target_type,target_id,reason,status,created_at')
            .eq('status', 'OPEN'))
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> audit() async {
    if (db == null) return const [];
    return (await _client
            .from('audit_logs')
            .select('action,entity_type,created_at')
            .order('created_at', ascending: false)
            .limit(80))
        .cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> referenceRecords(String type) async {
    if (db == null) return const [];
    return (await _client
            .from(type == 'CATEGORY' ? 'seafood_categories' : 'aden_areas')
            .select('id,name_ar,name_en,sort_order,is_active')
            .order('sort_order'))
        .cast<Map<String, dynamic>>();
  }

  Future<void> seller(
    String uid,
    String status, {
    String reason = '',
  }) async {
    await _client.rpc(
      'admin_approve_seller',
      params: {'p_user': uid, 'p_status': status, 'p_reason': reason},
    );
  }

  Future<void> listing(String id, String status) async {
    await _client.rpc(
      'admin_moderate_listing',
      params: {'p_listing': id, 'p_status': status},
    );
  }

  Future<void> report(String id, String status, String resolution) async {
    await _client.rpc(
      'admin_resolve_report',
      params: {
        'p_report': id,
        'p_status': status,
        'p_resolution': resolution,
      },
    );
  }

  Future<void> disputeOrder(String id) async {
    await _client.rpc(
      'transition_order',
      params: {
        'p_order': id,
        'p_status': 'DISPUTED',
        'p_note': 'Admin dispute review',
      },
    );
  }

  Future<void> account(String id, String status) async {
    await _client.rpc(
      'admin_account_status',
      params: {'p_user': id, 'p_status': status},
    );
  }

  Future<void> reference({
    required String type,
    String? id,
    required String arabic,
    required String english,
    required bool active,
    int order = 0,
  }) async {
    await _client.rpc(
      'admin_reference',
      params: {
        'p_kind': type,
        'p_id': id,
        'p_ar': arabic,
        'p_en': english,
        'p_active': active,
        'p_sort': order,
      },
    );
  }
}

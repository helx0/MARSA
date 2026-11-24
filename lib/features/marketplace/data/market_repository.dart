import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const listingSelect = 'id,seller_id,sale_type,category_id,title_ar,title_en,description,condition_note,area_id,quantity_available,unit,currency_code,status,created_at,published_at,seafood_categories(name_ar,name_en),aden_areas(name_ar,name_en),seller_profiles(business_name,verification_status),listing_images(storage_path,sort_order),direct_sale_details(unit_price,minimum_order_quantity),auctions(start_price,current_price,minimum_increment,reserve_price,starts_at,ends_at,status,winner_deadline)';

class MarketRepository {
  const MarketRepository(this.db);
  final SupabaseClient? db;

  Future<List<Map<String, dynamic>>> areas() async {
    if (db == null) {
      return [
        {'id': 'a1', 'name_ar': 'كريتر (صيرة)', 'name_en': 'Crater'},
        {'id': 'a2', 'name_ar': 'المعلا', 'name_en': 'Al Mualla'},
        {'id': 'a3', 'name_ar': 'خور مكسر', 'name_en': 'Khormaksar'},
        {'id': 'a4', 'name_ar': 'المنصورة', 'name_en': 'Al Mansoura'},
        {'id': 'a5', 'name_ar': 'البريقة', 'name_en': 'Al Buraiqa'},
      ];
    }
    return (await db!.from('aden_areas').select('id,name_ar,name_en,sort_order').eq('is_active', true).order('sort_order')).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> categories() async {
    if (db == null) {
      return [
        {'id': 'c1', 'name_ar': 'ديرك (كنعد)', 'name_en': 'King Mackerel'},
        {'id': 'c2', 'name_ar': 'روبيان (جمبري)', 'name_en': 'Shrimp'},
        {'id': 'c3', 'name_ar': 'ثمد (تونة)', 'name_en': 'Yellowfin Tuna'},
        {'id': 'c4', 'name_ar': 'سخلة', 'name_en': 'Emperor'},
        {'id': 'c5', 'name_ar': 'حبار (بغوي)', 'name_en': 'Squid'},
      ];
    }
    return (await db!.from('seafood_categories').select('id,name_ar,name_en,sort_order').eq('is_active', true).order('sort_order')).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> listings({
    String search = '', String? category, String? area, String? mode,
    String? currency, num? minPrice, num? maxPrice,
    bool onlyAvailable = true, int page = 0, String sort = 'newest',
  }) async {
    if (db == null) {
      // Return highly "Strong" mock data for UI demo
      return [
        {
          'id': 'mock-1', 'sale_type': 'DIRECT', 'title_ar': 'ديرك (كنعد) بلدي طازج - صيد الفجر',
          'quantity_available': 30.0, 'unit': 'kg', 'currency_code': 'YER', 'status': 'ACTIVE',
          'aden_areas': {'name_ar': 'كريتر (صيرة)'}, 'direct_sale_details': {'unit_price': 14000},
          'listing_images': [], 'seller_profiles': {'business_name': 'مسمكة صيرة النموذجية', 'verification_status': 'APPROVED'}
        },
        {
          'id': 'mock-2', 'sale_type': 'AUCTION', 'title_ar': 'مزاد: روبيان (جمبري) جامبو ملكي - 5 صناديق',
          'quantity_available': 5.0, 'unit': 'box', 'currency_code': 'YER', 'status': 'ACTIVE',
          'aden_areas': {'name_ar': 'خور مكسر'}, 'auctions': {'current_price': 38000, 'ends_at': DateTime.now().add(const Duration(hours: 4)).toIso8601String()},
          'listing_images': [], 'seller_profiles': {'business_name': 'البحار العدني', 'verification_status': 'APPROVED'}
        },
        {
          'id': 'mock-3', 'sale_type': 'DIRECT', 'title_ar': 'ثمد (تونة) طازج مقطع شرائح جاهزة',
          'quantity_available': 15.0, 'unit': 'kg', 'currency_code': 'YER', 'status': 'ACTIVE',
          'aden_areas': {'name_ar': 'المعلا'}, 'direct_sale_details': {'unit_price': 8500},
          'listing_images': [], 'seller_profiles': {'business_name': 'أسماك المعلا', 'verification_status': 'APPROVED'}
        },
        {
          'id': 'mock-4', 'sale_type': 'DIRECT', 'title_ar': 'سخلة بلدي فاخرة - صيد البريقة',
          'quantity_available': 10.0, 'unit': 'kg', 'currency_code': 'YER', 'status': 'ACTIVE',
          'aden_areas': {'name_ar': 'البريقة'}, 'direct_sale_details': {'unit_price': 11000},
          'listing_images': [], 'seller_profiles': {'business_name': 'بحر البريقة', 'verification_status': 'APPROVED'}
        },
        {
          'id': 'mock-5', 'sale_type': 'AUCTION', 'title_ar': 'مزاد: حبار (بغوي) أحجام كبيرة - كمية محدودة',
          'quantity_available': 8.0, 'unit': 'kg', 'currency_code': 'YER', 'status': 'ACTIVE',
          'aden_areas': {'name_ar': 'التواهي'}, 'auctions': {'current_price': 6000, 'ends_at': DateTime.now().add(const Duration(hours: 12)).toIso8601String()},
          'listing_images': [], 'seller_profiles': {'business_name': 'صياد التواهي', 'verification_status': 'APPROVED'}
        },
      ];
    }
    final ids = (await db!.rpc('search_marketplace', params: {
      'p_query': search.trim(), 'p_category': category, 'p_area': area, 'p_mode': mode,
      'p_currency': currency, 'p_min_price': minPrice, 'p_max_price': maxPrice,
      'p_only_available': onlyAvailable, 'p_page': page, 'p_sort': sort,
    }) as List).map((r) => (r as Map)['id'].toString()).toList();
    if (ids.isEmpty) return [];
    final rows = (await db!.from('listings').select(listingSelect).inFilter('id', ids)).cast<Map<String, dynamic>>();
    final byId = {for (final row in rows) row['id'].toString(): row};
    return [for (final id in ids) if (byId.containsKey(id)) byId[id]!];
  }

  Future<Map<String, dynamic>> listing(String id) async {
    if (db == null) {
      final all = await listings();
      return all.firstWhere((e) => e['id'] == id, orElse: () => all.first);
    }
    try {
      final row = await db!.from('listings').select(listingSelect).eq('id', id).single();
      if (row['status'] == 'ACTIVE') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('recent_listing_$id', jsonEncode(row));
      }
      return row;
    } catch (_) {
      final cached = await recent(id);
      if (cached == null) rethrow;
      return {...cached, '__cached': true};
    }
  }

  Future<Map<String, dynamic>?> recent(String id) async {
    final raw = (await SharedPreferences.getInstance()).getString('recent_listing_$id');
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  String imageUrl(String path) => db?.storage.from('listing-images').getPublicUrl(path) ?? '';

  Future<DateTime> serverTime() async {
    if (db == null) return DateTime.now();
    final result = await db!.rpc('server_clock');
    return DateTime.parse(result.toString());
  }
}

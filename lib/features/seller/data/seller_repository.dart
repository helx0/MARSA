import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerRepository {
  const SellerRepository(this.db);
  final SupabaseClient? db;

  Future<Map<String, dynamic>?> myApplication() async {
    if (db == null) return null;
    final uid = db!.auth.currentUser?.id;
    if (uid == null) return null;
    return db!.from('seller_profiles').select('*,seller_verifications(rejection_reason_private)').eq('user_id', uid).maybeSingle();
  }

  Future<void> apply(String businessName, String description) async {
    if (db == null) return;
    final uid = db!.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in required');
    await db!.from('seller_profiles').insert({'user_id': uid, 'business_name': businessName, 'description': description});
  }

  Future<List<Map<String, dynamic>>> myListings() async {
    if (db == null) return [];
    final uid = db!.auth.currentUser?.id;
    if (uid == null) return [];
    return (await db!.from('listings').select('id,title_ar,status,sale_type,quantity_available,unit,currency_code,created_at,direct_sale_details(unit_price),auctions(current_price,status)').eq('seller_id', uid).order('created_at', ascending: false)).cast<Map<String, dynamic>>();
  }

  Future<String> create(Map<String, dynamic> values) async {
    if (db == null) return 'mock-listing-id';
    final id = await db!.rpc('create_listing', params: values);
    return id.toString();
  }

  Future<void> uploadImages(String listingId, List<XFile> images) async {
    if (db == null) return;
    final uid = db!.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in required');
    for (var i = 0; i < images.length; i++) {
      final bytes = await images[i].readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) throw StateError('Image exceeds 5 MB');
      final extension = images[i].name.toLowerCase().split('.').last;
      final valid = ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
      final mime = valid == 'png' ? 'image/png' : valid == 'webp' ? 'image/webp' : 'image/jpeg';
      final path = '$uid/$listingId/${DateTime.now().microsecondsSinceEpoch}_$i.$valid';
      await db!.storage.from('listing-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
      await db!.from('listing_images').insert({'listing_id': listingId, 'storage_path': path, 'sort_order': i});
    }
  }

  Future<void> changeStatus(String id, String status) async {
    if (db == null) return;
    await db!.rpc('change_listing_status', params: {'p_listing': id, 'p_status': status});
  }

  Future<void> updateListing(String id, Map<String, dynamic> changes) async {
    if (db == null) return;
    await db!.from('listings').update(changes).eq('id', id);
  }

  Future<void> adjustStock(String id, num delta) async {
    if (db == null) return;
    await db!.rpc('adjust_stock', params: {'p_listing': id, 'p_delta': delta});
  }

  Future<void> changePrice(String id, num price) async {
    if (db == null) return;
    await db!.rpc('change_direct_price', params: {'p_listing': id, 'p_price': price});
  }
}

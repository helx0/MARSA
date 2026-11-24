import 'package:supabase_flutter/supabase_flutter.dart';

class AuctionRepository {
  const AuctionRepository(this.db);final SupabaseClient db;
  Future<Map<String,dynamic>?> activity(String listing) async {
    final row=await db.rpc('auction_activity',params:{'p_listing':listing});
    return row==null?null:Map<String,dynamic>.from(row as Map);
  }
  Future<Map<String,dynamic>> bid(String listing,num amount,String requestId) async {
    final row=await db.rpc('place_bid',params:{'p_listing':listing,'p_amount':amount,'p_request_id':requestId});
    return Map<String,dynamic>.from(row as Map);
  }
  Future<String> finalize(String listing) async =>
    (await db.rpc('finalize_auction',params:{'p_listing':listing})).toString();
}

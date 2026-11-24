import 'package:supabase_flutter/supabase_flutter.dart';

const orderSelect='id,order_number,buyer_id,seller_id,status,currency_code,subtotal,payment_arrangement,payment_status,handover_method,area_id,notes,cancellation_reason,auction_listing_id,created_at,order_items(id,listing_id,title_snapshot,unit_snapshot,quantity,unit_price_snapshot,line_total),order_status_history(old_status,new_status,note,created_at),aden_areas(name_ar,name_en)';

class OrderRepository {
  const OrderRepository(this.db);
  final SupabaseClient? db;

  Future<List<Map<String,dynamic>>> mine() async {
    if (db == null) return [];
    final uid=db!.auth.currentUser?.id;if(uid==null)return [];
    return (await db!.from('orders').select(orderSelect).or('buyer_id.eq.$uid,seller_id.eq.$uid').order('created_at',ascending:false)).cast<Map<String,dynamic>>();
  }
  
  Future<Map<String,dynamic>> byId(String id) async {
    if (db == null) return {};
    return db!.from('orders').select(orderSelect).eq('id',id).single();
  }
  
  Future<String> place({required String listing,required num quantity,required String requestId,required String area,required String handover,required String payment,required String notes}) async {
    if (db == null) return 'mock-order-id';
    final result=await db!.rpc('place_order',params:{'p_listing':listing,'p_quantity':quantity,'p_key':requestId,'p_area':area,'p_handover':handover,'p_payment':payment,'p_notes':notes});
    return result.toString();
  }
  
  Future<void> transition(String order,String status,{String note=''}) async {
    if (db == null) return;
    await db!.rpc('transition_order',params:{'p_order':order,'p_status':status,'p_note':note});
  }
}

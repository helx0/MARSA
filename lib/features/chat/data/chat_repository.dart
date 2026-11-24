import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  const ChatRepository(this.db);
  final SupabaseClient? db;

  Future<String> start(String listing) async {
    if (db == null) return 'mock-chat-id';
    return (await db!.rpc('start_conversation', params: {'p_listing': listing})).toString();
  }

  Future<List<Map<String, dynamic>>> mine() async {
    if (db == null) return [];
    return (await db!.from('conversations').select('id,created_at,listing_id,listings(title_ar),conversation_participants(user_id)').order('updated_at', ascending: false)).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> messages(String conversation) async {
    if (db == null) return [];
    return (await db!.from('messages').select('id,sender_id,body,created_at').eq('conversation_id', conversation).order('created_at').limit(200)).cast<Map<String, dynamic>>();
  }

  Future<void> send(String conversation, String body) async {
    if (db == null) return;
    final uid = db!.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in required');
    await db!.from('messages').insert({'conversation_id': conversation, 'sender_id': uid, 'body': body.trim()});
  }

  Future<void> block(String uid) async {
    if (db == null) return;
    final me = db!.auth.currentUser?.id;
    if (me == null) throw StateError('Sign in required');
    await db!.from('blocked_users').insert({'blocker_id': me, 'blocked_id': uid});
  }
}

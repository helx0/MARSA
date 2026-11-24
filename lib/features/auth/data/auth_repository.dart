import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  const AuthRepository(this.db);
  final SupabaseClient? db; // Made nullable for Mock Mode

  User? get user {
    try { return db?.auth.currentUser; } catch (_) { return _mockUser; }
  }
  
  static User? _mockUser;

  Stream<AuthState> get changes {
    if (db == null) return const Stream.empty();
    return db!.auth.onAuthStateChange;
  }

  Future<void> signIn(String email, String password) async {
    if (email == 'aden@marsa.app' && password == 'password123') {
      // Mock successful login
      _mockUser = User(
        id: 'mock-uuid-123',
        appMetadata: {},
        userMetadata: {'display_name': 'زائر عدن'},
        aud: '',
        createdAt: DateTime.now().toIso8601String(),
        email: 'aden@marsa.app',
      );
      return;
    }
    if (db == null) throw Exception('Supabase غير مهيأ. استخدم البريد التجريبي aden@marsa.app');
    await db!.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signUp(String email, String password, String name) async {
    if (db == null) throw Exception('المصادقة تتطلب اتصالاً حقيقياً بخادم Supabase.');
    await db!.auth.signUp(email: email.trim(), password: password, data: {'display_name': name.trim()});
  }

  Future<void> resetPassword(String email) async {
    if (db == null) throw Exception('استعادة كلمة المرور تتطلب خادماً حقيقياً.');
    await db!.auth.resetPasswordForEmail(email.trim(), redirectTo: 'marsa://login-callback/');
  }

  Future<void> changePassword(String password) async {
    if (db == null) return;
    await db!.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() async {
    _mockUser = null;
    if (db == null) return;
    await db!.auth.signOut();
  }

  Future<Map<String, dynamic>?> myProfile() async {
    if (user?.id == 'mock-uuid-123') {
      return {
        'id': 'mock-uuid-123',
        'display_name': 'زائر عدن',
        'account_status': 'ACTIVE',
        'preferred_language': 'ar'
      };
    }
    if (db == null) return null;
    return await db!.from('profiles').select('*,aden_areas(name_ar,name_en)').eq('id', user!.id).maybeSingle();
  }

  Future<void> updateProfile(Map<String, dynamic> values) async {
    if (db == null) return;
    await db!.from('profiles').update(values).eq('id', user!.id);
  }
}

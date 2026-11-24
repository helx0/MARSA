import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization/strings.dart';
import '../core/theme/marsa_theme.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/marketplace/presentation/market_screens.dart';
import '../features/seller/presentation/seller_screens.dart';
import '../features/orders/presentation/order_screens.dart';
import '../features/chat/presentation/chat_screens.dart';
import '../features/community/presentation/community_screens.dart';
import '../features/profile/presentation/profile_screens.dart';
import '../features/admin/presentation/admin_screens.dart';
import 'providers.dart';

class AuthRefresh extends ChangeNotifier {
  VoidCallback? onPasswordRecovery;
  AuthRefresh(SupabaseClient? db) {
    if (db == null) return;
    _subscription = db.auth.onAuthStateChange.listen((state) {
      notifyListeners();
      if (state.event == AuthChangeEvent.passwordRecovery) onPasswordRecovery?.call();
    });
  }
  StreamSubscription<AuthState>? _subscription;
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Use the safe provider instead of Supabase.instance
  final db = ref.watch(clientProvider);
  final refresh = AuthRefresh(db);
  
  final router = GoRouter(
    initialLocation: '/launch',
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final protected = path.startsWith('/order/') ||
          path == '/checkout' ||
          path.startsWith('/checkout/') ||
          path == '/orders' ||
          path == '/favorites' ||
          path == '/inbox' ||
          path.startsWith('/conversation/') ||
          path.startsWith('/seller') ||
          path == '/notifications' ||
          path == '/admin';
      
      // Access currentUser safely
      final currentUser = db?.auth.currentUser;
      if (db != null && protected && currentUser == null) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/launch', builder: (c, s) => const LaunchScreen()),
      GoRoute(path: '/intro', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (c, s) => const MarketScreen()),
      GoRoute(path: '/listing/:id', builder: (c, s) => ListingDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/login', builder: (c, s) => const AuthScreen(mode: 'login')),
      GoRoute(path: '/signup', builder: (c, s) => const AuthScreen(mode: 'signup')),
      GoRoute(path: '/reset', builder: (c, s) => const AuthScreen(mode: 'reset')),
      GoRoute(path: '/password-update', builder: (c, s) => const AuthScreen(mode: 'newPassword')),
      GoRoute(path: '/checkout/:id', builder: (c, s) => CheckoutScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
      GoRoute(path: '/order/:id', builder: (c, s) => OrderDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/favorites', builder: (c, s) => const FavoritesScreen()),
      GoRoute(path: '/inbox', builder: (c, s) => const InboxScreen()),
      GoRoute(path: '/conversation/:id', builder: (c, s) => ConversationScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/seller', builder: (c, s) => const SellerCenterScreen()),
      GoRoute(path: '/seller/apply', builder: (c, s) => const SellerApplyScreen()),
      GoRoute(path: '/seller/create', builder: (c, s) => const CreateListingScreen()),
      GoRoute(path: '/seller/edit/:id', builder: (c, s) => SellerEditScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/admin', builder: (c, s) => const AdminScreen()),
      GoRoute(path: '/help', builder: (c, s) => const HelpScreen()),
    ],
  );

  refresh.onPasswordRecovery = () => router.go('/password-update');
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class MarsaApp extends ConsumerWidget {
  const MarsaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    return MaterialApp.router(
      title: 'MARSA مرسى',
      debugShowCheckedModeBanner: false,
      theme: marsaTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: Locale(language),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => Directionality(
        textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

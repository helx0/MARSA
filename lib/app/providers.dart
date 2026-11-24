import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/marketplace/data/market_repository.dart';
import '../features/seller/data/seller_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/auctions/data/auction_repository.dart';
import '../features/chat/data/chat_repository.dart';
import '../features/community/data/community_repository.dart';
import '../features/admin/data/admin_repository.dart';
import '../core/config/environment.dart';

// Safe provider that doesn't trigger "Supabase instance not initialized"
final clientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppEnvironment.isConfigured) return null;
  // Use a safe check to avoid the assertion error
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(clientProvider)));
final marketRepositoryProvider = Provider((ref) => MarketRepository(ref.watch(clientProvider)));
final sellerRepositoryProvider = Provider((ref) => SellerRepository(ref.watch(clientProvider)));
final orderRepositoryProvider = Provider((ref) => OrderRepository(ref.watch(clientProvider)));
final auctionRepositoryProvider = Provider((ref) => AuctionRepository(ref.watch(clientProvider)));
final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(clientProvider)));
final communityRepositoryProvider = Provider((ref) => CommunityRepository(ref.watch(clientProvider)));
final adminRepositoryProvider = Provider((ref) => AdminRepository(ref.watch(clientProvider)));

final areasProvider = FutureProvider((ref) => ref.read(marketRepositoryProvider).areas());
final categoriesProvider = FutureProvider((ref) => ref.read(marketRepositoryProvider).categories());
final profileProvider = FutureProvider((ref) => ref.read(authRepositoryProvider).myProfile());
final sellerApplicationProvider = FutureProvider((ref) => ref.read(sellerRepositoryProvider).myApplication());
final isAdminProvider = FutureProvider((ref) => ref.read(adminRepositoryProvider).isAdmin());

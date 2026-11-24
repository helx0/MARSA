import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/shell.dart';
import '../../../core/localization/strings.dart';
import '../../../core/widgets/common.dart';
import '../../marketplace/presentation/market_screens.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});
  @override ConsumerState<FavoritesScreen> createState()=>_FavoritesState();
}
class _FavoritesState extends ConsumerState<FavoritesScreen> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(communityRepositoryProvider).favorites();}
  Future<void> remove(String id)async {
    try{await ref.read(communityRepositoryProvider).toggleFavorite(id,true);if(mounted)setState(reload);}
    catch(e){if(mounted)showToast(context,'$e');}
  }
  @override Widget build(BuildContext context)=>MarsaShell(selected:1,child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
    if(s.connectionState!=ConnectionState.done)return const LoadingView();
    if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
    if(s.data!.isEmpty)return EmptyState(title:t(ref,'empty'));
    return RefreshIndicator(onRefresh:()async{setState(reload);await future;},child:ListView(padding:const EdgeInsets.all(16),
      children:[for(final x in s.data!)Card(child:ListTile(
        title:Text(itemMap(x['listings'])['title_ar']?.toString()??'الإعلان غير متاح حالياً'),
        subtitle:Text(itemMap(x['listings'])['status']?.toString()??'Unavailable'),
        onTap:itemMap(x['listings']).isEmpty?null:()=>context.push('/listing/${x['listing_id']}'),
        trailing:IconButton(tooltip:'Remove',onPressed:()=>remove(x['listing_id'].toString()),icon:const Icon(Icons.favorite))))]));
  }));
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override ConsumerState<NotificationsScreen> createState()=>_NotificationState();
}
class _NotificationState extends ConsumerState<NotificationsScreen> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(communityRepositoryProvider).notifications();}
  Future<void> open(Map<String,dynamic> n)async{
    try{await ref.read(communityRepositoryProvider).markRead(n['id'].toString());}catch(e){if(mounted)showToast(context,'$e');}
    final payload=itemMap(n['payload']);
    if(!mounted)return;
    if(payload['order_id']!=null)context.push('/order/${payload['order_id']}');
    else if(payload['listing_id']!=null)context.push('/listing/${payload['listing_id']}');
    else if(n['type']=='SELLER_STATUS')context.push('/seller');
    else setState(reload);
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'notifications')),
    actions:[IconButton(onPressed:()=>setState(reload),icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
      if(s.data!.isEmpty)return EmptyState(title:t(ref,'empty'));
      return ListView(padding:const EdgeInsets.all(16),children:[for(final n in s.data!)Card(child:ListTile(
        leading:Icon(n['read_at']==null?Icons.notifications_active:Icons.notifications_none),
        title:Text(n['type'].toString()),subtitle:Text(n['created_at'].toString()),
        onTap:()=>open(n),trailing:n['read_at']==null?const Icon(Icons.circle,size:9):null))]);
    }));
}

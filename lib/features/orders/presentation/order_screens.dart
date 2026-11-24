import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/providers.dart';
import '../../../app/shell.dart';
import '../../../core/localization/strings.dart';
import '../../../core/widgets/common.dart';
import '../../marketplace/presentation/market_screens.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key,required this.id});final String id;
  @override ConsumerState<CheckoutScreen> createState()=>_CheckoutState();
}
class _CheckoutState extends ConsumerState<CheckoutScreen> {
  late Future<Map<String,dynamic>> future;
  final qty=TextEditingController(text:'1');final notes=TextEditingController();
  final requestId=const Uuid().v4();String? area;
  String handover='PICKUP',payment='CASH_ON_HANDOVER';bool busy=false;
  @override void initState(){super.initState();future=ref.read(marketRepositoryProvider).listing(widget.id);}
  @override void dispose(){qty.dispose();notes.dispose();super.dispose();}
  Future<void> checkout(Map<String,dynamic> listing) async {
    final quantity=num.tryParse(qty.text);
    if(listing['__cached']==true){showToast(context,'لا يمكن إتمام طلب باستخدام بيانات محفوظة دون اتصال.');return;}
    if(quantity==null || quantity<=0 || area==null){showToast(context,'تحقق من الكمية واختر منطقة عدن.');return;}
    final stock=listing['quantity_available'] as num? ??0;
    if(quantity>stock){showToast(context,'الكمية أكبر من المتاح');return;}
    setState(()=>busy=true);
    try{
      final id=await ref.read(orderRepositoryProvider).place(listing:widget.id,quantity:quantity,
        requestId:requestId,area:area!,handover:handover,payment:payment,notes:notes.text);
      if(mounted)context.go('/order/$id');
    }catch(e){if(mounted)showToast(context,'فشل الطلب: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'checkout'))),
    body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(()=>future=ref.read(marketRepositoryProvider).listing(widget.id)));
      final l=s.data!;final price=itemMap(l['direct_sale_details'])['unit_price'] as num? ??0;
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text(l['title_ar'].toString(),style:Theme.of(context).textTheme.titleLarge),
        Text('${t(ref,'available')}: ${l['quantity_available']} ${l['unit']}'),const FormSpace(),
        TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:t(ref,'quantity')),
          onChanged:(_)=>setState((){})),
        const FormSpace(),ref.watch(areasProvider).when(
          data:(rows)=>DropdownButtonFormField<String>(value:area,decoration:InputDecoration(labelText:t(ref,'area')),
            items:rows.map((r)=>DropdownMenuItem<String>(value:r['id'].toString(),child:Text(r['name_ar'].toString()))).toList(),
            onChanged:(v)=>setState(()=>area=v)),loading:()=>const LinearProgressIndicator(),error:(e,_)=>Text('$e')),
        const FormSpace(),DropdownButtonFormField<String>(value:handover,decoration:InputDecoration(labelText:t(ref,'handover')),
          items:const [DropdownMenuItem(value:'PICKUP',child:Text('استلام شخصي / Pickup')),
            DropdownMenuItem(value:'AGREED_DELIVERY',child:Text('توصيل بالاتفاق / Agreed delivery'))],onChanged:(v)=>setState(()=>handover=v??'PICKUP')),
        const FormSpace(),DropdownButtonFormField<String>(value:payment,decoration:InputDecoration(labelText:t(ref,'payment')),
          items:const [DropdownMenuItem(value:'CASH_ON_HANDOVER',child:Text('نقداً عند الاستلام / Cash')),
            DropdownMenuItem(value:'MANUAL_EXTERNAL_AGREEMENT',child:Text('اتفاق مباشر / External agreement'))],onChanged:(v)=>setState(()=>payment=v??'CASH_ON_HANDOVER')),
        const FormSpace(),TextField(controller:notes,maxLines:3,maxLength:500,decoration:InputDecoration(labelText:t(ref,'notes'))),
        const FormSpace(),Text(t(ref,'noOnlinePayment')),
        const Divider(),Text('${t(ref,'subtotal')}: ${money((num.tryParse(qty.text)??0)*price,l['currency_code'].toString())}',
          style:Theme.of(context).textTheme.titleLarge),const FormSpace(),
        ElevatedButton(onPressed:busy || l['__cached']==true || l['status']!='ACTIVE' ? null : ()=>checkout(l),child:Text(busy?t(ref,'loading'):t(ref,'confirm'))),
      ]);
    }));
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override ConsumerState<OrdersScreen> createState()=>_OrdersState();
}
class _OrdersState extends ConsumerState<OrdersScreen> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(orderRepositoryProvider).mine();}
  @override Widget build(BuildContext context)=>MarsaShell(selected:2,child:RefreshIndicator(
    onRefresh:()async{setState(reload);await future;},child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
      if(s.data!.isEmpty)return EmptyState(title:t(ref,'empty'));
      return ListView(padding:const EdgeInsets.all(16),children:[for(final o in s.data!)Card(child:ListTile(
        title:Text(o['order_number'].toString()),subtitle:Text('${o['status']} · ${money(o['subtotal'],o['currency_code'].toString())}'),
        trailing:const Icon(Icons.chevron_right),onTap:()=>context.push('/order/${o['id']}')))]);
    })));
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key,required this.id});final String id;
  @override ConsumerState<OrderDetailScreen> createState()=>_OrderDetailState();
}
class _OrderDetailState extends ConsumerState<OrderDetailScreen> {
  late Future<Map<String,dynamic>> future;bool busy=false;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(orderRepositoryProvider).byId(widget.id);}
  Future<void> change(String to)async{
    setState(()=>busy=true);
    try{await ref.read(orderRepositoryProvider).transition(widget.id,to);if(mounted){showToast(context,'تم تحديث حالة الطلب');setState(reload);}}
    catch(e){if(mounted)showToast(context,'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> review(Map<String,dynamic> o) async {
    var rating=5;final comment=TextEditingController();
    final approved=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setDialog)=>AlertDialog(
      title:Text(t(ref,'review')),
      content:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButton<int>(value:rating,
        items:[for(var i=1;i<=5;i++)DropdownMenuItem(value:i,child:Text('$i ★'))],onChanged:(v)=>setDialog(()=>rating=v??5)),
        TextField(controller:comment,maxLength:500,maxLines:3,decoration:const InputDecoration(hintText:'تعليق اختياري'))]),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t(ref,'cancel'))),
        ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:Text(t(ref,'send')))])));
    if(approved==true){
      try{await ref.read(communityRepositoryProvider).review(widget.id,o['seller_id'].toString(),rating,comment.text);
        if(mounted)showToast(context,'تم إرسال التقييم.');}
      catch(e){if(mounted)showToast(context,'تعذر حفظ التقييم (ربما قيّمت الطلب سابقاً): $e');}
    }
    comment.dispose();
  }
  Future<void> dispute()async {
    final reason=TextEditingController();
    final accepted=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('الإبلاغ عن نزاع'),
      content:TextField(controller:reason,decoration:const InputDecoration(hintText:'اشرح المشكلة بالتفصيل')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),
        ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال'))]));
    if(accepted==true){try{await ref.read(communityRepositoryProvider).report('ORDER',widget.id,reason.text);
      if(mounted)showToast(context,'تم إرسال البلاغ للإدارة');}catch(e){if(mounted)showToast(context,'$e');}}
    reason.dispose();
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'details')),
    actions:[IconButton(onPressed:()=>setState(reload),icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
      final o=s.data!;final uid=ref.read(authRepositoryProvider).user?.id;
      final isBuyer=uid==o['buyer_id'],isSeller=uid==o['seller_id'];final status=o['status'].toString();
      final items=itemList(o['order_items']);final history=itemList(o['order_status_history']);
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text('${t(ref,'orderNumber')}: ${o['order_number']}',style:Theme.of(context).textTheme.titleLarge),
        const FormSpace(),StatusPill(status),const FormSpace(),
        Text('${t(ref,'subtotal')}: ${money(o['subtotal'],o['currency_code'].toString())}',style:Theme.of(context).textTheme.titleMedium),
        Text('${t(ref,'payment')}: ${o['payment_arrangement']}'),
        Text('${t(ref,'handover')}: ${o['handover_method']}'),
        Text('${t(ref,'notes')}: ${o['notes']??''}'),const Divider(),
        for(final x in items)ListTile(title:Text(itemMap(x)['title_snapshot'].toString()),
          subtitle:Text('${itemMap(x)['quantity']} ${itemMap(x)['unit_snapshot']}'),
          trailing:Text(money(itemMap(x)['line_total'],o['currency_code'].toString()))),
        const Divider(),Text(t(ref,'history'),style:Theme.of(context).textTheme.titleMedium),
        for(final h in history)ListTile(dense:true,leading:const Icon(Icons.check_circle_outline),
          title:Text(itemMap(h)['new_status'].toString()),subtitle:Text(itemMap(h)['created_at'].toString())),
        const FormSpace(),if(isSeller && status=='PENDING_SELLER_CONFIRMATION')...[
          ElevatedButton(onPressed:busy?null:()=>change('ACCEPTED'),child:const Text('قبول الطلب / Accept')),
          OutlinedButton(onPressed:busy?null:()=>change('REJECTED'),child:const Text('رفض الطلب / Reject'))],
        if(isSeller && status=='ACCEPTED')...[
          ElevatedButton(onPressed:busy?null:()=>change('PREPARING'),child:const Text('قيد التجهيز / Preparing')),
          OutlinedButton(onPressed:busy?null:()=>change('READY_FOR_HANDOVER'),child:const Text('جاهز للاستلام / Ready'))],
        if(isSeller && status=='PREPARING')ElevatedButton(onPressed:busy?null:()=>change('READY_FOR_HANDOVER'),child:const Text('جاهز للاستلام / Ready')),
        if(isBuyer && status=='PENDING_SELLER_CONFIRMATION')OutlinedButton(onPressed:busy?null:()=>change('CANCELLED'),child:Text(t(ref,'cancel'))),
        if(isBuyer && status=='READY_FOR_HANDOVER')ElevatedButton(onPressed:busy?null:()=>change('COMPLETED'),child:const Text('تأكيد الاستلام / Confirm receipt')),
        if(isBuyer && status=='COMPLETED')OutlinedButton(onPressed:()=>review(o),child:Text(t(ref,'review'))),
        if(isBuyer||isSeller)TextButton.icon(onPressed:dispute,icon:const Icon(Icons.flag_outlined),label:const Text('إبلاغ عن مشكلة / Report issue')),
      ]);
    }));
}

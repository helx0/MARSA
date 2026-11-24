import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/providers.dart';
import '../../auctions/domain/auction_math.dart';
import '../../../app/shell.dart';
import '../../../core/localization/strings.dart';
import '../../../core/theme/marsa_theme.dart';
import '../../../core/widgets/common.dart';

Map<String,dynamic> itemMap(dynamic raw) {
  if(raw is Map<String,dynamic>)return raw;
  if(raw is Map)return Map<String,dynamic>.from(raw);
  if(raw is List && raw.isNotEmpty)return itemMap(raw.first);
  return {};
}
List<dynamic> itemList(dynamic raw) => raw is List?raw:[];

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});
  @override ConsumerState<MarketScreen> createState()=>_MarketState();
}
class _MarketState extends ConsumerState<MarketScreen> {
  final search=TextEditingController();
  final minimum=TextEditingController(),maximum=TextEditingController();
  String? category,area,mode,currency;bool onlyAvailable=true;String sort='newest';int page=0;
  late Future<List<Map<String,dynamic>>> rows;
  @override void initState(){super.initState();reload();}
  void reload(){rows=ref.read(marketRepositoryProvider).listings(search:search.text,category:category,area:area,mode:mode,sort:sort,page:page,
    currency:currency,minPrice:num.tryParse(minimum.text),maxPrice:num.tryParse(maximum.text),onlyAvailable:onlyAvailable);}
  void refresh(){setState(reload);}
  @override void dispose(){search.dispose();minimum.dispose();maximum.dispose();super.dispose();}
  
  Future<void> openFilters() async {
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>
      StatefulBuilder(builder:(context,setModal)=>Padding(padding:EdgeInsets.fromLTRB(20,12,20,MediaQuery.viewInsetsOf(context).bottom+28),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(t(ref,'filter'),style:Theme.of(context).textTheme.titleLarge),const FormSpace(),
        _DropdownFromAsync(value:area,provider:ref.watch(areasProvider),hint:t(ref,'area'),onChanged:(v){setModal(()=>area=v);}),
        const FormSpace(),_DropdownFromAsync(value:category,provider:ref.watch(categoriesProvider),hint:t(ref,'category'),onChanged:(v){setModal(()=>category=v);}),
        const FormSpace(),DropdownButtonFormField<String>(value:mode,decoration:InputDecoration(labelText:t(ref,'direct')+' / '+t(ref,'auction')),
          items:[const DropdownMenuItem<String>(value:null,child:Text('الكل / All')),
            DropdownMenuItem(value:'DIRECT',child:Text(t(ref,'direct'))),DropdownMenuItem(value:'AUCTION',child:Text(t(ref,'auction')))],onChanged:(v)=>setModal(()=>mode=v)),
        const FormSpace(),DropdownButtonFormField<String>(value:currency,decoration:const InputDecoration(labelText:'العملة (مطلوبة لمقارنة الأسعار)'),
          items:const [DropdownMenuItem<String>(value:null,child:Text('كل العملات')),
            DropdownMenuItem(value:'YER',child:Text('YER')),DropdownMenuItem(value:'SAR',child:Text('SAR')),
            DropdownMenuItem(value:'USD',child:Text('USD'))],onChanged:(v)=>setModal(()=>currency=v)),
        const FormSpace(),Row(children:[Expanded(child:TextField(controller:minimum,keyboardType:TextInputType.number,
          decoration:const InputDecoration(labelText:'سعر من'))),const SizedBox(width:8),
          Expanded(child:TextField(controller:maximum,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'سعر إلى')))]),
        const FormSpace(),SwitchListTile(title:const Text('المتاح فقط / In stock'),value:onlyAvailable,onChanged:(v)=>setModal(()=>onlyAvailable=v)),
        const FormSpace(),DropdownButtonFormField<String>(value:sort,decoration:InputDecoration(labelText:t(ref,'sort')),
          items:const [DropdownMenuItem(value:'newest',child:Text('الأحدث / Newest')),
            DropdownMenuItem(value:'oldest',child:Text('الأقدم / Oldest')),
            DropdownMenuItem(value:'relevance',child:Text('الأكثر صلة / Relevance')),
            DropdownMenuItem(value:'price_asc',child:Text('الأرخص / Price ↑')),
            DropdownMenuItem(value:'price_desc',child:Text('الأغلى / Price ↓'))],onChanged:(v)=>setModal(()=>sort=v??'newest')),
        const FormSpace(),Row(children:[Expanded(child:OutlinedButton(onPressed:(){setModal((){
          area=null;category=null;mode=null;currency=null;sort='newest';onlyAvailable=true;minimum.clear();maximum.clear();
        });},child:const Text('مسح / Reset'))),
          const SizedBox(width:12),Expanded(child:ElevatedButton(onPressed:(){
            if(currency==null&&(minimum.text.isNotEmpty||maximum.text.isNotEmpty||sort.startsWith('price_'))){
              showToast(context,'اختر العملة أولاً لمقارنة الأسعار دون تحويل.');return;
            }
            page=0;refresh();Navigator.of(sheetContext).pop();},child:Text(t(ref,'confirm'))))]),
      ]))));
  }

  @override Widget build(BuildContext context){
    return MarsaShell(selected:0,child:RefreshIndicator(onRefresh:()async{refresh();await rows;},child:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(16,24,16,8),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Container(
          padding:const EdgeInsets.all(24),
          decoration:BoxDecoration(
            gradient: const LinearGradient(colors: [MarsaColors.navy, MarsaColors.teal], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius:BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: MarsaColors.navy.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))]
          ),
          child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('بحر عدن يجود بخيره',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),
            SizedBox(height:4),
            Text('تصفح، زايد، واشترِ طازجاً من قلب صيرة والبريقة',style:TextStyle(color:MarsaColors.turquoise, fontSize: 14))
          ]),
        ),
        const SizedBox(height:20),
        TextField(controller:search,onSubmitted:(_){page=0;refresh();},
          decoration:InputDecoration(
            prefixIcon:const Icon(Icons.search, color: MarsaColors.teal),
            hintText:t(ref,'search'),
            suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward),onPressed:(){page=0;refresh();}),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            filled: true, fillColor: Colors.white,
          )),
        const SizedBox(height:12),
        Row(children:[
          OutlinedButton.icon(onPressed:openFilters,icon:const Icon(Icons.tune, size: 20),label:Text(t(ref,'filter'))),
          const SizedBox(width:8),
          ChoiceChip(label:Text(t(ref,'all')),selected:mode==null,onSelected:(_){mode=null;page=0;refresh();}),
          const SizedBox(width:5),
          ChoiceChip(label:Text(t(ref,'auction')),selected:mode=='AUCTION',onSelected:(_){mode='AUCTION';page=0;refresh();}),
        ]),const SizedBox(height:6),
      ]))),
      FutureBuilder<List<Map<String,dynamic>>>(future:rows,builder:(context,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return const SliverFillRemaining(child:LoadingView());
        if(snapshot.hasError)return SliverFillRemaining(child:ErrorView(error:snapshot.error!,onRetry:refresh));
        final listings=snapshot.data??[];
        if(listings.isEmpty)return SliverFillRemaining(child:EmptyState(title:t(ref,'empty')));
        return SliverPadding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),sliver:SliverList.builder(itemCount:listings.length+1,itemBuilder:(context,i){
          if(i==listings.length)return Center(child:Padding(padding:const EdgeInsets.all(14),child:TextButton.icon(
            onPressed:listings.length==20?(){page++;refresh();}:null,icon:const Icon(Icons.more_horiz),label:Text(t(ref,'more')))));
          return SeafoodListingCard(listing:listings[i]);
        }));
      }),
    ])));
  }
}

class _DropdownFromAsync extends StatelessWidget {
  const _DropdownFromAsync({required this.value,required this.provider,required this.hint,required this.onChanged});
  final String? value;final AsyncValue<List<Map<String,dynamic>>> provider;
  final String hint;final ValueChanged<String?> onChanged;
  @override Widget build(BuildContext context)=>provider.when(
    data:(rows)=>DropdownButtonFormField<String>(value:value,decoration:InputDecoration(labelText:hint),
      items:[const DropdownMenuItem<String>(value:null,child:Text('الكل / All')),...rows.map((e)=>DropdownMenuItem(value:e['id'].toString(),child:Text(e['name_ar'].toString())))],
      onChanged:onChanged),
    loading:()=>const LinearProgressIndicator(),error:(e,_)=>Text('$hint: $e'));
}

class SeafoodListingCard extends ConsumerWidget {
  const SeafoodListingCard({super.key,required this.listing});
  final Map<String,dynamic> listing;
  
  String get _fallbackImage {
    final title = listing['title_ar'].toString();
    if (title.contains('ديرك')) return 'https://images.unsplash.com/photo-1534604973900-c43ab4c2e0ab?w=500&q=80';
    if (title.contains('روبيان')) return 'https://images.unsplash.com/photo-1559740038-191442f46df0?w=500&q=80';
    if (title.contains('تونة') || title.contains('ثمد')) return 'https://images.unsplash.com/photo-1501595091296-3aa970afb3ff?w=500&q=80';
    return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=500&q=80';
  }

  @override Widget build(BuildContext context,WidgetRef ref){
    final images=itemList(listing['listing_images']);
    final price=itemMap(listing['direct_sale_details'])['unit_price'];
    final auction=itemMap(listing['auctions']);
    final area=itemMap(listing['aden_areas']);
    final type=listing['sale_type'].toString();
    
    return Card(clipBehavior:Clip.antiAlias,margin:const EdgeInsets.only(bottom:16),child:InkWell(
      onTap:()=>context.push('/listing/${listing['id']}'),child:Row(children:[
        Stack(children: [
          SizedBox(width:120,height:135,child:
            Image.network(
              images.isEmpty ? _fallbackImage : ref.read(marketRepositoryProvider).imageUrl(itemMap(images.first)['storage_path'].toString()),
              fit:BoxFit.cover,
              errorBuilder:(_,__,___)=>Container(color: MarsaColors.seafoam, child: const Icon(Icons.set_meal, color: MarsaColors.teal, size: 40))
            )
          ),
          if(type=='AUCTION') Positioned(top: 8, left: 8, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: MarsaColors.coral, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.gavel, color: Colors.white, size: 14),
          ))
        ]),
        Expanded(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(listing['title_ar'].toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800, color: MarsaColors.navy)),
          const SizedBox(height:6),
          Row(children: [
            StatusPill(type=='AUCTION'?t(ref,'auction'):t(ref,'direct')),
            const SizedBox(width: 8),
            Text('📍 ${area['name_ar']??'عدن'}',style:const TextStyle(color:MarsaColors.muted,fontSize:12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height:10),
          Text(type=='AUCTION'?money(auction['current_price'],listing['currency_code'].toString()):
            '${money(price,listing['currency_code'].toString())} / ${listing['unit']}',style:const TextStyle(fontWeight:FontWeight.w900,color:MarsaColors.teal, fontSize: 18)),
        ]))),
        const Icon(Icons.chevron_left, color: MarsaColors.turquoise),
        const SizedBox(width:8),
      ])));
  }
}

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key,required this.id});final String id;
  @override ConsumerState<ListingDetailScreen> createState()=>_ListingDetailState();
}
class _ListingDetailState extends ConsumerState<ListingDetailScreen> {
  late Future<Map<String,dynamic>> future;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(marketRepositoryProvider).listing(widget.id);}
  Future<void> onReport() async {
    final reason=TextEditingController();
    final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('إبلاغ عن الإعلان'),content:TextField(controller:reason,maxLines:3,decoration:const InputDecoration(hintText:'سبب البلاغ (5 أحرف على الأقل)')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),
      ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('إرسال'))]));
    if(approved==true){
      if(ref.read(authRepositoryProvider).user==null){if(mounted)context.push('/login');return;}
      try{await ref.read(communityRepositoryProvider).report('LISTING',widget.id,reason.text);if(mounted)showToast(context,'تم إرسال البلاغ.');}
      catch(e){if(mounted)showToast(context,'$e');}
    }
    reason.dispose();
  }
  Future<void> onChat() async {
    if(ref.read(authRepositoryProvider).user==null){context.push('/login');return;}
    try{final id=await ref.read(chatRepositoryProvider).start(widget.id);if(mounted)context.push('/conversation/$id');}
    catch(e){if(mounted)showToast(context,'$e');}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'details')),
    actions:[IconButton(tooltip:t(ref,'report'),onPressed:onReport,icon:const Icon(Icons.flag_outlined)),
      IconButton(tooltip:t(ref,'refresh'),onPressed:()=>setState(reload),icon:const Icon(Icons.refresh))]),
    body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
      final listing=s.data!;
      final imgs=itemList(listing['listing_images']);final a=itemMap(listing['auctions']);
      final direct=itemMap(listing['direct_sale_details']);final type=listing['sale_type']=='AUCTION';
      final area=itemMap(listing['aden_areas']);final seller=itemMap(listing['seller_profiles']);
      return ListView(padding:const EdgeInsets.all(16),children:[
        if(listing['__cached']==true)const Padding(padding:EdgeInsets.all(8),child:Text('نسخة محفوظة دون اتصال — الأسعار والمخزون غير مؤكدة ولا يمكن تنفيذ عمليات.',style:TextStyle(color:MarsaColors.coral))),
        SizedBox(height:210,child:imgs.isEmpty?const ColoredBox(color:MarsaColors.seafoam,child:Icon(Icons.set_meal,size:90,color:MarsaColors.teal)):
          PageView(children:[for(final image in imgs)ClipRRect(borderRadius:BorderRadius.circular(14),child:Image.network(
            ref.read(marketRepositoryProvider).imageUrl(itemMap(image)['storage_path'].toString()),fit:BoxFit.cover,
            errorBuilder:(_,__,___)=>const Icon(Icons.broken_image)))])),
        const FormSpace(),Row(children:[StatusPill(type?t(ref,'auction'):t(ref,'direct')),
          const Spacer(),Text('📍 ${area['name_ar']??'عدن'}')]),const FormSpace(),
        Text(listing['title_ar'].toString(),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
        const FormSpace(),
        Card(child:ListTile(leading:const Icon(Icons.verified_outlined,color:MarsaColors.teal),
          title:Text(seller['business_name']?.toString()??t(ref,'seller')),
          subtitle:Text(seller['verification_status']=='APPROVED'?'بائع معتمد إدارياً':'حالة البائع غير متاحة'))),
        const FormSpace(),Text('${t(ref,'available')}: ${listing['quantity_available']} ${listing['unit']}'),
        const FormSpace(),Text('${t(ref,'condition')}: ${listing['condition_note']??'—'}'),
        const FormSpace(),Text('${t(ref,'description')}: ${listing['description']??'—'}'),
        const SizedBox(height:20),
        if(type)AuctionPanel(listing:listing,auction:a,onChanged:()=>setState(reload))
        else Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('${money(direct['unit_price'],listing['currency_code'].toString())} / ${listing['unit']}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:MarsaColors.teal)),
          const SizedBox(height:12),ElevatedButton(onPressed:listing['status']=='ACTIVE'&&listing['__cached']!=true?()=>context.push('/checkout/${widget.id}'):null,child:Text(t(ref,'buy'))),
        ]))),
        const FormSpace(),OutlinedButton.icon(icon:const Icon(Icons.chat_bubble_outline),onPressed:onChat,label:Text(t(ref,'contact'))),
        _FavoriteButton(listingId:widget.id),
        const SizedBox(height:20),
      ]);
    }));
}
class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({required this.listingId});final String listingId;
  @override ConsumerState<_FavoriteButton> createState()=>_FavoriteState();
}
class _FavoriteState extends ConsumerState<_FavoriteButton> {
  bool? saved;
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){load();});}
  Future<void> load()async{
    if(ref.read(authRepositoryProvider).user==null)return;
    try{final value=await ref.read(communityRepositoryProvider).isFavorite(widget.listingId);if(mounted)setState(()=>saved=value);}catch(_){/* retry by tapping */}
  }
  Future<void> toggle() async {
    if(ref.read(authRepositoryProvider).user==null){context.push('/login');return;}
    try{await ref.read(communityRepositoryProvider).toggleFavorite(widget.listingId,saved??false);if(mounted)setState(()=>saved=!(saved??false));}
    catch(e){if(mounted)showToast(context,'$e');}
  }
  @override Widget build(BuildContext context)=>OutlinedButton.icon(onPressed:toggle,
    icon:Icon(saved==true?Icons.favorite:Icons.favorite_outline,color:saved==true?MarsaColors.coral:null),
    label:Text(saved==true?'إزالة من المفضلة':t(ref,'favorites')));
}

class AuctionPanel extends ConsumerStatefulWidget {
  const AuctionPanel({super.key,required this.listing,required this.auction,required this.onChanged});
  final Map<String,dynamic> listing,auction;final VoidCallback onChanged;
  @override ConsumerState<AuctionPanel> createState()=>_AuctionPanelState();
}
class _AuctionPanelState extends ConsumerState<AuctionPanel> {
  final bidController=TextEditingController();Timer? timer;Duration serverOffset=Duration.zero;
  Map<String,dynamic>? activity;bool working=false;String? pendingBidKey;num? pendingBidAmount;
  @override void initState(){super.initState();timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});
    WidgetsBinding.instance.addPostFrameCallback((_){loadActivity();});}
  @override void dispose(){timer?.cancel();bidController.dispose();super.dispose();}
  Future<void> loadActivity()async{
    try{final v=await ref.read(auctionRepositoryProvider).activity(widget.listing['id'].toString());
      final server=DateTime.tryParse(v?['server_time']?.toString()??'');
      if(mounted)setState((){activity=v;if(server!=null)serverOffset=server.toUtc().difference(DateTime.now().toUtc());});
    }catch(e){if(mounted)showToast(context,'$e');}
  }
  Future<void> submit()async{
    if(ref.read(authRepositoryProvider).user==null){context.push('/login');return;}
    final amount=num.tryParse(bidController.text);
    if(amount==null){showToast(context,'أدخل قيمة صحيحة');return;}
    final confirmed=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t(ref,'confirm')),
      content:Text('تأكيد المزايدة: ${money(amount,widget.listing['currency_code'].toString())}'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t(ref,'cancel'))),
        ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:Text(t(ref,'bid')))]));
    if(confirmed!=true)return;
    if(pendingBidAmount!=amount){pendingBidAmount=amount;pendingBidKey=const Uuid().v4();}
    setState(()=>working=true);
    try{await ref.read(auctionRepositoryProvider).bid(widget.listing['id'].toString(),amount,pendingBidKey!);
      pendingBidKey=null;pendingBidAmount=null;
      if(mounted){showToast(context,'تم قبول المزايدة من الخادم.');await loadActivity();widget.onChanged();}}
    catch(e){if(mounted){showToast(context,'المزايدة مرفوضة: $e');await loadActivity();widget.onChanged();}}
    finally{if(mounted)setState(()=>working=false);}
  }
  @override Widget build(BuildContext context){
    final a=widget.auction;
    final ends=DateTime.tryParse(a['ends_at']?.toString()??'')?.toUtc();
    final starts=DateTime.tryParse(a['starts_at']?.toString()??'')?.toUtc();
    final now=DateTime.now().toUtc().add(serverOffset);
    final isLive=starts!=null&&ends!=null&&!now.isBefore(starts)&&now.isBefore(ends)&&
      ['SCHEDULED','LIVE'].contains(a['status'])&&widget.listing['status']=='ACTIVE'&&widget.listing['__cached']!=true;
    final seconds=ends==null?0:ends.difference(now).inSeconds;
    final remaining=seconds<=0?'انتهى / Ended':'${Duration(seconds:seconds).inHours}h ${(seconds~/60)%60}m ${seconds%60}s';
    final count=(activity?['count'] as num?)?.toInt()??0;
    final current=widget.auction['current_price'] as num? ??0;
    final increment=widget.auction['minimum_increment'] as num? ??0;
    final minimum=displayMinimumBid(startingPrice:widget.auction['start_price'] as num? ??0,currentPrice:current,increment:increment,acceptedBidCount:count);
    return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(t(ref,'currentBid'),style:Theme.of(context).textTheme.titleMedium),
      Text(money(current,widget.listing['currency_code'].toString()),style:const TextStyle(fontSize:26,color:MarsaColors.teal,fontWeight:FontWeight.bold)),
      const FormSpace(),Text('${t(ref,'bidCount')}: $count   •   $remaining'),
      Text('${t(ref,'minBid')}: ${money(minimum,widget.listing['currency_code'].toString())}'),
      const FormSpace(),Text(t(ref,'auctionRules'),style:const TextStyle(color:MarsaColors.muted)),
      const FormSpace(),if(isLive)...[
        TextField(controller:bidController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:t(ref,'bid'))),
        const FormSpace(),ElevatedButton(onPressed:working?null:submit,child:Text(t(ref,'bid'))),
      ]else if(ends!=null && !now.isBefore(ends) && ['SCHEDULED','LIVE'].contains(a['status']))
        OutlinedButton(onPressed:working?null:()async{
          try{await ref.read(auctionRepositoryProvider).finalize(widget.listing['id'].toString());widget.onChanged();}
          catch(e){if(mounted)showToast(context,'$e');}
        },child:const Text('إنهاء المزاد والتحقق من النتيجة')),
      if(activity!=null)...[const Divider(),Text(t(ref,'history'),style:const TextStyle(fontWeight:FontWeight.bold)),
        for(final amount in itemList(activity!['amounts']))Text('• ${money(amount,widget.listing['currency_code'].toString())}')],
    ])));
  }
}

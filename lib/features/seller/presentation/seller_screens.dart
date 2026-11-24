import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/providers.dart';
import '../../../core/localization/strings.dart';
import '../../../core/theme/marsa_theme.dart';
import '../../../core/widgets/common.dart';
import '../../marketplace/presentation/market_screens.dart';

class SellerCenterScreen extends ConsumerWidget {
  const SellerCenterScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref){
    final application=ref.watch(sellerApplicationProvider);
    return Scaffold(appBar:AppBar(title:Text(t(ref,'sellerCenter'))),body:application.when(
      loading:()=>const LoadingView(),error:(e,_)=>ErrorView(error:e,onRetry:()=>ref.invalidate(sellerApplicationProvider)),
      data:(seller){
        if(seller==null)return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.storefront_outlined,size:70,color:MarsaColors.teal),const FormSpace(),
          const Text('يمكنك الشراء كمستخدم، والتقديم كبائع معتمد لإضافة إعلاناتك.'),const FormSpace(),
          ElevatedButton(onPressed:()=>context.push('/seller/apply'),child:Text(t(ref,'applySeller')))])));
        if(seller['verification_status']!='APPROVED')return Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
          StatusPill(seller['verification_status'].toString()),const FormSpace(),
          const Text('لا يمكن نشر إعلانات قبل الموافقة من الإدارة.'),
          Text(itemMap(seller['seller_verifications'])['rejection_reason_private']?.toString()??''),
        ])));
        return FutureBuilder<List<Map<String,dynamic>>>(future:ref.read(sellerRepositoryProvider).myListings(),builder:(c,s){
          if(s.connectionState!=ConnectionState.done)return const LoadingView();
          if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>ref.invalidate(sellerApplicationProvider));
          return ListView(padding:const EdgeInsets.all(16),children:[
            ElevatedButton.icon(onPressed:()=>context.push('/seller/create'),icon:const Icon(Icons.add),label:Text(t(ref,'newListing'))),
            const FormSpace(),Text('إعلاناتي (${s.data!.length})',style:Theme.of(context).textTheme.titleLarge),
            for(final l in s.data!)Card(child:ListTile(title:Text(l['title_ar'].toString()),subtitle:Text('${l['status']} · ${l['quantity_available']} ${l['unit']}'),
              trailing:const Icon(Icons.edit_outlined),onTap:()=>context.push('/seller/edit/${l['id']}'))),
            if(s.data!.isEmpty)const EmptyState(title:'لا توجد إعلانات بعد'),
            const Divider(),OutlinedButton(onPressed:()=>context.push('/orders'),child:const Text('الطلبات الواردة / Incoming orders')),
          ]);
        });
      }));
  }
}
class SellerApplyScreen extends ConsumerStatefulWidget {
  const SellerApplyScreen({super.key});
  @override ConsumerState<SellerApplyScreen> createState()=>_SellerApplyState();
}
class _SellerApplyState extends ConsumerState<SellerApplyScreen> {
  final form=GlobalKey<FormState>();final name=TextEditingController(),description=TextEditingController();bool busy=false;
  @override void dispose(){name.dispose();description.dispose();super.dispose();}
  Future<void> apply()async{
    if(!form.currentState!.validate())return;
    setState(()=>busy=true);
    try{await ref.read(sellerRepositoryProvider).apply(name.text.trim(),description.text.trim());
      ref.invalidate(sellerApplicationProvider);if(mounted)context.go('/seller');}
    catch(e){if(mounted)showToast(context,'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'applySeller'))),
    body:SingleChildScrollView(padding:const EdgeInsets.all(18),child:Form(key:form,child:Column(children:[
      const Text('يراجع فريق الإدارة طلبات البيع. لا تشارك وثائق هوية حساسة عبر المحادثة.'),const FormSpace(),
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'اسم النشاط أو البائع'),
        validator:(v)=>(v??'').trim().length<2?'الاسم مطلوب':null),const FormSpace(),
      TextFormField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'نبذة عن النشاط')),
      const FormSpace(),ElevatedButton(onPressed:busy?null:apply,child:Text(t(ref,'applySeller'))),
    ]))));
}
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});
  @override ConsumerState<CreateListingScreen> createState()=>_CreateListingState();
}
class _CreateListingState extends ConsumerState<CreateListingScreen> {
  final form=GlobalKey<FormState>();
  final title=TextEditingController(),description=TextEditingController(),condition=TextEditingController(),quantity=TextEditingController(text:'1');
  final price=TextEditingController(),increment=TextEditingController(),reserve=TextEditingController();
  String? category,area;String unit='kg',currency='YER',mode='DIRECT';
  DateTime start=DateTime.now().add(const Duration(minutes:10));
  DateTime end=DateTime.now().add(const Duration(hours:24));
  List<XFile> images=[];bool busy=false;
  @override void dispose(){for(final x in [title,description,condition,quantity,price,increment,reserve])x.dispose();super.dispose();}
  Future<void> chooseImages()async{
    try{final picked=await ImagePicker().pickMultiImage(imageQuality:75,maxWidth:1400);
      if(mounted)setState(()=>images=picked.take(5).toList());}
    catch(e){if(mounted)showToast(context,'$e');}
  }
  Future<DateTime?> pickDate(DateTime original) async {
    final d=await showDatePicker(context:context,initialDate:original,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:30)));
    if(d==null||!mounted)return null;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(original));
    if(time==null)return null;
    return DateTime(d.year,d.month,d.day,time.hour,time.minute);
  }
  Future<void> create()async {
    if(!form.currentState!.validate()||category==null||area==null){showToast(context,'أكمل الحقول واختر الفئة والمنطقة.');return;}
    if(images.isEmpty){showToast(context,'أضف صورة واحدة على الأقل قبل إرسال الإعلان.');return;}
    if(mode=='AUCTION' && !end.isAfter(start)){showToast(context,'تاريخ نهاية المزاد غير صحيح.');return;}
    setState(()=>busy=true);
    try{
      final id=await ref.read(sellerRepositoryProvider).create({
        'p_type':mode,'p_category':category,'p_title':title.text.trim(),
        'p_description':description.text,'p_condition':condition.text,'p_area':area,
        'p_quantity':num.parse(quantity.text),'p_unit':unit,'p_currency':currency,
        'p_unit_price':mode=='DIRECT'?num.parse(price.text):null,
        'p_start_price':mode=='AUCTION'?num.parse(price.text):null,
        'p_increment':mode=='AUCTION'?num.parse(increment.text):null,
        'p_reserve':mode=='AUCTION'&&reserve.text.isNotEmpty?num.parse(reserve.text):null,
        'p_starts':mode=='AUCTION'?start.toUtc().toIso8601String():null,
        'p_ends':mode=='AUCTION'?end.toUtc().toIso8601String():null,
      });
      if(images.isNotEmpty)await ref.read(sellerRepositoryProvider).uploadImages(id,images);
      await ref.read(sellerRepositoryProvider).changeStatus(id,'PENDING_REVIEW');
      if(mounted){showToast(context,t(ref,'reviewNeeded'));context.go('/seller');}
    }catch(e){if(mounted)showToast(context,'تعذر إنشاء الإعلان: $e. إذا تم حفظ مسودة، ستجدها في مركز البائع.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'newListing'))),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      TextFormField(controller:title,decoration:InputDecoration(labelText:t(ref,'title')),validator:(v)=>(v??'').trim().length<3?'العنوان قصير':null),
      const FormSpace(),TextFormField(controller:description,decoration:InputDecoration(labelText:t(ref,'description')),maxLines:3),
      const FormSpace(),TextFormField(controller:condition,decoration:InputDecoration(labelText:t(ref,'condition'))),
      const FormSpace(),ref.watch(categoriesProvider).when(data:(rows)=>DropdownButtonFormField<String>(value:category,
        decoration:InputDecoration(labelText:t(ref,'category')),items:rows.map((r)=>DropdownMenuItem(value:r['id'].toString(),child:Text(r['name_ar'].toString()))).toList(),
        onChanged:(v)=>setState(()=>category=v)),loading:()=>const LinearProgressIndicator(),error:(e,_)=>Text('$e')),
      const FormSpace(),ref.watch(areasProvider).when(data:(rows)=>DropdownButtonFormField<String>(value:area,
        decoration:InputDecoration(labelText:t(ref,'area')),items:rows.map((r)=>DropdownMenuItem(value:r['id'].toString(),child:Text(r['name_ar'].toString()))).toList(),
        onChanged:(v)=>setState(()=>area=v)),loading:()=>const LinearProgressIndicator(),error:(e,_)=>Text('$e')),
      const FormSpace(),DropdownButtonFormField<String>(value:mode,decoration:const InputDecoration(labelText:'نوع البيع (نوع واحد للإعلان)'),
        items:const [DropdownMenuItem(value:'DIRECT',child:Text('مباشر / DIRECT')),DropdownMenuItem(value:'AUCTION',child:Text('مزاد / AUCTION'))],
        onChanged:(v)=>setState(()=>mode=v??'DIRECT')),
      const FormSpace(),TextFormField(controller:quantity,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:t(ref,'quantity')),
        validator:(v)=>(num.tryParse(v??'')??0)<=0?'كمية غير صالحة':null),
      const FormSpace(),DropdownButtonFormField<String>(value:unit,decoration:InputDecoration(labelText:t(ref,'unit')),
        items:const [DropdownMenuItem(value:'kg',child:Text('كيلوجرام / kg')),DropdownMenuItem(value:'box',child:Text('صندوق / box')),
          DropdownMenuItem(value:'piece',child:Text('قطعة / piece'))],onChanged:(v)=>setState(()=>unit=v??'kg')),
      const FormSpace(),DropdownButtonFormField<String>(value:currency,decoration:const InputDecoration(labelText:'العملة / Currency'),
        items:const [DropdownMenuItem(value:'YER',child:Text('ريال يمني YER')),DropdownMenuItem(value:'SAR',child:Text('ريال سعودي SAR')),
          DropdownMenuItem(value:'USD',child:Text('دولار أمريكي USD'))],onChanged:(v)=>setState(()=>currency=v??'YER')),
      const FormSpace(),TextFormField(controller:price,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:mode=='DIRECT'?t(ref,'price'):'سعر بداية المزاد'),
        validator:(v)=>(num.tryParse(v??'')??0)<=0?'سعر غير صالح':null),
      if(mode=='AUCTION')...[
        const FormSpace(),TextFormField(controller:increment,keyboardType:TextInputType.number,
          decoration:InputDecoration(labelText:t(ref,'minIncrement')),validator:(v)=>(num.tryParse(v??'')??0)<=0?'الزيادة مطلوبة':null),
        const FormSpace(),TextFormField(controller:reserve,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر الاحتياط (اختياري)')),
        const FormSpace(),OutlinedButton.icon(onPressed:()async{final d=await pickDate(start);if(d!=null)setState(()=>start=d);},
          icon:const Icon(Icons.access_time),label:Text('${t(ref,'start')}: $start')),
        const FormSpace(),OutlinedButton.icon(onPressed:()async{final d=await pickDate(end);if(d!=null)setState(()=>end=d);},
          icon:const Icon(Icons.event),label:Text('${t(ref,'end')}: $end')),
      ],
      const FormSpace(),OutlinedButton.icon(onPressed:chooseImages,icon:const Icon(Icons.add_photo_alternate_outlined),
        label:Text('${t(ref,'upload')} (${images.length}/5)')),
      if(images.isNotEmpty)Text(images.map((f)=>f.name).join(' · '),maxLines:3),
      const FormSpace(),const Text('يُحفظ الإعلان كمسودة ثم يُرسل للمراجعة الإدارية. لا تذكر معلومات غير مؤكدة عن الطزاجة.'),
      const FormSpace(),ElevatedButton(onPressed:busy?null:create,child:Text(busy?t(ref,'loading'):t(ref,'publish'))),
      const SizedBox(height:30),
    ]))));
}

class SellerEditScreen extends ConsumerStatefulWidget {
  const SellerEditScreen({super.key,required this.id});final String id;
  @override ConsumerState<SellerEditScreen> createState()=>_SellerEditState();
}
class _SellerEditState extends ConsumerState<SellerEditScreen> {
  late Future<Map<String,dynamic>> future;
  final title=TextEditingController(),description=TextEditingController(),delta=TextEditingController(),price=TextEditingController();
  bool initialized=false,working=false;
  @override void initState(){super.initState();future=ref.read(marketRepositoryProvider).listing(widget.id);}
  @override void dispose(){title.dispose();description.dispose();delta.dispose();price.dispose();super.dispose();}
  Future<void> execute(Future<void> Function() callback)async{
    setState(()=>working=true);
    try{await callback();if(mounted){showToast(context,'تم الحفظ');setState(()=>future=ref.read(marketRepositoryProvider).listing(widget.id));}}
    catch(e){if(mounted)showToast(context,'$e');}
    finally{if(mounted)setState(()=>working=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تعديل الإعلان')),
    body:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(()=>future=ref.read(marketRepositoryProvider).listing(widget.id)));
      final l=s.data!;if(!initialized){title.text=l['title_ar'].toString();description.text=l['description']?.toString()??'';initialized=true;}
      final isDirect=l['sale_type']=='DIRECT',status=l['status'].toString();
      return ListView(padding:const EdgeInsets.all(16),children:[
        Text('الحالة: $status'),const FormSpace(),TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان الإعلان')),
        const FormSpace(),TextField(controller:description,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
        const FormSpace(),ElevatedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).updateListing(widget.id,
          {'title_ar':title.text,'description':description.text})),child:Text(t(ref,'save'))),
        if(isDirect)...[const FormSpace(),TextField(controller:delta,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),
          decoration:const InputDecoration(labelText:'تعديل المخزون (+/-)')),
          OutlinedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).adjustStock(widget.id,num.parse(delta.text))),child:const Text('حفظ المخزون')),
          const FormSpace(),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر الوحدة الجديد')),
          OutlinedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changePrice(widget.id,num.parse(price.text))),child:const Text('تحديث السعر'))],
        const FormSpace(),if(status=='DRAFT')ElevatedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changeStatus(widget.id,'PENDING_REVIEW')),
          child:Text(t(ref,'publish'))),
        if(status=='ACTIVE')OutlinedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changeStatus(widget.id,'PAUSED')),
          child:const Text('إيقاف مؤقت / Pause')),
        if(status=='PAUSED')ElevatedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changeStatus(widget.id,'ACTIVE')),
          child:const Text('إعادة النشر / Resume')),
        if(['ACTIVE','PAUSED','SOLD_OUT'].contains(status))OutlinedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changeStatus(widget.id,'CLOSED')),
          child:const Text('إغلاق الإعلان / Close')),
        if(status=='REJECTED')OutlinedButton(onPressed:working?null:()=>execute(()=>ref.read(sellerRepositoryProvider).changeStatus(widget.id,'DRAFT')),
          child:const Text('إعادة لمسودة / Revise')),
      ]);
    }));
}

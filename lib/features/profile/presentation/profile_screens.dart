import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/shell.dart';
import '../../../core/localization/strings.dart';
import '../../../core/widgets/common.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref){
    final auth=ref.read(authRepositoryProvider);
    return MarsaShell(selected:4,child:auth.user==null?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.person_outline,size:64),const SizedBox(height:14),
      ElevatedButton(onPressed:()=>context.push('/login'),child:Text(t(ref,'login'))),
      TextButton(onPressed:()=>context.push('/signup'),child:Text(t(ref,'signup'))),
      TextButton(onPressed:()=>context.push('/help'),child:Text(t(ref,'support'))),
    ])):ref.watch(profileProvider).when(loading:()=>const LoadingView(),
      error:(e,_)=>ErrorView(error:e,onRetry:()=>ref.invalidate(profileProvider)),data:(profile)=>ListView(padding:const EdgeInsets.all(16),children:[
        const CircleAvatar(radius:34,child:Icon(Icons.person,size:40)),const FormSpace(),
        Center(child:Text(profile?['display_name']?.toString()??'مرسى',style:Theme.of(context).textTheme.titleLarge)),
        Center(child:Text(auth.user?.email??'')),const FormSpace(),
        Card(child:ListTile(leading:const Icon(Icons.edit_outlined),title:const Text('تعديل الملف الشخصي'),onTap:()=>_showEdit(context,ref,profile))),
        Card(child:ListTile(leading:const Icon(Icons.storefront_outlined),title:Text(t(ref,'sellerCenter')),onTap:()=>context.push('/seller'))),
        Card(child:ListTile(leading:const Icon(Icons.translate),title:Text(t(ref,'language')),
          subtitle:Text(ref.watch(languageProvider)=='ar'?'العربية':'English'),
          onTap:(){final next=ref.read(languageProvider)=='ar'?'en':'ar';
            ref.read(languageProvider.notifier).state=next;
            auth.updateProfile({'preferred_language':next}).catchError((Object _){return;});})),
        Card(child:ListTile(leading:const Icon(Icons.notifications_none),title:Text(t(ref,'notifications')),onTap:()=>context.push('/notifications'))),
        ref.watch(isAdminProvider).when(data:(allowed)=>allowed?Card(child:ListTile(leading:const Icon(Icons.admin_panel_settings_outlined),
          title:Text(t(ref,'admin')),onTap:()=>context.push('/admin'))):const SizedBox.shrink(),
          loading:()=>const SizedBox.shrink(),error:(_,__)=>const SizedBox.shrink()),
        Card(child:ListTile(leading:const Icon(Icons.help_outline),title:Text(t(ref,'support')),onTap:()=>context.push('/help'))),
        const FormSpace(),OutlinedButton.icon(onPressed:()async{await auth.signOut();
          ref.invalidate(profileProvider);ref.invalidate(isAdminProvider);if(context.mounted)context.go('/');},
          icon:const Icon(Icons.logout),label:Text(t(ref,'logout'))),
      ])));
  }
  Future<void> _showEdit(BuildContext context,WidgetRef ref,Map<String,dynamic>? profile) async {
    final name=TextEditingController(text:profile?['display_name']?.toString()??'');
    final phone=TextEditingController(text:profile?['phone_private']?.toString()??'');
    String? area=profile?['area_id']?.toString();
    final accepted=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setModal)=>AlertDialog(
      title:const Text('الملف الشخصي'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),const FormSpace(),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم الهاتف (خاص، اختياري)')),
        const FormSpace(),ref.watch(areasProvider).when(data:(rows)=>DropdownButtonFormField<String>(value:area,
          decoration:const InputDecoration(labelText:'منطقة عدن'),items:rows.map((r)=>DropdownMenuItem<String>(
            value:r['id'].toString(),child:Text(r['name_ar'].toString()))).toList(),onChanged:(v)=>setModal(()=>area=v)),
          loading:()=>const LinearProgressIndicator(),error:(e,_)=>Text('$e')),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),
        ElevatedButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حفظ'))])));
    if(accepted==true){
      final cleaned=phone.text.trim();
      if(cleaned.isNotEmpty&&!RegExp(r'^\+?967[0-9]{8,10}$|^[0-9]{9}$').hasMatch(cleaned)){
        if(context.mounted)showToast(context,'صيغة رقم الهاتف غير صحيحة');
      }else{
        try{await ref.read(authRepositoryProvider).updateProfile({'display_name':name.text.trim(),
          'phone_private':cleaned.isEmpty?null:cleaned,'area_id':area});ref.invalidate(profileProvider);
          if(context.mounted)showToast(context,'تم حفظ الملف الشخصي');}
        catch(e){if(context.mounted)showToast(context,'$e');}
      }
    }
    name.dispose();phone.dispose();
  }
}

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref)=>Scaffold(appBar:AppBar(title:Text(t(ref,'support'))),
    body:ListView(padding:const EdgeInsets.all(20),children:const [
      Text('حول مرسى | About MARSA',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      SizedBox(height:8),Text('مرسى سوق للمأكولات البحرية في محافظة عدن. يجمع المشترين والبائعين المعتمدين ويدعم البيع المباشر والمزادات.'),
      Divider(),Text('قواعد السوق / Marketplace rules',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('الإعلانات مقتصرة على المأكولات البحرية. يتحمل البائع مسؤولية دقة معلومات عرضه. لا تنشر بيانات حساسة أو محتوى مخالفاً.'),
      Divider(),Text('قواعد المزاد / Auction rules',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('المزايدات ملزمة وفق الاتفاق بين الطرفين. يتحقق الخادم من توقيت المزايدات وقيمتها. عدم بلوغ سعر الاحتياط يعني عدم وجود فائز. مهلة الفائز 48 ساعة ما لم يغير المسؤول السياسات.'),
      Divider(),Text('الخصوصية / Privacy',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('البريد والهاتف وبيانات التحقق ليست عامة. لا تخزن مرسى معلومات الدفع الإلكتروني. لا ترسل وثائق هوية عبر الدردشة. يمكن الإبلاغ عن إساءة الاستخدام.'),
      Divider(),Text('الشروط والسلامة / Terms and safety',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('اتفق على طريقة التسليم والسعر والنوع قبل التبادل. افحص سلامة المنتجات بنفسك. لا توجد خدمة شحن تابعة لمرسى أو ضمان مالي أو خدمة وسيط حفظ أموال.'),
      Divider(),Text('الدعم / Contact',style:TextStyle(fontWeight:FontWeight.bold)),
      Text('لتقديم بلاغ حول إعلان أو طلب، استخدم زر «إبلاغ» داخل التطبيق. يجب إعداد قناة دعم رسمية قبل النشر التجاري.'),
    ]));
}

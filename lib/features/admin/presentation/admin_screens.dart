import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/widgets/common.dart';
import '../../../core/localization/strings.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override ConsumerState<AdminScreen> createState()=>_AdminState();
}
class _AdminState extends ConsumerState<AdminScreen> {
  int tab=0;String? pendingError;
  Future<void> action(Future<void> Function() fn) async {
    try{await fn();if(mounted){setState((){});showToast(context,'تم تنفيذ الإجراء');}}
    catch(e){if(mounted)showToast(context,'رفض الخادم: $e');}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'admin'))),
    body:ref.watch(isAdminProvider).when(
      loading:()=>const LoadingView(),error:(e,_)=>ErrorView(error:e,onRetry:()=>ref.invalidate(isAdminProvider)),
      data:(allowed){if(!allowed)return const EmptyState(title:'لا تملك صلاحية الإدارة.');
        return Column(children:[SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
          for(final pair in const [(0,'البائعون'),(1,'الإعلانات'),(2,'البلاغات'),(3,'الفئات'),(4,'المناطق'),(5,'التدقيق'),(6,'الحسابات')])
            Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:ChoiceChip(label:Text(pair.$2),selected:tab==pair.$1,onSelected:(_)=>setState(()=>tab=pair.$1))),
        ])),Expanded(child:Builder(builder:(context){switch(tab){
          case 0:return _queue(ref.read(adminRepositoryProvider).pendingSellers(),(r)=>Card(child:Column(children:[
            ListTile(title:Text(r['business_name'].toString()),subtitle:Text(r['description'].toString())),
            Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).seller(r['user_id'].toString(),'APPROVED')),child:const Text('اعتماد')),
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).seller(r['user_id'].toString(),'REJECTED',reason:'بيانات التحقق غير مكتملة')),child:const Text('رفض')),
            ])])));
          case 1:return _queue(ref.read(adminRepositoryProvider).pendingListings(),(r)=>Card(child:Column(children:[
            ListTile(title:Text(r['title_ar'].toString()),subtitle:Text(r['sale_type'].toString())),
            Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).listing(r['id'].toString(),'ACTIVE')),child:const Text('نشر')),
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).listing(r['id'].toString(),'REJECTED')),child:const Text('رفض')),
            ])])));
          case 2:return _queue(ref.read(adminRepositoryProvider).reports(),(r)=>Card(child:Column(children:[
            ListTile(title:Text('${r['target_type']}: ${r['reason']}'),subtitle:Text(r['target_id'].toString())),
            Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
              if(r['target_type']=='ORDER')TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).disputeOrder(r['target_id'].toString())),child:const Text('فتح نزاع')),
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).report(r['id'].toString(),'RESOLVED','تمت مراجعة البلاغ')),child:const Text('معالجة')),
              TextButton(onPressed:()=>action(()=>ref.read(adminRepositoryProvider).report(r['id'].toString(),'DISMISSED','لا توجد مخالفة مثبتة')),child:const Text('إغلاق')),
            ])])));
          case 3:return _referenceTable('CATEGORY');
          case 4:return _referenceTable('AREA');
          case 5:return _queue(ref.read(adminRepositoryProvider).audit(),(r)=>Card(child:ListTile(title:Text(r['action'].toString()),
            subtitle:Text('${r['entity_type']} · ${r['created_at']}'))));
          case 6:return _AccountStatusEditor(onSave:(uid,status)=>action(()=>ref.read(adminRepositoryProvider).account(uid,status)));
          default:return const SizedBox.shrink();
        }}))]);
      }));
  Widget _queue(Future<List<Map<String,dynamic>>> future,Widget Function(Map<String,dynamic>) renderer)=>FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
    if(s.connectionState!=ConnectionState.done)return const LoadingView();
    if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState((){}));
    if(s.data!.isEmpty)return const EmptyState();
    return RefreshIndicator(onRefresh:()async{setState((){});},child:ListView(padding:const EdgeInsets.all(14),children:s.data!.map(renderer).toList()));
  });
  Widget _referenceTable(String kind){
    final future=ref.read(adminRepositoryProvider).referenceRecords(kind);
    return FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState((){}));
      return ListView(padding:const EdgeInsets.all(16),children:[
        ElevatedButton.icon(onPressed:()=>_editReference(kind,null),icon:const Icon(Icons.add),label:const Text('إضافة سجل')),
        for(final row in s.data!)ListTile(title:Text(row['name_ar'].toString()),subtitle:Text(row['name_en'].toString()),
          onTap:()=>_editReference(kind,row),trailing:const Icon(Icons.edit)),
      ]);
    });
  }
  Future<void> _editReference(String kind,Map<String,dynamic>? row) async {
    final ar=TextEditingController(text:row?['name_ar']?.toString()??'');
    final en=TextEditingController(text:row?['name_en']?.toString()??'');
    bool active=row?['is_active']==false?false:true;
    final confirm=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,setDialog)=>AlertDialog(
      title:Text(kind=='AREA'?'منطقة عدن':'فئة بحرية'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:ar,decoration:const InputDecoration(labelText:'الاسم العربي')),
        const FormSpace(),TextField(controller:en,decoration:const InputDecoration(labelText:'English name')),
        SwitchListTile(title:const Text('مفعّل'),value:active,onChanged:(v)=>setDialog(()=>active=v)),
      ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),
        ElevatedButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))])));
    if(confirm==true)await action(()=>ref.read(adminRepositoryProvider).reference(
      type:kind,id:row?['id']?.toString(),arabic:ar.text,english:en.text,active:active,order:row?['sort_order'] as int? ??0));
    ar.dispose();en.dispose();
    ref.invalidate(categoriesProvider);ref.invalidate(areasProvider);
  }
}

class _AccountStatusEditor extends StatefulWidget {
  const _AccountStatusEditor({required this.onSave});
  final void Function(String uid,String status) onSave;
  @override State<_AccountStatusEditor> createState()=>_AccountStatusEditorState();
}
class _AccountStatusEditorState extends State<_AccountStatusEditor> {
  final uid=TextEditingController();String status='SUSPENDED';
  @override void dispose(){uid.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const Text('إيقاف / استعادة حساب باستخدام معرف المستخدم UUID. الصلاحية تُتحقق على الخادم.'),
    const FormSpace(),TextField(controller:uid,decoration:const InputDecoration(labelText:'User UUID')),
    const FormSpace(),DropdownButtonFormField<String>(value:status,items:const [
      DropdownMenuItem(value:'SUSPENDED',child:Text('إيقاف')),DropdownMenuItem(value:'ACTIVE',child:Text('استعادة'))],
      onChanged:(v)=>setState(()=>status=v??'SUSPENDED')),
    const FormSpace(),ElevatedButton(onPressed:()=>widget.onSave(uid.text.trim(),status),child:const Text('تنفيذ')),
  ]));
}

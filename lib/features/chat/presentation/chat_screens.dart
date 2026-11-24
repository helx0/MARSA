import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/shell.dart';
import '../../../core/localization/strings.dart';
import '../../../core/theme/marsa_theme.dart';
import '../../../core/widgets/common.dart';
import '../../marketplace/presentation/market_screens.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});
  @override ConsumerState<InboxScreen> createState()=>_InboxState();
}
class _InboxState extends ConsumerState<InboxScreen> {
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();reload();}
  void reload(){future=ref.read(chatRepositoryProvider).mine();}
  @override Widget build(BuildContext context)=>MarsaShell(selected:3,child:RefreshIndicator(onRefresh:()async{
    setState(reload);await future;
  },child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(context,s){
    if(s.connectionState!=ConnectionState.done)return const LoadingView();
    if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
    if(s.data!.isEmpty)return EmptyState(title:t(ref,'empty'),icon:Icons.forum_outlined);
    return ListView(padding:const EdgeInsets.all(16),children:[for(final c in s.data!)Card(child:ListTile(
      leading:const CircleAvatar(child:Icon(Icons.chat_outlined)),
      title:Text(itemMap(c['listings'])['title_ar']?.toString()??'محادثة بخصوص إعلان'),
      subtitle:Text(c['created_at'].toString()),
      onTap:()=>context.push('/conversation/${c['id']}'),trailing:const Icon(Icons.chevron_right)))]);
  })));
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key,required this.id});final String id;
  @override ConsumerState<ConversationScreen> createState()=>_ConversationState();
}
class _ConversationState extends ConsumerState<ConversationScreen> {
  final text=TextEditingController();bool busy=false;
  late Future<List<Map<String,dynamic>>> future;
  @override void initState(){super.initState();reload();}
  @override void dispose(){text.dispose();super.dispose();}
  void reload(){future=ref.read(chatRepositoryProvider).messages(widget.id);}
  Future<void> send() async {
    if(text.text.trim().isEmpty)return;
    setState(()=>busy=true);
    try{await ref.read(chatRepositoryProvider).send(widget.id,text.text.trim());text.clear();if(mounted)setState(reload);}
    catch(e){if(mounted)showToast(context,'$e');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> messageAction(String otherId,String messageId)async{
    final action=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:const Icon(Icons.block),title:Text(t(ref,'block')),onTap:()=>Navigator.pop(c,'block')),
      ListTile(leading:const Icon(Icons.flag),title:Text(t(ref,'report')),onTap:()=>Navigator.pop(c,'report')),
    ])));
    if(action==null)return;
    try{
      if(action=='block')await ref.read(chatRepositoryProvider).block(otherId);
      if(action=='report')await ref.read(communityRepositoryProvider).report('MESSAGE',messageId,'رسالة غير ملائمة أو مزعجة');
      if(mounted)showToast(context,'تم تسجيل الإجراء');
    }catch(e){if(mounted)showToast(context,'$e');}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(t(ref,'chat')),
    actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:()=>setState(reload))]),
    body:Column(children:[Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:future,builder:(c,s){
      if(s.connectionState!=ConnectionState.done)return const LoadingView();
      if(s.hasError)return ErrorView(error:s.error!,onRetry:()=>setState(reload));
      final messages=s.data!;
      if(messages.isEmpty)return const EmptyState(title:'ابدأ محادثة خاصة مع البائع.');
      final me=ref.read(authRepositoryProvider).user?.id;
      return ListView.builder(reverse:true,padding:const EdgeInsets.all(14),itemCount:messages.length,itemBuilder:(c,index){
        final msg=messages[messages.length-index-1],mine=msg['sender_id']==me;
        return Align(alignment:mine?AlignmentDirectional.centerEnd:AlignmentDirectional.centerStart,
          child:GestureDetector(onLongPress:mine?null:()=>messageAction(msg['sender_id'].toString(),msg['id'].toString()),
            child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.80),
              margin:const EdgeInsets.symmetric(vertical:4),padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:mine?MarsaColors.seafoam:Colors.white,borderRadius:BorderRadius.circular(14)),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(msg['body'].toString()),
                Text(msg['created_at'].toString(),style:const TextStyle(fontSize:10,color:MarsaColors.muted))]))));
      });
    })),SafeArea(child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
      Expanded(child:TextField(controller:text,maxLines:3,minLines:1,maxLength:2000,
        decoration:InputDecoration(hintText:t(ref,'writeMessage'),counterText:''))),const SizedBox(width:8),
      IconButton.filled(onPressed:busy?null:send,icon:const Icon(Icons.send)),
    ])))]));
}

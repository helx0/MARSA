import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/providers.dart';
import '../../../core/localization/strings.dart';
import '../../../core/theme/marsa_theme.dart';
import '../../../core/widgets/common.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});
  @override State<LaunchScreen> createState()=>_LaunchState();
}
class _LaunchState extends State<LaunchScreen> {
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){_open();});}
  Future<void> _open() async {
    final prefs=await SharedPreferences.getInstance();
    if(mounted) context.go(prefs.getBool('onboarding_seen')==true?'/':'/intro');
  }
  @override Widget build(BuildContext context)=>const Scaffold(body:Center(child:Column(
    mainAxisSize:MainAxisSize.min,children:[Icon(Icons.sailing,size:76,color:MarsaColors.teal),SizedBox(height:16),
    Text('مرسى | MARSA',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800,color:MarsaColors.navy)),
    SizedBox(height:20),CircularProgressIndicator()])));
}
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState()=>_IntroState();
}
class _IntroState extends State<OnboardingScreen> {
  int index=0; final controller=PageController();
  Future<void> done() async {await (await SharedPreferences.getInstance()).setBool('onboarding_seen',true);if(mounted)context.go('/');}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Padding(padding:const EdgeInsets.all(24),
    child:Column(children:[Align(alignment:AlignmentDirectional.centerEnd,child:TextButton(onPressed:done,child:const Text('تخطى / Skip'))),
      Expanded(child:PageView(controller:controller,onPageChanged:(v)=>setState(()=>index=v),children:const [
        _IntroPanel(Icons.set_meal_outlined,'اكتشف خيرات البحر','تصفح أسماك ومأكولات بحرية معروضة من بائعين في عدن.'),
        _IntroPanel(Icons.storefront_outlined,'بع في مرسى','قدم طلب اعتماد البائع وأضف إعلاناتك بعد الموافقة.'),
        _IntroPanel(Icons.gavel_outlined,'شارك في المزادات','زايد بأمان، والخادم يتحقق من الأسعار والتوقيت.'),
      ])),
      Text('${index+1} / 3'),const SizedBox(height:12),
      SizedBox(width:double.infinity,child:ElevatedButton(onPressed:(){if(index==2)done();else controller.nextPage(duration:const Duration(milliseconds:250),curve:Curves.easeOut);},child:Text(index==2?'ابدأ / Start':'التالي / Next'))),
    ]))));
}
class _IntroPanel extends StatelessWidget {
  const _IntroPanel(this.icon,this.title,this.subtitle);
  final IconData icon;final String title,subtitle;
  @override Widget build(BuildContext context)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    CircleAvatar(radius:70,backgroundColor:MarsaColors.seafoam,child:Icon(icon,size:72,color:MarsaColors.teal)),
    const SizedBox(height:35),Text(title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    const SizedBox(height:16),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(fontSize:16)),
  ]);
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key,required this.mode});final String mode;
  @override ConsumerState<AuthScreen> createState()=>_AuthState();
}
class _AuthState extends ConsumerState<AuthScreen> {
  final form=GlobalKey<FormState>();final email=TextEditingController();final password=TextEditingController();final name=TextEditingController();
  bool working=false;
  @override void dispose(){email.dispose();password.dispose();name.dispose();super.dispose();}
  Future<void> submit() async {
    if(!form.currentState!.validate())return;
    setState(()=>working=true);
    try{
      final auth=ref.read(authRepositoryProvider);
      if(widget.mode=='newPassword'){await auth.changePassword(password.text);if(mounted){showToast(context,'تم تحديث كلمة المرور.');context.go('/');}}
      else if(widget.mode=='login'){await auth.signIn(email.text,password.text);if(mounted)context.go('/');}
      else if(widget.mode=='signup'){
        await auth.signUp(email.text,password.text,name.text);
        if(mounted){showToast(context,'تم إرسال طلب التسجيل؛ تحقق من البريد الإلكتروني إذا كان التفعيل مطلوباً.');context.go('/login');}
      } else {await auth.resetPassword(email.text);if(mounted)showToast(context,'إذا كان البريد مسجلاً، ستصلك تعليمات الاستعادة.');}
    }catch(e){if(mounted)showToast(context,'تعذر إكمال العملية: $e');}
    finally{if(mounted)setState(()=>working=false);}
  }
  @override Widget build(BuildContext context){
    final signup=widget.mode=='signup',reset=widget.mode=='reset',newPassword=widget.mode=='newPassword';
    return Scaffold(appBar:AppBar(title:Text(newPassword?'تعيين كلمة مرور جديدة':reset?t(ref,'reset'):signup?t(ref,'signup'):t(ref,'login'))),
      body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),
        child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Icon(Icons.sailing,color:MarsaColors.navy,size:72),const SizedBox(height:20),
          if(signup)...[TextFormField(controller:name,decoration:InputDecoration(labelText:t(ref,'name')),
            validator:(v)=>(v??'').trim().length<2?'الاسم مطلوب':null),const FormSpace()],
          if(!newPassword)TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:InputDecoration(labelText:t(ref,'email')),
            validator:(v)=>!(v??'').contains('@')?'بريد إلكتروني غير صالح':null),const FormSpace(),
          if(!reset)...[TextFormField(controller:password,obscureText:true,decoration:InputDecoration(labelText:t(ref,'password')),
            validator:(v)=>(v??'').length<8?'استخدم 8 أحرف على الأقل':null),const FormSpace()],
          ElevatedButton(onPressed:working?null:submit,child:Text(working?t(ref,'loading'):newPassword?'حفظ كلمة المرور':reset?t(ref,'reset'):signup?t(ref,'signup'):t(ref,'login'))),
          const SizedBox(height:12),if(!reset && !newPassword)TextButton(onPressed:()=>context.go(signup?'/login':'/signup'),child:Text(signup?t(ref,'login'):t(ref,'signup'))),
          if(!signup && !reset && !newPassword)TextButton(onPressed:()=>context.push('/reset'),child:Text(t(ref,'reset'))),
          const SizedBox(height:12),const Text('بيانات التواصل الخاصة بك ليست عامة. باستخدام مرسى توافق على قواعد السوق والخصوصية.',textAlign:TextAlign.center),
        ]))))));
  }
}

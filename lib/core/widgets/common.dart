import 'package:flutter/material.dart';
import '../theme/marsa_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.title='لا توجد بيانات',this.icon=Icons.inbox_outlined});
  final String title;
  final IconData icon;
  @override Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: MarsaColors.muted, size: 55), const SizedBox(height: 12), Text(title,textAlign:TextAlign.center),
    ])));
}
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
class ErrorView extends StatelessWidget {
  const ErrorView({super.key,required this.error,required this.onRetry});
  final Object error; final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),child: Column(mainAxisSize:MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_outlined,size:44,color:MarsaColors.coral),const SizedBox(height:12),
    SelectableText(error.toString(),textAlign:TextAlign.center),const SizedBox(height:12),
    OutlinedButton.icon(onPressed:onRetry,icon:const Icon(Icons.refresh),label:const Text('إعادة المحاولة / Retry')),
  ])));
}
void showToast(BuildContext context,String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),behavior:SnackBarBehavior.floating));
}
String money(dynamic value,String currency) => '${value ?? '—'} $currency';
class StatusPill extends StatelessWidget {
  const StatusPill(this.value,{super.key});final String value;
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
    decoration:BoxDecoration(color:MarsaColors.seafoam,borderRadius:BorderRadius.circular(20)),
    child:Text(value,style:const TextStyle(fontSize:12,color:MarsaColors.navy,fontWeight:FontWeight.w600)));
}
class FormSpace extends StatelessWidget {
  const FormSpace({super.key});
  @override Widget build(BuildContext context)=>const SizedBox(height:12);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/strings.dart';
import '../core/theme/marsa_theme.dart';

class MarsaShell extends ConsumerWidget {
  const MarsaShell({super.key,required this.selected,required this.child,this.title});
  final int selected;final Widget child;final String? title;
  @override Widget build(BuildContext context,WidgetRef ref){
    final paths=['/','/favorites','/orders','/inbox','/profile'];
    return Scaffold(
      appBar:AppBar(title:Text(title??t(ref,'app'),style:const TextStyle(fontWeight:FontWeight.w800)),
        actions:[IconButton(tooltip:t(ref,'notifications'),icon:const Icon(Icons.notifications_outlined),onPressed:()=>context.push('/notifications'))]),
      body:SafeArea(child:child),
      bottomNavigationBar:NavigationBar(selectedIndex:selected,indicatorColor:MarsaColors.seafoam,
        onDestinationSelected:(index)=>context.go(paths[index]),
        destinations:[
          NavigationDestination(icon:const Icon(Icons.storefront_outlined),selectedIcon:const Icon(Icons.storefront),label:t(ref,'home')),
          NavigationDestination(icon:const Icon(Icons.favorite_border),selectedIcon:const Icon(Icons.favorite),label:t(ref,'favorites')),
          NavigationDestination(icon:const Icon(Icons.receipt_long_outlined),label:t(ref,'orders')),
          NavigationDestination(icon:const Icon(Icons.chat_bubble_outline),label:t(ref,'chat')),
          NavigationDestination(icon:const Icon(Icons.person_outline),label:t(ref,'profile')),
        ]),
    );
  }
}

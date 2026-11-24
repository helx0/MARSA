import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:marsa/app/marsa_app.dart';
import 'package:marsa/core/config/environment.dart';

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('app opens with configured development Supabase', (tester) async {
    // Missing staging credentials must FAIL, not silently skip an integration test.
    expect(AppEnvironment.isConfigured,isTrue,reason:'Supply staging SUPABASE_URL and SUPABASE_ANON_KEY to run this integration test.');
    await Supabase.initialize(url:AppEnvironment.supabaseUrl,anonKey:AppEnvironment.supabaseAnonKey);
    await tester.pumpWidget(const ProviderScope(child:MarsaApp()));
    await tester.pump(const Duration(milliseconds:350));
    expect(find.byType(MarsaApp),findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/marsa_app.dart';
import 'core/config/environment.dart';
import 'core/theme/marsa_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!AppEnvironment.isConfigured) {
    runApp(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: marsaTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFFEDF6F9),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sailing, size: 80, color: Color(0xFF002A32)),
                      const SizedBox(height: 24),
                      const Text(
                        'مرسى | MARSA',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF002A32)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'مرحباً بك في وضع المعاينة. للتشغيل الكامل، يرجى إعداد Supabase.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Color(0xFF8D99AE)),
                      ),
                      const SizedBox(height: 32),
                      const _MockStartButton(),
                      const SizedBox(height: 16),
                      const SelectableText(
                        'لتفعيل البيئة الحقيقية:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_ANON_KEY=...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: AppEnvironment.supabaseUrl, anonKey: AppEnvironment.supabaseAnonKey);
    runApp(const ProviderScope(child: MarsaApp()));
  } catch (error) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: SelectableText('خطأ في إعداد Supabase: $error')))));
  }
}

class _MockStartButton extends StatelessWidget {
  const _MockStartButton();
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
        minimumSize: const Size(200, 50),
      ),
      onPressed: () {
        runApp(const ProviderScope(child: MarsaApp()));
      },
      child: const Text('دخول وضع التجربة (مشاهدة الواجهات)'),
    );
  }
}

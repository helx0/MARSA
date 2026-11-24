import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marsa/core/config/environment.dart';
import 'package:marsa/main.dart' as marsa;

void main() {
  testWidgets('MARSA shows backend configuration message', (tester) async {
    expect(
      AppEnvironment.isConfigured,
      isFalse,
      reason: 'Run this test without Supabase dart-defines.',
    );

    await marsa.main();
    await tester.pump();

    final message = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );

    expect(message.data, contains('لتفعيل البيئة الحقيقية'));
  });
}

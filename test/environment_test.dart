import 'package:flutter_test/flutter_test.dart';
import 'package:marsa/core/config/environment.dart';

void main(){
  test('missing backend configuration does not silently enable transactions',(){
    if(AppEnvironment.supabaseAnonKey.isEmpty){
      expect(AppEnvironment.isConfigured,isFalse);
    }
  });
}

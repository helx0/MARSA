import 'package:flutter_test/flutter_test.dart';
import 'package:marsa/core/localization/strings.dart';
import 'package:marsa/core/theme/marsa_theme.dart';

void main(){
  test('localized core actions are available',(){
    expect(tr('ar','buy'),'اطلب الآن');
    expect(tr('en','buy'),'Order now');
    expect(tr('ar','bid'),'زايد الآن');
  });
  test('design color matches specification',(){
    expect(MarsaColors.navy.toARGB32(),0xFF073B4C);
    expect(MarsaColors.teal.toARGB32(),0xFF0E7C86);
  });
}

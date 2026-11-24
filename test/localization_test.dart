import 'package:flutter_test/flutter_test.dart';
import 'package:marsa/core/localization/strings.dart';
import 'package:marsa/core/theme/marsa_theme.dart';

void main() {
  test('localized core actions are available', () {
    expect(tr('ar', 'buy'), 'اطلب الآن');
    expect(tr('en', 'buy'), 'Order now');
    expect(tr('ar', 'bid'), 'زايد الآن');
  });

  test('design colors match the documented brand palette', () {
    expect(MarsaColors.navy.toARGB32(), 0xFF073B4C);
    expect(MarsaColors.teal.toARGB32(), 0xFF0E7C86);
    expect(MarsaColors.turquoise.toARGB32(), 0xFF22B8B0);
    expect(MarsaColors.seafoam.toARGB32(), 0xFFDFF3EF);
    expect(MarsaColors.sand.toARGB32(), 0xFFF4EBDD);
    expect(MarsaColors.coral.toARGB32(), 0xFFF0785A);
    expect(MarsaColors.slate.toARGB32(), 0xFF20343B);
    expect(MarsaColors.muted.toARGB32(), 0xFF6B7C82);
  });
}

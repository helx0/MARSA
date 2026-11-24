# MARSA — تقرير التحقق الهندسي المستقل (المرحلة الثانية)

**التاريخ:** 19 نوفمبر 2026  
**المشروع:** `MARSA/`  
**الحكم الحالي:** **لم يثبت نجاح بناء Flutter أو تشغيله أو تفعيل قاعدة البيانات.** لم يُنشأ APK. تم تنفيذ مراجعة وتصحيحات على المصدر واختبارات مصدرية فقط.

## 1. فحص البيئة ومحاولات التنفيذ الفعلية

تم فك الأرشيف السابق وفحص ملفات المشروع، ثم تشغيل الأوامر الستة المطلوبة فعلياً في بيئة التنفيذ الحالية. **جميع أوامر Flutter/Dart أعادت رمز الخروج 127** ورسالة `command not found`: لا يتوفر Flutter SDK ولا Dart SDK. جرّبت Gradle Wrapper أيضاً، فبدأ تشغيل Java لكنه لم يتمكن من الوصول إلى `services.gradle.org` بسبب فشل DNS. لا تتوفر حزم Android SDK أو `adb` أو Android Studio أو محاكي Android، ولا PostgreSQL أو Supabase CLI أو Docker أو مفاتيح مشروع Supabase تجريبي. نسخة Java المتاحة هي **OpenJDK 21.0.12.1**، ولا يوجد إصدار Flutter/Dart قابل للتسجيل أو الادعاء بأنه مختبر.

## 2. جدول الاختبارات والأدلة

| Test | Command | Result | Evidence | Remaining Issues |
|---|---|---|---|---|
| Flutter doctor | `flutter doctor -v` | **BLOCKED — exit 127** | `verification/evidence/flutter_doctor__v.log` | Flutter SDK غير متاح |
| Package resolution | `flutter pub get` | **BLOCKED — exit 127** | `verification/evidence/flutter_pub_get.log` | لا يوجد `pubspec.lock`، والشبكة غير متاحة |
| Dart formatter | `dart format .` | **BLOCKED — exit 127** | `verification/evidence/dart_format__.log` | لم تتم إعادة تنسيق Dart رسمياً |
| Dart analysis | `flutter analyze` | **BLOCKED — exit 127** | `verification/evidence/flutter_analyze.log` | فحص أنواع Dart وواجهات المكتبات لم يُنفذ |
| Flutter automated tests | `flutter test` | **BLOCKED — exit 127** | `verification/evidence/flutter_test.log` | اختبارات Flutter لم تُنفذ |
| Debug APK | `flutter build apk --debug` | **BLOCKED — exit 127** | `verification/evidence/flutter_build_apk___debug.log` | APK غير متوفر |
| Gradle bootstrap | `cd android && ./gradlew --version` | **FAILED — exit 1** | `verification/evidence/gradle_wrapper_attempt.log` | DNS: `services.gradle.org` |
| Gradle Java class | `javac -d <temp> .../GradleWrapperMain.java` | **PASS** | `verification/evidence/gradle_java_compile.log` | ليس بناء Gradle أو Android |
| Offline source-contract tests | `python -m unittest discover -s tests -p 'test_*.py' -v` | **PASS — 21/21** | `verification/evidence/python_source_contracts.log` | اختبارات نصية/بنيوية فقط |
| Local structure/lexical checks | `python verification/offline_checks.py` | **PASS — 5 checks** | `verification/evidence/offline_checks.log` | لا تتحقق من ترجمة Dart أو تنفيذ SQL |
| Python harness parsing | `python -m py_compile ...` | **PASS** | `verification/evidence/python_compile.log` | لم تُشغّل الاختبارات الحية |
| Supabase migrations / seed | `supabase start; supabase db reset; psql` | **NOT RUN** | `verification/evidence/tool_availability.log` | لا يوجد CLI أو خادم اختبار |
| Auth/signup/login | Supabase REST integration | **NOT RUN** | `tests/backend_acceptance.py` | حسابات حقيقية واختبار بريد مطلوبان |
| Buyer / seller / admin / RLS | Supabase REST/RPC integration | **NOT RUN** | `tests/backend_acceptance.py` | قاعدة بيانات مستقلة متعددة الحسابات |
| Listing CRUD + Storage upload | Supabase RPC/Storage integration | **NOT RUN** | `tests/backend_acceptance.py` | Storage وصلاحيات معتمدة ومشروع حي |
| Order + cancellation + stock restore | Concurrent REST/RPC test | **NOT RUN** | `tests/backend_concurrency.py` | مشترون وكمية واحدة وتزامن حقيقي |
| Bid floor + self-bid + expired auction | Live RPC checks | **NOT RUN** | `tests/backend_acceptance.py` | مستخدمون ومزادات مُحضّرة |
| Simultaneous equal bids | Two-account race script | **NOT RUN** | `tests/backend_concurrency.py` | PostgreSQL وحسابان مستقلان |
| Winner + reserve + repeated finalization | Live RPC checks | **NOT RUN** | `tests/backend_acceptance.py` | مزادات اختبار منتهية بحالات مختلفة |
| Android RTL / LTR / screen sizes | Device/emulator visual testing | **NOT RUN** | لا توجد لقطات شاشة فعلية | Android SDK ومحاكي/هاتف ومراجعة بصرية |
| Visual design comparison | Screenshots vs supplied visuals | **NOT RUN** | لا يوجد تشغيل Android أو لقطات | PDF يقدم نظام التصميم لا لقطة تشغيل من التطبيق |
| ZIP archive integrity | `unzip -t` and independent extraction | **PASS** *بعد التغليف النهائي* | `verification/evidence/final_zip_integrity.log` | لا يعني سلامة تشغيل التطبيق |

## 3. الإصلاحات التي أُدخلت على ملفات المصدر

1. **مفاتيح إعادة المحاولة للطلبات:** رفض إعادة استخدام مفتاح طلب مع إعلان/كمية/منطقة/طريقة تسليم أو دفع مختلفة بدلاً من إرجاع طلب سابق وكأنه مطابق.
2. **مفاتيح المزايدات:** رفض استخدام مفتاح المزايدة نفسه لمزاد آخر أو مبلغ مختلف.
3. **الوقت بعد القفل:** استعمال `clock_timestamp()` بعد قفل صف المزاد للتحقق من وقت المزايدة الفعلي، ولتوقيت إنهاء المزاد، بدلاً من الاعتماد على وقت بداية المعاملة الذي قد يصبح قديماً عند الانتظار.
4. **تسلسل إغلاق وتعديل المزادات:** تقليل سباقات إغلاق الإعلان أو تعديله أثناء مزايدات متزامنة، بقفل صف المزاد قبل حسم الحالات في مسارات RPC، وإضافة قفل في حارس تعديل حقول المزاد.
5. **انتهاء مهلة الجائزة:** منع مهمة انتهاء المهلة من الكتابة فوق طلب سبق أن وافق عليه البائع، باستخدام قفل الصف والتحقق من الحالة عند التحديث.
6. **عدد صور الإعلان:** تسلسل إدخالات الصور المتزامنة قبل التحقق من حد الصور الخمس.
7. **الشراء دون اتصال:** تعطيل تأكيد الطلب إذا كانت تفاصيل الإعلان مأخوذة من التخزين المحلي أو إذا كان الإعلان غير نشط.
8. **اختبار التكامل:** استبدال التخطي الصامت عند نقص إعدادات Supabase بتأكيد اختبار صريح يفشل عند نقص الإعداد.

**تنبيه:** جميع هذه تصحيحات مصدرية. نجحت الفحوص البنيوية التي أضفتها، لكن لم تنفذ المعاملات في PostgreSQL ولم تُختبر مشاكل الأقفال أو التزامن فعلياً؛ قد تظهر أخطاء إضافية عند التطبيق الحقيقي.

## 4. حكم القبول الصادق

1. **هل المشروع يبني؟** غير مثبت. أمر البناء لم ينفذ لغياب Flutter، ولم يُنتج APK.
2. **هل يعمل على Android؟** غير مثبت. لم يُشغّل على جهاز أو محاكي ولم يُستورد إلى Android Studio في هذه البيئة.
3. **هل قاعدة البيانات تعمل؟** غير مثبت. المخطط والترحيلات ملفات مصدرية لم تطبق على PostgreSQL.
4. **هل البيع المباشر يعمل؟** غير مثبت تشغيلياً؛ توجد دوال وشاشات وسكربت اختبار لم يُشغّل على الخادم.
5. **هل المزادات تعمل؟** غير مثبت تشغيلياً؛ توجد دوال وإصلاحات تزامن وسكربتات حية غير منفذة.
6. **ما المشاكل المتبقية؟** تثبيت SDK، تنزيل الاعتماديات، حفظ `pubspec.lock`، `flutter analyze/test/build`، Supabase migrations/RLS، تشغيل سكربتات الاختبار على staging، صور/واجهات RTL/LTR واختبار الهواتف، فحص أمني، ومراجعة النشر.
7. **ZIP وAPK:** أُعد ZIP جديد بالمصدر والاختبارات والأدلة. لم يُنشأ APK؛ يجب عدم تسمية ZIP نسخة جاهزة للتثبيت.

## 5. خطوات استكمال التحقق في بيئة مناسبة

- فك ZIP وافتح مجلد `MARSA` الذي يحتوي على `pubspec.yaml` في Android Studio.
- جهّز Flutter stable/Android SDK والاتصال بمخازن الاعتماديات، ثم نفّذ الأوامر الستة السابقة تباعاً. احفظ Flutter/Dart versions و`pubspec.lock` وتقارير أي إصلاحات لاحقة.
- أنشئ Supabase مشروع اختبار مستقل، طبّق ترحيلات `supabase/migrations/` بالترتيب وبيانات `supabase/seed/`، واضبط Authentication وStorage والتخويل الإداري ضمن الخادم فقط.
- شغّل `supabase/tests/001_schema_assertions.sql` ثم `tests/backend_concurrency.py` و`tests/backend_acceptance.py` باستخدام حسابات اختبار وبيانات ملائمة، **في staging فقط**. تعليمات الحسابات والبيانات في `TESTING.md`.
- عند نجاح البناء والاختبارات فعلياً، اصدر APK، ثبته على جهاز Android، التقط صور شاشات عربية/إنجليزية بأحجام مختلفة، ثم حدّث التقرير بنتائج مسندة إلى سجلات حقيقية.

**ملاحظة للترحيلات:** في هذه الجلسة لم تُطبق أي migrations على قاعدة بيانات. تم إصلاح ملفات الترحيل الأصلية غير المنفذة. إذا سبق أن استُخدمت نسخة قديمة في خادم قائم، ينبغي إصدار ترحيل تصحيحي جديد بدلاً من تعديل تاريخ الترحيلات المطبقة.

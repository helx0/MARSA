import 'package:flutter_riverpod/flutter_riverpod.dart';

final languageProvider = StateProvider<String>((ref) => 'ar');

const _strings = <String, List<String>>{
  'app': ['مرسى', 'MARSA'],
  'home': ['السوق', 'Marketplace'], 'favorites': ['المفضلة', 'Favorites'],
  'orders': ['طلباتي', 'Orders'], 'chat': ['الرسائل', 'Messages'], 'profile': ['حسابي', 'Profile'],
  'search': ['ابحث عن الأسماك والمأكولات البحرية', 'Search seafood'],
  'all': ['الكل', 'All'], 'direct': ['بيع مباشر', 'Direct sale'], 'auction': ['مزاد', 'Auction'],
  'price': ['السعر', 'Price'], 'currentBid': ['أعلى مزايدة', 'Current bid'],
  'bid': ['زايد الآن', 'Place bid'], 'buy': ['اطلب الآن', 'Order now'],
  'quantity': ['الكمية', 'Quantity'], 'available': ['المتاح', 'Available'],
  'description': ['الوصف', 'Description'], 'seller': ['البائع', 'Seller'],
  'area': ['المنطقة في عدن', 'Aden area'], 'category': ['الفئة', 'Category'],
  'settings': ['الإعدادات', 'Settings'], 'login': ['تسجيل الدخول', 'Sign in'],
  'signup': ['إنشاء حساب', 'Create account'], 'logout': ['تسجيل الخروج', 'Sign out'],
  'email': ['البريد الإلكتروني', 'Email'], 'password': ['كلمة المرور', 'Password'],
  'name': ['الاسم', 'Name'], 'reset': ['استعادة كلمة المرور', 'Reset password'],
  'save': ['حفظ', 'Save'], 'cancel': ['إلغاء', 'Cancel'],
  'send': ['إرسال', 'Send'], 'continue': ['متابعة', 'Continue'],
  'loading': ['جارٍ التحميل…', 'Loading…'], 'retry': ['إعادة المحاولة', 'Retry'],
  'empty': ['لا توجد نتائج حالياً', 'No results yet'],
  'error': ['تعذر تنفيذ العملية. تأكد من اتصالك وحاول مجدداً.', 'Something went wrong. Check your connection and retry.'],
  'sellerCenter': ['مركز البائع', 'Seller center'], 'applySeller': ['التسجيل كبائع', 'Apply as seller'],
  'newListing': ['إضافة إعلان', 'Create listing'], 'title': ['عنوان الإعلان', 'Listing title'],
  'unit': ['الوحدة', 'Unit'], 'condition': ['ملاحظات الحالة والطزاجة', 'Condition and freshness notes'],
  'images': ['صور المنتج', 'Product images'], 'publish': ['إرسال للمراجعة', 'Submit for review'],
  'status': ['الحالة', 'Status'], 'notifications': ['الإشعارات', 'Notifications'],
  'checkout': ['تأكيد الطلب', 'Checkout'], 'subtotal': ['الإجمالي', 'Subtotal'],
  'payment': ['طريقة الدفع', 'Payment arrangement'], 'handover': ['طريقة الاستلام', 'Handover'],
  'notes': ['ملاحظات', 'Notes'], 'confirm': ['تأكيد', 'Confirm'],
  'noOnlinePayment': ['لا يوجد دفع إلكتروني داخل مرسى. اتفق مع البائع على الدفع والتسليم.',
    'MARSA has no online payment. Arrange payment and handover with the seller.'],
  'orderNumber': ['رقم الطلب', 'Order number'], 'details': ['التفاصيل', 'Details'],
  'history': ['سجل الحالة', 'Status history'], 'review': ['تقييم', 'Review'],
  'report': ['إبلاغ', 'Report'], 'block': ['حظر المستخدم', 'Block user'],
  'filter': ['تصفية', 'Filter'], 'sort': ['الترتيب', 'Sort'], 'newest': ['الأحدث', 'Newest'],
  'language': ['اللغة', 'Language'], 'english': ['English', 'English'],
  'arabic': ['العربية', 'Arabic'], 'admin': ['الإدارة', 'Administration'],
  'approved': ['معتمد', 'Approved'], 'pending': ['بانتظار المراجعة', 'Pending review'],
  'auctionRules': ['تُعتمد المزايدات من الخادم، ولا يمكن تعديلها بعد إرسالها.',
    'Bids are validated by the server and cannot be changed.'],
  'stock': ['المخزون', 'Stock'], 'more': ['المزيد', 'More'],
  'refresh': ['تحديث', 'Refresh'], 'view': ['عرض', 'View'],
  'support': ['الدعم والسياسات', 'Help and policies'],
  'writeMessage': ['اكتب رسالة', 'Write a message'], 'contact': ['راسل البائع', 'Message seller'],
  'upload': ['رفع الصور', 'Upload images'], 'start': ['البداية', 'Start'], 'end': ['النهاية', 'End'],
  'minIncrement': ['أقل زيادة', 'Minimum increment'], 'bidCount': ['عدد المزايدات', 'Bids'],
  'minBid': ['أقل مزايدة مقبولة', 'Minimum next bid'],
  'reviewNeeded': ['يتم نشر الإعلان بعد مراجعة الإدارة.', 'Admin review is required before publication.'],
};

String t(WidgetRef ref, String key) {
  final language = ref.watch(languageProvider);
  final item = _strings[key];
  return item == null ? key : item[language == 'en' ? 1 : 0];
}
String tr(String language, String key) {
  final item = _strings[key];
  return item == null ? key : item[language == 'en' ? 1 : 0];
}

import unittest, pathlib, re, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[1]

def source(relative):return (ROOT/relative).read_text(encoding='utf-8')

class MARSAContracts(unittest.TestCase):
    def test_dart_entry_and_android_starter(self):
        for path in ['pubspec.yaml','lib/main.dart','lib/app/marsa_app.dart','android/settings.gradle',
         'android/app/build.gradle','android/app/src/main/kotlin/com/marsa/marketplace/MainActivity.kt',
         'android/gradle/wrapper/gradle-wrapper.jar','android/gradlew']:
            self.assertTrue((ROOT/path).is_file(),path)
        ET.parse(ROOT/'android/app/src/main/AndroidManifest.xml')
        self.assertIn('com.marsa.marketplace',source('android/app/build.gradle'))
    def test_all_expected_tables_and_rls(self):
        schema=source('supabase/migrations/202611190001_foundation.sql')
        for table in ['profiles','seller_profiles','seller_verifications','aden_areas','seafood_categories','listings',
          'listing_images','direct_sale_details','auctions','bids','orders','order_items','order_status_history',
          'conversations','conversation_participants','messages','favorites','reviews','reports','notifications','audit_logs']:
            self.assertIn('create table public.'+table,schema)
            self.assertIn("'"+table+"'",schema.split('alter table public.%I enable row level security')[0])
        self.assertIn('enable row level security',schema)
        self.assertIn('create policy',schema)
    def test_server_authority_and_transactional_locking(self):
        ops=source('supabase/migrations/202611190002_operations.sql')
        for fn in ['place_order','transition_order','place_bid','finalize_auction','finalize_due_auctions',
          'admin_approve_seller','admin_moderate_listing','start_conversation','admin_reference']:
            self.assertIn('function public.'+fn,ops)
        for fn in ['public.listings where id=p_listing for update','public.auctions where listing_id=p_listing for update',
                   'public.orders where id=p_order for update']:
            self.assertIn(fn,ops)
        self.assertIn('unique(buyer_id,idempotency_key)',source('supabase/migrations/202611190001_foundation.sql'))
    def test_no_embedded_privileged_credentials(self):
        all_dart='\n'.join(p.read_text() for p in (ROOT/'lib').rglob('*.dart'))
        self.assertNotIn('SUPABASE_SERVICE_ROLE_KEY',all_dart)
        self.assertNotIn('service_role',all_dart.lower())
        self.assertIn('String.fromEnvironment',all_dart)
        self.assertNotIn('sk_test_',all_dart)
    def test_adens_first_release(self):
        seed=source('supabase/seed/001_aden.sql')
        for district in ['كريتر','المعلا','التواهي','خور مكسر','المنصورة','الشيخ عثمان','دار سعد','البريقة']:
            self.assertIn(district,seed)
        self.assertIn('g.is_enabled',source('supabase/migrations/202611190002_operations.sql'))
    def test_security_hardening(self):
        hardening=source('supabase/migrations/202611190004_security_hardening.sql')
        self.assertIn('revoke select on public.auctions',hardening)
        self.assertNotIn('current_bidder_id)',hardening.split('grant select')[1].split('on public.auctions')[0])
        self.assertIn('immutable_bid',source('supabase/migrations/202611190001_foundation.sql'))
    def test_local_dart_imports_are_resolved(self):
        for dart in (ROOT/'lib').rglob('*.dart'):
            content=dart.read_text(encoding='utf-8')
            for match in re.finditer(r"import\s+['\"]([^'\"]+)['\"]",content):
                target=match.group(1)
                if target.startswith('package:marsa/'):
                    imported=ROOT/'lib'/target.removeprefix('package:marsa/')
                elif target.startswith('.'):
                    imported=(dart.parent/target).resolve()
                else:
                    continue
                self.assertTrue(imported.is_file(),f'{dart}: missing {target}')
    def test_sensitive_private_admin_table_has_rls(self):
        self.assertIn('alter table mars_private.admin_users enable row level security',
            source('supabase/migrations/202611190009_private_rls.sql'))
    def test_documentation_present(self):
        for path in ['README.md','ARCHITECTURE.md','SRS.md','DATABASE.md','DESIGN_SYSTEM.md','TESTING.md','.env.example']:
            self.assertTrue((ROOT/path).is_file(),path)

if __name__=='__main__':unittest.main()

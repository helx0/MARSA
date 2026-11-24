"""Offline source-level regression checks. These do NOT execute PostgreSQL or Dart."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
OPS = (ROOT/'supabase/migrations/202611190002_operations.sql').read_text()


def function_body(name):
    m = re.search(rf'create or replace function public\.{name}\s*\(', OPS, re.I)
    if not m:
        raise AssertionError(f'Missing function {name}')
    start = OPS.index('$$', m.end()) + 2
    end = OPS.index('$$', start)
    return OPS[start:end]


class Phase2RegressionContracts(unittest.TestCase):
    def test_order_retries_reject_changed_request_in_both_paths(self):
        body = function_body('place_order')
        self.assertEqual(body.count("raise exception 'Order idempotency key reused with different request'"), 2)
        for token in ('i.listing_id=p_listing', 'i.quantity=p_quantity', 'o.area_id=p_area',
                      'o.payment_arrangement=p_payment', 'o.handover_method=p_handover'):
            self.assertEqual(body.count(token), 2, token)

    def test_bid_retries_validate_listing_and_amount(self):
        body = function_body('place_bid')
        self.assertIn('v_previous.auction_id<>p_listing', body)
        self.assertIn('v_previous.amount<>p_amount', body)
        self.assertIn("raise exception 'Bid idempotency key reused", body)

    def test_bid_clock_checked_after_lock(self):
        body = function_body('place_bid')
        self.assertLess(body.index('for update;'), body.index('v_time=clock_timestamp();'))
        self.assertIn('v_time>=a.ends_at', body)
        self.assertNotIn('now()>=a.ends_at', body)

    def test_public_auction_activity_requires_approved_seller(self):
        body = function_body('auction_activity')
        self.assertIn("status='ACTIVE' and public.is_approved_seller(seller_id)", body)

    def test_checkout_never_submits_offline_cached_listing(self):
        checkout = (ROOT/'lib/features/orders/presentation/order_screens.dart').read_text()
        self.assertIn("if(listing['__cached']==true)", checkout)
        self.assertIn("l['__cached']==true || l['status']!='ACTIVE'", checkout)

    def test_integration_test_cannot_silently_skip_when_unconfigured(self):
        integration = (ROOT/'integration_test/launch_test.dart').read_text()
        self.assertIn('expect(AppEnvironment.isConfigured,isTrue,reason:', integration)
        self.assertNotIn('if(!AppEnvironment.isConfigured) return;', integration)

    def test_auction_cancellation_and_edit_serialized_with_bid_lock(self):
        status_body = function_body('change_listing_status')
        self.assertLess(status_body.index('v_owner is distinct from auth.uid()'),
                        status_body.index('for update;'))
        self.assertLess(status_body.index('public.auctions where listing_id=p_listing for update'),
                        status_body.index('public.listings where id=p_listing for update'))
        moderate_body = function_body('admin_moderate_listing')
        self.assertLess(moderate_body.index('public.auctions where listing_id=p_listing for update'),
                        moderate_body.index('public.listings where id=p_listing for update'))
        guard = (ROOT/'supabase/migrations/202611190003_guards.sql').read_text()
        self.assertIn('from public.auctions where listing_id=old.id for update', guard)

    def test_finalize_uses_actual_clock_after_lock(self):
        body = function_body('finalize_auction')
        self.assertLess(body.index('for update;'), body.index('v_time=clock_timestamp();'))
        self.assertIn('v_time<a.ends_at', body)
        self.assertIn("winner_deadline=v_time+interval '48 hours'", body)

    def test_expiring_auction_awards_cannot_overwrite_seller_acceptance(self):
        body = function_body('finalize_due_auctions')
        self.assertIn('for update of o skip locked', body)
        self.assertIn("where id=v_row.id and status='PENDING_SELLER_CONFIRMATION'", body)

    def test_image_metadata_limit_serializes_concurrent_inserts(self):
        body = (ROOT/'supabase/migrations/202611190006_media_guard.sql').read_text()
        self.assertIn('seller_id=auth.uid()', body)
        self.assertIn('where id=new.listing_id for update', body)
        self.assertLess(body.index('where id=new.listing_id for update'), body.index('count(*)'))

    def test_stock_restore_only_on_eligible_transition(self):
        body = function_body('transition_order')
        self.assertIn('o.stock_released_at is null', body)
        self.assertIn('o.auction_listing_id is null', body)
        self.assertIn('where id=p_order for update', body)

    def test_finalize_idempotent_terminal_states(self):
        body = function_body('finalize_auction')
        self.assertIn('where listing_id=p_listing for update', body)
        self.assertIn("a.status in ('ENDED_WITH_WINNER','ENDED_NO_WINNER','CANCELLED')", body)


if __name__ == '__main__':
    unittest.main()

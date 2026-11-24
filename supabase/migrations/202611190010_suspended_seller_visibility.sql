-- Suspended sellers cannot keep active public product listings in discoverable catalog.
drop policy if exists listing_read on public.listings;
create policy listing_read on public.listings for select to anon, authenticated using(
 (status='ACTIVE' and public.is_approved_seller(seller_id))
 or seller_id=auth.uid() or public.is_admin()
);
-- Both direct and auction discovery rely on listing-read RLS. Search is SECURITY INVOKER.

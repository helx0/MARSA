-- All direct UPDATE paths are checked in addition to RLS.
create or replace function public.guard_listing_edit() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 -- Direct seller UPDATEs bypass the status RPC: serialize auction edits with bids too.
 -- A concurrent bid that commits first must make critical-field edits fail.
 if old.sale_type='AUCTION' then
  perform 1 from public.auctions where listing_id=old.id for update;
 end if;
 if old.sale_type<>new.sale_type or old.seller_id<>new.seller_id then raise exception 'Immutable seller or sale type';end if;
 if old.area_id is distinct from new.area_id and not exists (
  select 1 from public.aden_areas a join public.governorates g on g.id=a.governorate_id
  where a.id=new.area_id and a.is_active and g.code='ADEN' and g.is_enabled) then raise exception 'Aden-only area required';end if;
 if old.category_id is distinct from new.category_id and not exists (
  select 1 from public.seafood_categories where id=new.category_id and is_active) then raise exception 'Category is inactive';end if;
 if old.sale_type='AUCTION' and exists(select 1 from public.bids where auction_id=old.id)
 and (old.title_ar is distinct from new.title_ar or old.category_id is distinct from new.category_id
 or old.area_id is distinct from new.area_id or old.quantity_available is distinct from new.quantity_available
 or old.status is distinct from new.status) and not (old.status='ACTIVE' and new.status='CLOSED' and new.quantity_available=0)
 then raise exception 'Critical auction fields locked after first bid';end if;
 return new;
end;$$;
create trigger guard_listing_edit before update on public.listings for each row execute function public.guard_listing_edit();

-- Storage deletion of DB image references is owner-only; direct price changes occur via RPC.
-- Block client-side changes to bids, orders, auctions, statuses through denied privileges.

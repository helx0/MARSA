-- Security-definer RPCs are the ONLY path for money-adjacent or privileged state.
alter table public.conversations add column buyer_id uuid references public.profiles(id);
alter table public.conversations add column seller_id uuid references public.profiles(id);
create unique index conversations_unique_pair on public.conversations(listing_id,buyer_id,seller_id);

create or replace function public.create_listing(
 p_type text,p_category uuid,p_title text,p_description text,p_condition text,p_area uuid,
 p_quantity numeric,p_unit text,p_currency text,p_unit_price numeric default null,
 p_start_price numeric default null,p_increment numeric default null,p_reserve numeric default null,
 p_starts timestamptz default null,p_ends timestamptz default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
 if not public.is_approved_seller(auth.uid()) then raise exception 'Seller approval required';end if;
 if p_type not in ('DIRECT','AUCTION') or p_quantity<=0 or p_quantity>100000 or p_unit not in ('kg','box','piece')
 or p_currency !~ '^[A-Z]{3}$' or length(trim(p_title)) not between 3 and 120 then raise exception 'Invalid listing fields'; end if;
 if not exists(select 1 from public.aden_areas a join public.governorates g on a.governorate_id=g.id where a.id=p_area and a.is_active and g.is_enabled)
 or not exists(select 1 from public.seafood_categories where id=p_category and is_active) then raise exception 'Invalid Aden area or category';end if;
 if p_type='DIRECT' and (p_unit_price is null or p_unit_price<=0) then raise exception 'Invalid unit price';end if;
 if p_type='AUCTION' and (p_start_price is null or p_start_price<=0 or p_increment is null or p_increment<=0 or p_starts is null or p_ends is null
 or p_ends<=p_starts or p_ends<=now() or p_ends>now()+interval '30 days' or (p_reserve is not null and p_reserve<=0)) then raise exception 'Invalid auction settings';end if;
 insert into public.listings(seller_id,sale_type,category_id,title_ar,description,condition_note,area_id,quantity_available,unit,currency_code)
 values(auth.uid(),p_type,p_category,trim(p_title),coalesce(p_description,''),coalesce(p_condition,''),p_area,p_quantity,p_unit,p_currency) returning id into v_id;
 if p_type='DIRECT' then insert into public.direct_sale_details(listing_id,unit_price) values(v_id,p_unit_price);
 else insert into public.auctions(listing_id,start_price,current_price,minimum_increment,reserve_price,starts_at,ends_at)
 values(v_id,p_start_price,p_start_price,p_increment,p_reserve,p_starts,p_ends);end if;
 return v_id;
end;$$;

create or replace function public.change_listing_status(p_listing uuid,p_status text) returns text language plpgsql security definer set search_path = '' as $$
declare l public.listings%rowtype;v_owner uuid;v_mode text;
begin
 -- Verify ownership before acquiring the auction lock; do not allow third-party lock abuse.
 select seller_id,sale_type into v_owner,v_mode from public.listings where id=p_listing;
 if v_owner is distinct from auth.uid() or not public.is_approved_seller(auth.uid()) then
  raise exception 'Not authorized';end if;
 -- Serialize seller cancellation with place_bid's FOR UPDATE before inspecting bids.
 if v_mode='AUCTION' then perform 1 from public.auctions where listing_id=p_listing for update;end if;
 select * into l from public.listings where id=p_listing for update;
 if not found then raise exception 'Listing not found';end if;
 if l.seller_id<>auth.uid() or not public.is_approved_seller(auth.uid()) then raise exception 'Not authorized';end if;
 if not ((l.status='DRAFT' and p_status='PENDING_REVIEW') or
 (l.status='REJECTED' and p_status='DRAFT') or
 (l.status='ACTIVE' and p_status in ('PAUSED','CLOSED')) or
 (l.status='PAUSED' and p_status in ('ACTIVE','CLOSED')) or
 (l.status='SOLD_OUT' and p_status='CLOSED')) then raise exception 'Invalid listing transition';end if;
 if p_status='PENDING_REVIEW' and not exists(select 1 from public.listing_images where listing_id=p_listing) then raise exception 'Upload at least one photo before submission';end if;
 if l.sale_type='AUCTION' and p_status in ('PAUSED','CLOSED') and exists(select 1 from public.bids where auction_id=p_listing)
 then raise exception 'Cannot interrupt auction after bids';end if;
 update public.listings set status=p_status, published_at=case when p_status='ACTIVE' then coalesce(published_at,now()) else published_at end where id=p_listing;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'listing_'||lower(p_status),'listing',p_listing);
 return p_status;
end;$$;

create or replace function public.adjust_stock(p_listing uuid,p_delta numeric) returns numeric language plpgsql security definer set search_path = '' as $$
declare l public.listings%rowtype;v_stock numeric;
begin
 select * into l from public.listings where id=p_listing for update;
 if not found or l.seller_id<>auth.uid() or l.sale_type<>'DIRECT' or not public.is_approved_seller(auth.uid()) or l.status not in ('ACTIVE','PAUSED','DRAFT','SOLD_OUT') then raise exception 'Stock change not allowed';end if;
 if p_delta=0 or abs(p_delta)>100000 or l.quantity_available+p_delta<0 then raise exception 'Invalid quantity';end if;
 update public.listings set quantity_available=quantity_available+p_delta where id=p_listing returning quantity_available into v_stock;
 return v_stock;
end;$$;

create or replace function public.change_direct_price(p_listing uuid,p_price numeric) returns numeric language plpgsql security definer set search_path = '' as $$
begin
 if p_price<=0 or p_price>1000000000 or not public.is_approved_seller(auth.uid()) or not exists(select 1 from public.listings where id=p_listing and seller_id=auth.uid() and sale_type='DIRECT' and status in ('DRAFT','ACTIVE','PAUSED')) then raise exception 'Price change denied';end if;
 update public.direct_sale_details set unit_price=p_price where listing_id=p_listing;
 return p_price;
end;$$;

create or replace function public.place_order(p_listing uuid,p_quantity numeric,p_key text,p_area uuid,p_handover text,p_payment text,p_notes text default '')
returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.listings%rowtype;d public.direct_sale_details%rowtype;v_order uuid;v_amount numeric;
begin
 if not public.is_active_user() or p_key is null or length(p_key) not between 8 and 100 or p_quantity is null or p_quantity<=0 or p_quantity>100000
 or p_handover not in ('PICKUP','AGREED_DELIVERY') or p_payment not in ('CASH_ON_HANDOVER','MANUAL_EXTERNAL_AGREEMENT')
 or length(coalesce(p_notes,''))>500 then raise exception 'Invalid order request';end if;
 select id into v_order from public.orders where buyer_id=auth.uid() and idempotency_key=p_key;
 if found then
  -- A reused key must not silently confirm a different listing, quantity or handover.
  if not exists (select 1 from public.order_items i where i.order_id=v_order
    and i.listing_id=p_listing and i.quantity=p_quantity)
    or not exists (select 1 from public.orders o where o.id=v_order
      and o.area_id=p_area and o.handover_method=p_handover
      and o.payment_arrangement=p_payment and o.notes=coalesce(p_notes,''))
  then raise exception 'Order idempotency key reused with different request';end if;
  return v_order;
 end if;
 select * into l from public.listings where id=p_listing for update;
 if not found or l.status<>'ACTIVE' or l.sale_type<>'DIRECT' or l.seller_id=auth.uid() or not public.is_approved_seller(l.seller_id) then raise exception 'Listing not available';end if;
 select id into v_order from public.orders where buyer_id=auth.uid() and idempotency_key=p_key;
 if found then
  -- A reused key must not silently confirm a different listing, quantity or handover.
  if not exists (select 1 from public.order_items i where i.order_id=v_order
    and i.listing_id=p_listing and i.quantity=p_quantity)
    or not exists (select 1 from public.orders o where o.id=v_order
      and o.area_id=p_area and o.handover_method=p_handover
      and o.payment_arrangement=p_payment and o.notes=coalesce(p_notes,''))
  then raise exception 'Order idempotency key reused with different request';end if;
  return v_order;
 end if;
 if not exists(select 1 from public.aden_areas a join public.governorates g on a.governorate_id=g.id where a.id=p_area and a.is_active and g.is_enabled) then raise exception 'Enabled area required';end if;
 select * into d from public.direct_sale_details where listing_id=p_listing;
 if p_quantity<d.minimum_order_quantity or p_quantity>l.quantity_available then raise exception 'Insufficient stock or quantity below minimum';end if;
 v_amount=round(p_quantity*d.unit_price,2);
 update public.listings set quantity_available=quantity_available-p_quantity where id=p_listing;
 insert into public.orders(order_number,buyer_id,seller_id,currency_code,subtotal,payment_arrangement,handover_method,area_id,notes,idempotency_key)
 values('MRS-'||to_char(now(),'YYYYMMDD')||'-'||upper(left(replace(gen_random_uuid()::text,'-',''),8)),auth.uid(),l.seller_id,l.currency_code,v_amount,p_payment,p_handover,p_area,coalesce(p_notes,''),p_key) returning id into v_order;
 insert into public.order_items(order_id,listing_id,title_snapshot,unit_snapshot,quantity,unit_price_snapshot,line_total)
 values(v_order,p_listing,l.title_ar,l.unit,p_quantity,d.unit_price,v_amount);
 insert into public.order_status_history(order_id,new_status,actor_id) values(v_order,'PENDING_SELLER_CONFIRMATION',auth.uid());
 insert into public.notifications(recipient_id,type,payload) values(l.seller_id,'NEW_ORDER',jsonb_build_object('order_id',v_order));
 return v_order;
end;$$;

create or replace function public.transition_order(p_order uuid,p_status text,p_note text default '')
returns text language plpgsql security definer set search_path = '' as $$
declare o public.orders%rowtype;li public.order_items%rowtype;v_admin boolean;
begin
 select * into o from public.orders where id=p_order for update;
 if not found or not public.is_active_user() then raise exception 'Order unavailable';end if;
 v_admin=public.is_admin();
 if not (
  (o.seller_id=auth.uid() and ((o.status='PENDING_SELLER_CONFIRMATION' and p_status in ('ACCEPTED','REJECTED')) or (o.status='ACCEPTED' and p_status in ('PREPARING','READY_FOR_HANDOVER')) or (o.status='PREPARING' and p_status='READY_FOR_HANDOVER')))
  or (o.buyer_id=auth.uid() and ((o.status='PENDING_SELLER_CONFIRMATION' and p_status='CANCELLED') or (o.status='READY_FOR_HANDOVER' and p_status='COMPLETED')))
  or (v_admin and o.status not in ('COMPLETED','REJECTED','CANCELLED','EXPIRED') and p_status='DISPUTED')
 ) then raise exception 'Invalid order transition or actor';end if;
 if p_status in ('REJECTED','CANCELLED','EXPIRED') and o.stock_released_at is null and o.auction_listing_id is null then
  for li in select * from public.order_items where order_id=p_order loop
   update public.listings set quantity_available=quantity_available+li.quantity where id=li.listing_id;
  end loop;
  update public.orders set stock_released_at=now() where id=p_order;
 end if;
 update public.orders set status=p_status,cancellation_reason=case when p_status in ('REJECTED','CANCELLED','DISPUTED') then left(p_note,500) else cancellation_reason end where id=p_order;
 insert into public.order_status_history(order_id,old_status,new_status,actor_id,note) values(p_order,o.status,p_status,auth.uid(),left(p_note,500));
 insert into public.notifications(recipient_id,type,payload) values(
 case when auth.uid()=o.buyer_id then o.seller_id else o.buyer_id end,'ORDER_STATUS',jsonb_build_object('order_id',p_order,'status',p_status));
 return p_status;
end;$$;

create or replace function public.place_bid(p_listing uuid,p_amount numeric,p_request_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a public.auctions%rowtype;l public.listings%rowtype;v_min numeric;v_count int;
  v_previous public.bids%rowtype;v_bid uuid;v_time timestamptz;
begin
 if not public.is_active_user() or p_amount is null or p_amount<=0 or p_request_id is null or length(p_request_id) not between 8 and 100 then raise exception 'Invalid bid';end if;
 select * into a from public.auctions where listing_id=p_listing for update;
 if not found then raise exception 'Auction not found';end if;
 select * into l from public.listings where id=p_listing;
 if l.status<>'ACTIVE' or not public.is_approved_seller(l.seller_id) or l.seller_id=auth.uid() then raise exception 'Not allowed to bid';end if;
 select * into v_previous from public.bids where bidder_id=auth.uid() and request_id=p_request_id;
 if found then
  if v_previous.auction_id<>p_listing or v_previous.amount<>p_amount then
   raise exception 'Bid idempotency key reused with different auction or amount';
  end if;
  return jsonb_build_object('bid_id',v_previous.id,'current_price',a.current_price,
    'server_time',clock_timestamp(),'idempotent',true);
 end if;
 if exists(select 1 from public.bids where bidder_id=auth.uid() and created_at>now()-interval '1 second') then raise exception 'Bid rate limited';end if;
 -- now() is the transaction start time: it can be stale after waiting for FOR UPDATE.
 -- Take wall-clock time only AFTER obtaining the auction row lock.
 v_time=clock_timestamp();
 if v_time<a.starts_at or v_time>=a.ends_at or a.status not in ('SCHEDULED','LIVE') then raise exception 'Auction is not live';end if;
 select count(*) into v_count from public.bids where auction_id=p_listing;
 v_min=case when v_count=0 then a.start_price else a.current_price+a.minimum_increment end;
 if p_amount<v_min then raise exception 'Bid too low. Minimum: %',v_min;end if;
 insert into public.bids(auction_id,bidder_id,amount,request_id) values(p_listing,auth.uid(),p_amount,p_request_id) returning id into v_bid;
 update public.auctions set current_price=p_amount,current_bidder_id=auth.uid(),status='LIVE' where listing_id=p_listing;
 if a.current_bidder_id is not null and a.current_bidder_id<>auth.uid() then
  insert into public.notifications(recipient_id,type,payload) values(a.current_bidder_id,'OUTBID',jsonb_build_object('listing_id',p_listing));
 end if;
 insert into public.notifications(recipient_id,type,payload) values(auth.uid(),'BID_ACCEPTED',jsonb_build_object('listing_id',p_listing,'amount',p_amount));
 return jsonb_build_object('bid_id',v_bid,'current_price',p_amount,'server_time',v_time,'idempotent',false);
end;$$;

-- Public-safe auction data: bidder IDs NEVER returned in history.
create or replace function public.auction_activity(p_listing uuid) returns jsonb language sql stable security definer set search_path = '' as $$
 select case when exists(select 1 from public.listings where id=p_listing and ((status='ACTIVE' and public.is_approved_seller(seller_id)) or seller_id=auth.uid() or public.is_admin()))
 then jsonb_build_object('server_time',now(),'count',(select count(*) from public.bids where auction_id=p_listing),
 'amounts',coalesce((select jsonb_agg(x.amount order by x.created_at desc) from (select amount,created_at from public.bids where auction_id=p_listing order by created_at desc limit 15) x),'[]'::jsonb))
 else null end;
$$;

-- Safe on-demand finalization may be called by any signed-in user; result is deterministic.
create or replace function public.finalize_auction(p_listing uuid) returns text language plpgsql security definer set search_path = '' as $$
declare a public.auctions%rowtype;l public.listings%rowtype;v_order uuid;v_amount numeric;v_time timestamptz;
begin
 select * into a from public.auctions where listing_id=p_listing for update;
 if not found then raise exception 'Auction missing';end if;
 if a.status in ('ENDED_WITH_WINNER','ENDED_NO_WINNER','CANCELLED') then return a.status;end if;
 v_time=clock_timestamp();
 if v_time<a.ends_at then raise exception 'Auction has not ended';end if;
 select * into l from public.listings where id=p_listing;
 if a.current_bidder_id is null or (a.reserve_price is not null and a.current_price<a.reserve_price) then
  update public.auctions set status='ENDED_NO_WINNER',finalized_at=v_time where listing_id=p_listing;
  update public.listings set status='CLOSED' where id=p_listing;
  insert into public.notifications(recipient_id,type,payload) values(l.seller_id,'AUCTION_NO_WINNER',jsonb_build_object('listing_id',p_listing));
  return 'ENDED_NO_WINNER';
 end if;
 v_amount=round(a.current_price*l.quantity_available,2);
 update public.auctions set status='ENDED_WITH_WINNER',winner_user_id=a.current_bidder_id,finalized_at=v_time,winner_deadline=v_time+interval '48 hours' where listing_id=p_listing;
 insert into public.orders(order_number,buyer_id,seller_id,currency_code,subtotal,payment_arrangement,handover_method,area_id,notes,idempotency_key,auction_listing_id)
 values('MRS-'||to_char(now(),'YYYYMMDD')||'-'||upper(left(replace(gen_random_uuid()::text,'-',''),8)),a.current_bidder_id,l.seller_id,l.currency_code,v_amount,'CASH_ON_HANDOVER','PICKUP',l.area_id,'Auction award','auction:'||p_listing::text,p_listing) returning id into v_order;
 insert into public.order_items(order_id,listing_id,title_snapshot,unit_snapshot,quantity,unit_price_snapshot,line_total)
 values(v_order,p_listing,l.title_ar,l.unit,l.quantity_available,a.current_price,v_amount);
 insert into public.order_status_history(order_id,new_status) values(v_order,'PENDING_SELLER_CONFIRMATION');
 update public.listings set quantity_available=0,status='CLOSED' where id=p_listing;
 insert into public.notifications(recipient_id,type,payload) values
 (a.current_bidder_id,'AUCTION_WON',jsonb_build_object('order_id',v_order)),
 (l.seller_id,'AUCTION_ENDED',jsonb_build_object('order_id',v_order));
 return 'ENDED_WITH_WINNER';
end;$$;

create or replace function public.finalize_due_auctions() returns integer language plpgsql security definer set search_path = '' as $$
declare v_row record;v_n int=0;
begin
 for v_row in select listing_id from public.auctions where status in ('SCHEDULED','LIVE') and ends_at<=now() order by ends_at limit 200 loop
  perform public.finalize_auction(v_row.listing_id);v_n=v_n+1;
 end loop;
 -- Do not silently award to second bidder; expired winner must be manually relisted.
 for v_row in select o.id from public.orders o join public.auctions a on a.listing_id=o.auction_listing_id
 where o.status='PENDING_SELLER_CONFIRMATION' and a.winner_deadline<clock_timestamp()
 order by o.created_at limit 200 for update of o skip locked loop
  -- A seller accepting an award concurrently must not have ACCEPTED overwritten.
  update public.orders set status='EXPIRED',cancellation_reason='Auction winner deadline expired'
  where id=v_row.id and status='PENDING_SELLER_CONFIRMATION';
  insert into public.order_status_history(order_id,old_status,new_status,note) values(v_row.id,'PENDING_SELLER_CONFIRMATION','EXPIRED','Winner did not complete before deadline');
  insert into public.audit_logs(action,entity_type,entity_id) values('auction_winner_default','order',v_row.id);
 end loop;
 return v_n;
end;$$;

create or replace function public.start_conversation(p_listing uuid) returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.listings%rowtype;v_id uuid;
begin
 if not public.is_active_user() then raise exception 'Sign in required';end if;
 select * into l from public.listings where id=p_listing;
 if not found or l.status not in ('ACTIVE','CLOSED') or l.seller_id=auth.uid() then raise exception 'Conversation not allowed';end if;
 if exists(select 1 from public.blocked_users b where (b.blocker_id=auth.uid() and b.blocked_id=l.seller_id) or (b.blocker_id=l.seller_id and b.blocked_id=auth.uid())) then raise exception 'Conversation blocked';end if;
 insert into public.conversations(listing_id,buyer_id,seller_id) values(p_listing,auth.uid(),l.seller_id)
 on conflict(listing_id,buyer_id,seller_id) do update set updated_at=excluded.updated_at returning id into v_id;
 insert into public.conversation_participants(conversation_id,user_id) values(v_id,auth.uid()),(v_id,l.seller_id) on conflict do nothing;
 return v_id;
end;$$;

create or replace function public.admin_approve_seller(p_user uuid,p_status text,p_reason text default '') returns text language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() or p_status not in ('APPROVED','REJECTED','SUSPENDED') then raise exception 'Admin only';end if;
 update public.seller_profiles set verification_status=p_status,admin_reviewed_at=now() where user_id=p_user;
 if not found then raise exception 'Seller missing';end if;
 insert into public.seller_verifications(seller_id,rejection_reason_private) values(p_user,left(p_reason,500))
 on conflict(seller_id) do update set rejection_reason_private=excluded.rejection_reason_private;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'seller_'||lower(p_status),'seller',p_user);
 insert into public.notifications(recipient_id,type,payload) values(p_user,'SELLER_STATUS',jsonb_build_object('status',p_status));
 return p_status;
end;$$;

create or replace function public.admin_moderate_listing(p_listing uuid,p_status text) returns text language plpgsql security definer set search_path = '' as $$
declare l public.listings%rowtype;v_mode text;
begin
 if not public.is_admin() or p_status not in ('ACTIVE','REJECTED','REMOVED') then raise exception 'Admin only';end if;
 select sale_type into v_mode from public.listings where id=p_listing;
 if v_mode='AUCTION' then perform 1 from public.auctions where listing_id=p_listing for update;end if;
 select * into l from public.listings where id=p_listing for update;
 if not found or not ((l.status='PENDING_REVIEW' and p_status in ('ACTIVE','REJECTED')) or (l.status in ('ACTIVE','PAUSED') and p_status='REMOVED')) then raise exception 'Invalid moderation transition';end if;
 if p_status='ACTIVE' and not public.is_approved_seller(l.seller_id) then raise exception 'Seller not approved';end if;
 if p_status='REMOVED' and l.sale_type='AUCTION' and exists(select 1 from public.bids where auction_id=p_listing) then raise exception 'Auction with bids requires dispute workflow';end if;
 update public.listings set status=p_status,published_at=case when p_status='ACTIVE' then now() else published_at end where id=p_listing;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'moderate_'||lower(p_status),'listing',p_listing);
 insert into public.notifications(recipient_id,type,payload) values(l.seller_id,'LISTING_MODERATION',jsonb_build_object('listing_id',p_listing,'status',p_status));
 return p_status;
end;$$;

create or replace function public.admin_resolve_report(p_report uuid,p_status text,p_resolution text) returns text language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() or p_status not in ('RESOLVED','DISMISSED') then raise exception 'Admin only';end if;
 update public.reports set status=p_status,admin_resolution=left(p_resolution,1000) where id=p_report and status='OPEN';
 if not found then raise exception 'Report not open';end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'report_'||lower(p_status),'report',p_report);
 return p_status;
end;$$;

create or replace function public.admin_account_status(p_user uuid,p_status text) returns text language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() or p_status not in ('ACTIVE','SUSPENDED') or p_user=auth.uid() then raise exception 'Admin only';end if;
 update public.profiles set account_status=p_status where id=p_user;
 if not found then raise exception 'Account not found';end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'account_'||lower(p_status),'profile',p_user);
 return p_status;
end;$$;

create or replace function public.admin_reference(p_kind text,p_id uuid,p_ar text,p_en text,p_active boolean,p_sort int default 0)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;v_aden uuid;
begin
 if not public.is_admin() then raise exception 'Admin only';end if;
 if length(trim(p_ar)) not between 2 and 70 or length(trim(p_en)) not between 2 and 70 then raise exception 'Invalid names';end if;
 if p_kind='CATEGORY' then
  if p_id is null then insert into public.seafood_categories(name_ar,name_en,is_active,sort_order) values(p_ar,p_en,p_active,p_sort) returning id into v_id;
  else update public.seafood_categories set name_ar=p_ar,name_en=p_en,is_active=p_active,sort_order=p_sort where id=p_id returning id into v_id;end if;
 elsif p_kind='AREA' then
  select id into v_aden from public.governorates where code='ADEN';
  if p_id is null then insert into public.aden_areas(governorate_id,name_ar,name_en,is_active,sort_order) values(v_aden,p_ar,p_en,p_active,p_sort) returning id into v_id;
  else update public.aden_areas set name_ar=p_ar,name_en=p_en,is_active=p_active,sort_order=p_sort where id=p_id and governorate_id=v_aden returning id into v_id;end if;
 else raise exception 'Invalid reference type';end if;
 if v_id is null then raise exception 'Reference not found';end if;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id) values(auth.uid(),'reference_changed',lower(p_kind),v_id);
 return v_id;
end;$$;

-- Pin RPC permissions: PostgreSQL gives PUBLIC EXECUTE by default; never rely on RLS for definer RPC.
revoke execute on function public.create_listing(text,uuid,text,text,text,uuid,numeric,text,text,numeric,numeric,numeric,numeric,timestamptz,timestamptz) from public,anon;
revoke execute on function public.change_listing_status(uuid,text) from public,anon;
revoke execute on function public.adjust_stock(uuid,numeric) from public,anon;
revoke execute on function public.change_direct_price(uuid,numeric) from public,anon;
revoke execute on function public.place_order(uuid,numeric,text,uuid,text,text,text) from public,anon;
revoke execute on function public.transition_order(uuid,text,text) from public,anon;
revoke execute on function public.place_bid(uuid,numeric,text) from public,anon;
revoke execute on function public.finalize_auction(uuid) from public,anon;
revoke execute on function public.finalize_due_auctions() from public,anon,authenticated;
revoke execute on function public.start_conversation(uuid) from public,anon;
revoke execute on function public.admin_approve_seller(uuid,text,text) from public,anon;
revoke execute on function public.admin_moderate_listing(uuid,text) from public,anon;
revoke execute on function public.admin_resolve_report(uuid,text,text) from public,anon;
revoke execute on function public.admin_account_status(uuid,text) from public,anon;
revoke execute on function public.admin_reference(text,uuid,text,text,boolean,int) from public,anon;
grant execute on function public.create_listing(text,uuid,text,text,text,uuid,numeric,text,text,numeric,numeric,numeric,numeric,timestamptz,timestamptz),public.change_listing_status(uuid,text),public.adjust_stock(uuid,numeric),public.change_direct_price(uuid,numeric),public.place_order(uuid,numeric,text,uuid,text,text,text),public.transition_order(uuid,text,text),public.place_bid(uuid,numeric,text),public.finalize_auction(uuid),public.start_conversation(uuid),public.admin_approve_seller(uuid,text,text),public.admin_moderate_listing(uuid,text),public.admin_resolve_report(uuid,text,text),public.admin_account_status(uuid,text),public.admin_reference(text,uuid,text,text,boolean,int) to authenticated;
grant execute on function public.finalize_due_auctions() to service_role;
grant execute on function public.auction_activity(uuid) to anon,authenticated;

create or replace function public.server_clock() returns timestamptz language sql stable set search_path = '' as $$select now()$$;
grant execute on function public.server_clock() to anon,authenticated;

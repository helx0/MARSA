-- MARSA 1.0: PostgreSQL/Supabase schema. Run with Supabase migrations.
create extension if not exists pgcrypto;
create schema if not exists mars_private;
revoke all on schema mars_private from public, anon, authenticated;

create table public.governorates (
 id uuid primary key default gen_random_uuid(), code text not null unique,
 name_ar text not null, name_en text not null, is_enabled boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.aden_areas (
 id uuid primary key default gen_random_uuid(), governorate_id uuid not null references public.governorates(id),
 name_ar text not null, name_en text not null, is_active boolean not null default true,
 sort_order int not null default 0, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(governorate_id,name_ar)
);
create table public.seafood_categories (
 id uuid primary key default gen_random_uuid(), name_ar text not null unique, name_en text not null,
 image_path text, is_active boolean not null default true, sort_order int not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade, display_name text not null default 'مستخدم مرسى',
 avatar_path text, phone_private text, account_status text not null default 'ACTIVE' check(account_status in ('ACTIVE','SUSPENDED')),
 preferred_language text not null default 'ar' check(preferred_language in ('ar','en')),
 area_id uuid references public.aden_areas(id), neighborhood_private text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table mars_private.admin_users (
 user_id uuid primary key references auth.users(id) on delete cascade,
 assigned_at timestamptz not null default now()
);
create table public.seller_profiles (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 business_name text not null check(length(trim(business_name)) between 2 and 100),
 description text not null default '',
 verification_status text not null default 'PENDING' check(verification_status in ('PENDING','APPROVED','REJECTED','SUSPENDED')),
 admin_reviewed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.seller_verifications (
 seller_id uuid primary key references public.seller_profiles(user_id) on delete cascade,
 verification_private_data jsonb not null default '{}'::jsonb,
 document_path text, rejection_reason_private text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.listings (
 id uuid primary key default gen_random_uuid(), seller_id uuid not null references public.seller_profiles(user_id),
 sale_type text not null check(sale_type in ('DIRECT','AUCTION')),
 category_id uuid not null references public.seafood_categories(id),
 title_ar text not null check(length(trim(title_ar)) between 3 and 120), title_en text,
 description text not null default '', condition_note text not null default '',
 area_id uuid not null references public.aden_areas(id), quantity_available numeric(12,3) not null check(quantity_available >= 0),
 unit text not null check(unit in ('kg','box','piece')),
 currency_code text not null default 'YER' check(currency_code ~ '^[A-Z]{3}$'),
 status text not null default 'DRAFT' check(status in ('DRAFT','PENDING_REVIEW','ACTIVE','PAUSED','SOLD_OUT','CLOSED','REJECTED','REMOVED')),
 published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index listings_feed_idx on public.listings(status,sale_type,created_at desc);
create index listings_seller_idx on public.listings(seller_id,created_at desc);
create index listings_area_category_idx on public.listings(area_id,category_id);
create table public.listing_images (
 id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade,
 storage_path text not null unique, sort_order int not null default 0, alt_text text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.direct_sale_details (
 listing_id uuid primary key references public.listings(id) on delete cascade,
 unit_price numeric(14,2) not null check(unit_price > 0), minimum_order_quantity numeric(12,3) not null default 1 check(minimum_order_quantity > 0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.auctions (
 listing_id uuid primary key references public.listings(id) on delete cascade,
 start_price numeric(14,2) not null check(start_price > 0), current_price numeric(14,2) not null check(current_price > 0),
 minimum_increment numeric(14,2) not null check(minimum_increment > 0),
 reserve_price numeric(14,2) check(reserve_price is null or reserve_price > 0),
 starts_at timestamptz not null, ends_at timestamptz not null,
 status text not null default 'SCHEDULED' check(status in ('SCHEDULED','LIVE','ENDED_WITH_WINNER','ENDED_NO_WINNER','CANCELLED')),
 current_bidder_id uuid references public.profiles(id), winner_user_id uuid references public.profiles(id),
 finalized_at timestamptz, winner_deadline timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint auction_time check(ends_at > starts_at), constraint auction_price check(current_price >= start_price)
);
create index auctions_expiry_idx on public.auctions(status,ends_at);
create table public.bids (
 id uuid primary key default gen_random_uuid(), auction_id uuid not null references public.auctions(listing_id),
 bidder_id uuid not null references public.profiles(id), amount numeric(14,2) not null check(amount > 0),
 status text not null default 'ACCEPTED' check(status in ('ACCEPTED','REJECTED')),
 request_id text not null, created_at timestamptz not null default now(),
 unique(bidder_id,request_id)
);
create index bids_auction_time_idx on public.bids(auction_id, created_at desc);
create index bids_bidder_idx on public.bids(bidder_id,created_at desc);
create table public.orders (
 id uuid primary key default gen_random_uuid(), order_number text not null unique,
 buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id),
 status text not null default 'PENDING_SELLER_CONFIRMATION' check(status in ('PENDING_SELLER_CONFIRMATION','ACCEPTED','PREPARING','READY_FOR_HANDOVER','COMPLETED','REJECTED','CANCELLED','EXPIRED','DISPUTED')),
 currency_code text not null check(currency_code ~ '^[A-Z]{3}$'), subtotal numeric(16,2) not null check(subtotal >= 0),
 payment_arrangement text not null check(payment_arrangement in ('CASH_ON_HANDOVER','MANUAL_EXTERNAL_AGREEMENT')),
 payment_status text not null default 'UNCONFIRMED' check(payment_status in ('UNCONFIRMED','MARKED_PAID')),
 handover_method text not null check(handover_method in ('PICKUP','AGREED_DELIVERY')),
 area_id uuid references public.aden_areas(id), notes text not null default '', cancellation_reason text,
 idempotency_key text not null, auction_listing_id uuid unique references public.auctions(listing_id),
 stock_released_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(buyer_id,idempotency_key), check(buyer_id <> seller_id)
);
create index orders_buyer_idx on public.orders(buyer_id,created_at desc);
create index orders_seller_idx on public.orders(seller_id,created_at desc);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 listing_id uuid not null references public.listings(id), title_snapshot text not null, unit_snapshot text not null,
 quantity numeric(12,3) not null check(quantity > 0), unit_price_snapshot numeric(14,2) not null check(unit_price_snapshot >= 0),
 line_total numeric(16,2) not null check(line_total >= 0),
 created_at timestamptz not null default now(), unique(order_id,listing_id)
);
create table public.order_status_history (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 old_status text, new_status text not null, actor_id uuid references public.profiles(id), note text,
 created_at timestamptz not null default now()
);
create table public.conversations (
 id uuid primary key default gen_random_uuid(), listing_id uuid references public.listings(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.conversation_participants (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(conversation_id,user_id)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(), conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id), body text not null check(length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now()
);
create index messages_conversation_idx on public.messages(conversation_id,created_at desc);
create table public.blocked_users (
 blocker_id uuid not null references public.profiles(id), blocked_id uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), primary key(blocker_id,blocked_id), check(blocker_id <> blocked_id)
);
create table public.favorites (
 user_id uuid not null references public.profiles(id), listing_id uuid not null references public.listings(id) on delete cascade,
 created_at timestamptz not null default now(), primary key(user_id,listing_id)
);
create table public.reviews (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id),
 buyer_id uuid not null references public.profiles(id), seller_id uuid not null references public.profiles(id),
 rating int not null check(rating between 1 and 5), comment text,
 moderation_status text not null default 'VISIBLE' check(moderation_status in ('VISIBLE','HIDDEN')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.reports (
 id uuid primary key default gen_random_uuid(), reporter_id uuid not null references public.profiles(id),
 target_type text not null check(target_type in ('USER','LISTING','ORDER','MESSAGE')),
 target_id uuid not null, reason text not null check(length(trim(reason)) between 5 and 1000),
 status text not null default 'OPEN' check(status in ('OPEN','RESOLVED','DISMISSED')),
 admin_resolution text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references public.profiles(id),
 type text not null, payload jsonb not null default '{}'::jsonb, read_at timestamptz,
 created_at timestamptz not null default now()
);
create index notifications_recipient_idx on public.notifications(recipient_id,created_at desc);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_id uuid references public.profiles(id),
 action text not null, entity_type text not null, entity_id uuid, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

create or replace function public.touch_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at=now();return new;end;$$;
do $$ declare v text; begin foreach v in array array['governorates','aden_areas','seafood_categories','profiles','seller_profiles','seller_verifications','listings','listing_images','direct_sale_details','auctions','orders','conversations','reviews','reports'] loop
 execute format('create trigger touch_updated before update on public.%I for each row execute function public.touch_updated_at()',v);
end loop;end $$;

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from mars_private.admin_users where user_id=auth.uid());
$$;
create or replace function public.is_active_user() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and account_status='ACTIVE');
$$;
create or replace function public.is_approved_seller(p_user uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.seller_profiles s join public.profiles p on p.id=s.user_id
 where s.user_id=p_user and s.verification_status='APPROVED' and p.account_status='ACTIVE');
$$;
create or replace function public.is_conversation_participant(p_conversation uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.conversation_participants where conversation_id=p_conversation and user_id=auth.uid());
$$;
create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,display_name) values(new.id,coalesce(nullif(left(new.raw_user_meta_data->>'display_name',100),''),'مستخدم مرسى'));
 return new;
end;$$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.on_auth_user_created();

-- Protect reference data and private records with RLS plus column-level grants.
do $$ declare v text; begin foreach v in array array['governorates','aden_areas','seafood_categories','profiles','seller_profiles','seller_verifications','listings','listing_images','direct_sale_details','auctions','bids','orders','order_items','order_status_history','conversations','conversation_participants','messages','blocked_users','favorites','reviews','reports','notifications','audit_logs'] loop
 execute format('alter table public.%I enable row level security',v);
 execute format('revoke all on public.%I from anon, authenticated',v);
end loop;end $$;

create policy gov_read on public.governorates for select to anon, authenticated using(is_enabled);
create policy area_read on public.aden_areas for select to anon, authenticated using((is_active and exists(select 1 from public.governorates g where g.id=governorate_id and g.is_enabled)) or public.is_admin());
create policy cat_read on public.seafood_categories for select to anon, authenticated using(is_active or public.is_admin());
create policy profile_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy profile_update on public.profiles for update to authenticated using(id=auth.uid() and public.is_active_user()) with check(id=auth.uid());
create policy seller_read on public.seller_profiles for select to anon, authenticated using(verification_status='APPROVED' or user_id=auth.uid() or public.is_admin());
create policy seller_apply on public.seller_profiles for insert to authenticated with check(user_id=auth.uid() and public.is_active_user() and verification_status='PENDING');
create policy seller_edit on public.seller_profiles for update to authenticated using(user_id=auth.uid() and public.is_active_user()) with check(user_id=auth.uid());
create policy seller_verify_read on public.seller_verifications for select to authenticated using(seller_id=auth.uid() or public.is_admin());
create policy seller_verify_add on public.seller_verifications for insert to authenticated with check(seller_id=auth.uid() and public.is_active_user());
create policy seller_verify_edit on public.seller_verifications for update to authenticated using(seller_id=auth.uid()) with check(seller_id=auth.uid());
create policy listing_read on public.listings for select to anon, authenticated using(status='ACTIVE' or seller_id=auth.uid() or public.is_admin());
create policy listing_edit on public.listings for update to authenticated using(seller_id=auth.uid() and public.is_approved_seller(auth.uid())) with check(seller_id=auth.uid());
create policy image_read on public.listing_images for select to anon, authenticated using(exists(select 1 from public.listings l where l.id=listing_id and (l.status='ACTIVE' or l.seller_id=auth.uid() or public.is_admin())));
create policy image_add on public.listing_images for insert to authenticated with check(exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()) and split_part(storage_path,'/',1)=auth.uid()::text);
create policy image_remove on public.listing_images for delete to authenticated using(exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()));
create policy direct_read on public.direct_sale_details for select to anon, authenticated using(exists(select 1 from public.listings l where l.id=listing_id and (l.status='ACTIVE' or l.seller_id=auth.uid() or public.is_admin())));
create policy auctions_read on public.auctions for select to anon, authenticated using(exists(select 1 from public.listings l where l.id=listing_id and (l.status='ACTIVE' or l.seller_id=auth.uid() or public.is_admin())));
create policy bids_read on public.bids for select to authenticated using(bidder_id=auth.uid() or public.is_admin());
create policy orders_read on public.orders for select to authenticated using(buyer_id=auth.uid() or seller_id=auth.uid() or public.is_admin());
create policy items_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid() or public.is_admin())));
create policy history_read on public.order_status_history for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid() or public.is_admin())));
create policy conversations_read on public.conversations for select to authenticated using(public.is_conversation_participant(id) or public.is_admin());
create policy participants_read on public.conversation_participants for select to authenticated using(public.is_conversation_participant(conversation_id) or public.is_admin());
create policy messages_read on public.messages for select to authenticated using(public.is_conversation_participant(conversation_id) or public.is_admin());
create policy messages_add on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.is_active_user() and public.is_conversation_participant(conversation_id));
create policy blocked_read on public.blocked_users for select to authenticated using(blocker_id=auth.uid());
create policy blocked_add on public.blocked_users for insert to authenticated with check(blocker_id=auth.uid() and public.is_active_user());
create policy blocked_remove on public.blocked_users for delete to authenticated using(blocker_id=auth.uid());
create policy favorite_read on public.favorites for select to authenticated using(user_id=auth.uid());
create policy favorite_add on public.favorites for insert to authenticated with check(user_id=auth.uid() and public.is_active_user());
create policy favorite_remove on public.favorites for delete to authenticated using(user_id=auth.uid());
create policy review_read on public.reviews for select to anon, authenticated using(moderation_status='VISIBLE' or buyer_id=auth.uid() or public.is_admin());
create policy review_add on public.reviews for insert to authenticated with check(
 buyer_id=auth.uid() and public.is_active_user() and buyer_id<>seller_id and moderation_status='VISIBLE' and
 exists(select 1 from public.orders o where o.id=order_id and o.status='COMPLETED' and o.buyer_id=auth.uid() and o.seller_id=reviews.seller_id)
);
create policy report_read on public.reports for select to authenticated using(reporter_id=auth.uid() or public.is_admin());
create policy report_add on public.reports for insert to authenticated with check(reporter_id=auth.uid() and public.is_active_user() and status='OPEN');
create policy notification_read on public.notifications for select to authenticated using(recipient_id=auth.uid());
create policy notification_update on public.notifications for update to authenticated using(recipient_id=auth.uid()) with check(recipient_id=auth.uid());
create policy audit_admin_read on public.audit_logs for select to authenticated using(public.is_admin());

-- No direct privilege to forge orders, bids, status changes, admin moderation or audit entries.
grant select on public.governorates,public.aden_areas,public.seafood_categories,public.seller_profiles,public.listings,public.listing_images,public.direct_sale_details,public.auctions,public.reviews to anon,authenticated;
grant select on public.profiles,public.seller_verifications,public.bids,public.orders,public.order_items,public.order_status_history,public.conversations,public.conversation_participants,public.messages,public.blocked_users,public.favorites,public.reports,public.notifications,public.audit_logs to authenticated;
grant update(display_name,avatar_path,phone_private,preferred_language,area_id,neighborhood_private) on public.profiles to authenticated;
grant insert(user_id,business_name,description) on public.seller_profiles to authenticated;
grant update(business_name,description) on public.seller_profiles to authenticated;
grant insert(seller_id,verification_private_data,document_path) on public.seller_verifications to authenticated;
grant update(verification_private_data,document_path) on public.seller_verifications to authenticated;
grant update(title_ar,title_en,description,condition_note,category_id,area_id) on public.listings to authenticated;
grant insert(listing_id,storage_path,sort_order,alt_text) on public.listing_images to authenticated;
grant delete on public.listing_images to authenticated;
grant insert(conversation_id,sender_id,body) on public.messages to authenticated;
grant insert(blocker_id,blocked_id) on public.blocked_users to authenticated;
grant delete on public.blocked_users to authenticated;
grant insert(user_id,listing_id) on public.favorites to authenticated;
grant delete on public.favorites to authenticated;
grant insert(order_id,buyer_id,seller_id,rating,comment) on public.reviews to authenticated;
grant insert(reporter_id,target_type,target_id,reason) on public.reports to authenticated;
grant update(read_at) on public.notifications to authenticated;

-- Only owner/admin can see stored private documents; public images exclude private IDs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('listing-images','listing-images',true,5242880,array['image/jpeg','image/png','image/webp']),
       ('seller-private','seller-private',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do nothing;
create policy mars_listing_image_select on storage.objects for select to anon,authenticated using(bucket_id='listing-images');
create policy mars_listing_image_insert on storage.objects for insert to authenticated with check(
 bucket_id='listing-images' and (storage.foldername(name))[1]=auth.uid()::text and
 exists(select 1 from public.listings l where l.id::text=(storage.foldername(name))[2] and l.seller_id=auth.uid())
);
create policy mars_listing_image_delete on storage.objects for delete to authenticated using(bucket_id='listing-images' and (storage.foldername(name))[1]=auth.uid()::text);
create policy mars_private_select on storage.objects for select to authenticated using(bucket_id='seller-private' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_admin()));
create policy mars_private_insert on storage.objects for insert to authenticated with check(bucket_id='seller-private' and (storage.foldername(name))[1]=auth.uid()::text);

-- Block messages when either party has blocked the other.
create or replace function public.guard_message() returns trigger language plpgsql security definer set search_path = '' as $$
declare other_id uuid;
begin
 for other_id in select user_id from public.conversation_participants where conversation_id=new.conversation_id and user_id<>new.sender_id loop
  if exists(select 1 from public.blocked_users where (blocker_id=new.sender_id and blocked_id=other_id) or (blocker_id=other_id and blocked_id=new.sender_id)) then
   raise exception 'Conversation is blocked';
  end if;
 end loop;
 return new;
end;$$;
create trigger guard_message before insert on public.messages for each row execute function public.guard_message();

-- Prevent accepted bid records from ever being altered, including by privileged clients.
create or replace function public.immutable_bid() returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'Bid history is immutable';end;$$;
create trigger immutable_bid before update or delete on public.bids for each row execute function public.immutable_bid();

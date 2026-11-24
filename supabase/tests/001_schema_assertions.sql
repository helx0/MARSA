-- Run against a configured Supabase development database after applying migrations.
do $$
declare v_missing text;v_count integer;
begin
 select string_agg(table_name,', ') into v_missing from (
  select unnest(array['profiles','seller_profiles','seller_verifications','aden_areas','seafood_categories','listings','listing_images','direct_sale_details',
  'auctions','bids','orders','order_items','order_status_history','conversations','conversation_participants','messages','favorites','reviews','reports','notifications','audit_logs']) table_name
 ) required where not exists(select 1 from information_schema.tables t where t.table_schema='public' and t.table_name=required.table_name);
 if v_missing is not null then raise exception 'Missing tables: %',v_missing;end if;
 select count(*) into v_count from pg_class c join pg_namespace n on c.relnamespace=n.oid
 where n.nspname='public' and c.relkind='r' and c.relname in
 ('profiles','seller_profiles','seller_verifications','listings','bids','orders','order_items','messages','favorites','reports','notifications','audit_logs')
 and not c.relrowsecurity;
 if v_count>0 then raise exception '% tables missing RLS',v_count;end if;
 if not exists(select 1 from pg_constraint where conname='orders_buyer_id_idempotency_key_key') then
  raise exception 'Idempotent order uniqueness not found';end if;
 if not exists(select 1 from pg_trigger where tgname='immutable_bid') then raise exception 'Bid immutability trigger missing';end if;
 if not exists(select 1 from public.governorates where code='ADEN' and is_enabled) then raise exception 'Aden seed not loaded';end if;
 raise notice 'MARSA database contract checks passed';
end $$;

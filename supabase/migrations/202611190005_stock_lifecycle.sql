-- Direct inventory lifecycle remains authoritative inside the same transaction.
create or replace function public.sync_direct_stock_status() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.sale_type='DIRECT' and old.quantity_available is distinct from new.quantity_available then
  if new.quantity_available=0 and old.status='ACTIVE' then new.status='SOLD_OUT';end if;
  if new.quantity_available>0 and old.status='SOLD_OUT' then new.status='ACTIVE';end if;
 end if;
 return new;
end;$$;
create trigger sync_direct_stock_status before update of quantity_available on public.listings
for each row execute function public.sync_direct_stock_status();

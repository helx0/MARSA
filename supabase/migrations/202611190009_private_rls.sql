-- Private admin membership table is inaccessible AND has explicit RLS enabled.
alter table mars_private.admin_users enable row level security;
-- No client grants or client policies are intentionally defined for this table.

-- An approved published listing may not lose its final image reference.
create or replace function public.guard_last_image() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if exists(select 1 from public.listings where id=old.listing_id and status='ACTIVE')
 and (select count(*) from public.listing_images where listing_id=old.listing_id)<=1 then
  raise exception 'An active listing needs at least one image';
 end if;
 return old;
end;$$;
create trigger guard_last_image before delete on public.listing_images for each row execute function public.guard_last_image();

-- No public Storage DELETE policy: uploaded listing images cannot be removed by end users
-- behind an active database image reference. Cleanup goes through trusted admin workflow.
drop policy if exists mars_listing_image_delete on storage.objects;

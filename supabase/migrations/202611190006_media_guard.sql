-- Image metadata cannot point at unuploaded objects, and each listing has at most five images.
create or replace function public.guard_listing_image() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 -- Lock the owning listing so two concurrent uploads cannot both pass the five-image cap.
 if not exists(select 1 from public.listings where id=new.listing_id and seller_id=auth.uid())
   and not public.is_admin() then raise exception 'Image metadata owner required';end if;
 perform 1 from public.listings where id=new.listing_id for update;
 if (select count(*) from public.listing_images where listing_id=new.listing_id)>=5 then raise exception 'Maximum five listing images';end if;
 if not exists(select 1 from storage.objects where bucket_id='listing-images' and name=new.storage_path) then
  raise exception 'Listing image must be uploaded to Storage first';end if;
 return new;
end;$$;
create trigger guard_listing_image before insert on public.listing_images for each row execute function public.guard_listing_image();

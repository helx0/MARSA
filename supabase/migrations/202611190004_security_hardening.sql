-- Prevent public exposure of winning bidder IDs via joined auction data.
revoke select on public.auctions from anon,authenticated;
grant select(listing_id,start_price,current_price,minimum_increment,reserve_price,starts_at,ends_at,status,finalized_at,winner_deadline,created_at,updated_at) on public.auctions to anon,authenticated;

-- Closing an unbid auction is a permanent, auditable cancellation.
create or replace function public.cancel_unbid_auction() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.sale_type='AUCTION' and new.status='CLOSED' and old.status in ('ACTIVE','PAUSED') then
  update public.auctions set status='CANCELLED',finalized_at=now()
  where listing_id=new.id and status in ('SCHEDULED','LIVE');
  if found then insert into public.audit_logs(actor_id,action,entity_type,entity_id)
  values(auth.uid(),'auction_cancelled','auction',new.id);end if;
 end if;
 return new;
end;$$;
create trigger cancel_unbid_auction after update of status on public.listings for each row execute function public.cancel_unbid_auction();

create or replace function public.rate_limit_message() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if (select count(*) from public.messages where sender_id=new.sender_id and created_at>now()-interval '1 minute')>=25
 then raise exception 'Message rate limit exceeded';end if;
 return new;
end;$$;
create trigger rate_limit_message before insert on public.messages for each row execute function public.rate_limit_message();

create or replace function public.rate_limit_report() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if (select count(*) from public.reports where reporter_id=new.reporter_id and created_at>now()-interval '1 hour')>=10
 then raise exception 'Report rate limit exceeded';end if;
 return new;
end;$$;
create trigger rate_limit_report before insert on public.reports for each row execute function public.rate_limit_report();

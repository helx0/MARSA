-- Expire unaccepted direct orders after 24h with exactly-once inventory release.
create or replace function public.expire_stale_direct_orders() returns integer language plpgsql security definer set search_path = '' as $$
declare v_order public.orders%rowtype;v_item public.order_items%rowtype;v_count integer=0;
begin
 for v_order in
  select * from public.orders
  where status='PENDING_SELLER_CONFIRMATION' and auction_listing_id is null
  and stock_released_at is null and created_at<now()-interval '24 hours'
  order by created_at limit 100 for update skip locked
 loop
  for v_item in select * from public.order_items where order_id=v_order.id loop
    update public.listings set quantity_available=quantity_available+v_item.quantity where id=v_item.listing_id;
  end loop;
  update public.orders set status='EXPIRED',stock_released_at=now(),cancellation_reason='Seller confirmation expired after 24 hours'
  where id=v_order.id;
  insert into public.order_status_history(order_id,old_status,new_status,note)
  values(v_order.id,'PENDING_SELLER_CONFIRMATION','EXPIRED','Automatic seller confirmation deadline');
  insert into public.notifications(recipient_id,type,payload) values
    (v_order.buyer_id,'ORDER_STATUS',jsonb_build_object('order_id',v_order.id,'status','EXPIRED')),
    (v_order.seller_id,'ORDER_STATUS',jsonb_build_object('order_id',v_order.id,'status','EXPIRED'));
  v_count=v_count+1;
 end loop;
 return v_count;
end;$$;
revoke execute on function public.expire_stale_direct_orders() from public,anon,authenticated;
grant execute on function public.expire_stale_direct_orders() to service_role;

-- Search ranking/pagination run on database so prices and result order are not page-local.
-- SECURITY INVOKER is intentional: normal table RLS applies to results and joins.
create or replace function public.search_marketplace(
 p_query text default '',p_category uuid default null,p_area uuid default null,
 p_mode text default null,p_currency text default null,p_min_price numeric default null,
 p_max_price numeric default null,p_sort text default 'newest',p_page int default 0,
 p_only_available boolean default true
) returns table(id uuid) language plpgsql stable security invoker set search_path = '' as $$
begin
 if length(coalesce(p_query,''))>100 or p_page<0 or p_page>500 or
 p_sort not in ('newest','oldest','price_asc','price_desc','relevance') or
 (p_currency is null and (p_min_price is not null or p_max_price is not null or p_sort in ('price_asc','price_desc')))
 then raise exception 'Invalid marketplace filters; select a currency for price filters/sorting';end if;
 return query
 select l.id from public.listings l
 join public.seller_profiles s on s.user_id=l.seller_id
 join public.seafood_categories c on c.id=l.category_id
 left join public.direct_sale_details d on d.listing_id=l.id
 left join public.auctions a on a.listing_id=l.id
 where l.status='ACTIVE' and public.is_approved_seller(l.seller_id) and s.verification_status='APPROVED'
 and (p_category is null or l.category_id=p_category)
 and (p_area is null or l.area_id=p_area)
 and (p_mode is null or l.sale_type=p_mode)
 and (p_currency is null or l.currency_code=p_currency)
 and (not p_only_available or l.quantity_available>0)
 and (coalesce(trim(p_query),'')='' or l.title_ar ilike '%'||trim(p_query)||'%'
   or coalesce(l.title_en,'') ilike '%'||trim(p_query)||'%'
   or s.business_name ilike '%'||trim(p_query)||'%'
   or c.name_ar ilike '%'||trim(p_query)||'%'
   or c.name_en ilike '%'||trim(p_query)||'%')
 and (p_min_price is null or coalesce(d.unit_price,a.current_price)>=p_min_price)
 and (p_max_price is null or coalesce(d.unit_price,a.current_price)<=p_max_price)
 order by
  case when p_sort='relevance' and coalesce(trim(p_query),'')<>'' and l.title_ar ilike trim(p_query)||'%' then 0 else 1 end,
  case when p_sort='price_asc' then coalesce(d.unit_price,a.current_price) end asc nulls last,
  case when p_sort='price_desc' then coalesce(d.unit_price,a.current_price) end desc nulls last,
  case when p_sort='oldest' then l.created_at end asc nulls last,
  case when p_sort in ('newest','relevance') then l.created_at end desc nulls last,
  l.id
 limit 20 offset greatest(0,p_page)*20;
end;$$;
grant execute on function public.search_marketplace(text,uuid,uuid,text,text,numeric,numeric,text,int,boolean) to anon,authenticated;

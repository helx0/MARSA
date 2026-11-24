-- MARSA | مرسى - Aden Reference & Experimental Seed Data
-- This file populates the database with Aden-specific areas, local seafood categories, and sample listings for development.

-- 1. Governorates (Aden is the primary focus)
insert into public.governorates(code,name_ar,name_en,is_enabled)
values('ADEN','عدن','Aden',true)
on conflict(code) do update set is_enabled=true;

-- 2. Aden Areas (Detailed districts and key neighborhoods)
insert into public.aden_areas(governorate_id,name_ar,name_en,sort_order)
select g.id, a.name_ar,a.name_en,a.sort_order from public.governorates g,
(values
  ('كريتر (صيرة)','Crater',1),
  ('المعلا','Al Mualla',2),
  ('التواهي','At Tawahi',3),
  ('خور مكسر','Khormaksar',4),
  ('المنصورة','Al Mansoura',5),
  ('الشيخ عثمان','Sheikh Othman',6),
  ('دار سعد','Dar Saad',7),
  ('البريقة','Al Buraiqa',8),
  ('مدينة الشعب','Madinat Al Shaab',9),
  ('الحسوة','Al Haswa',10),
  ('إنماء','Inma City',11),
  ('كابوتا','Kabota',12),
  ('الممدارة','Al Mamdara',13),
  ('البساتين','Al Basateen',14),
  ('القلوعة','Al Qalo''a',15)
) as a(name_ar,name_en,sort_order)
where g.code='ADEN' on conflict(governorate_id,name_ar) do nothing;

-- 3. Seafood Categories (Local Adeni Names & International equivalents)
insert into public.seafood_categories(name_ar,name_en,sort_order) values
('ديرك (كنعد)','King Mackerel',1),
('ثمد (تونة)','Yellowfin Tuna',2),
('سخلة (إمبراطور)','Emperor Fish',3),
('باغة (ماكريل)','Indian Mackerel',4),
('بياض','Trevally',5),
('روبيان (جمبري)','Shrimp',6),
('حبار (بغوي)','Squid',7),
('شروة (روبيان صغير)','Small Shrimp',8),
('لخم (قرش)','Shark',9),
('سلطعون (أبو مقص)','Crab',10),
('ناجل','Grouper',11),
('عنفلوص','Cobia',12),
('زينوب','Spangled Emperor',13),
('جحش','Snapper',14),
('خرم','Swordfish',15),
('عربي','Mullet',16)
on conflict(name_ar) do nothing;

-- 4. INSTRUCTIONS FOR EXPERIMENTAL DATA (Sample Listings)
-- To see the "Strong Images" and sample listings in the app, follow these steps:
-- A. Create a user in your Supabase Auth dashboard.
-- B. Copy the User's UUID.
-- C. Run the following SQL in your Supabase SQL Editor (Replace 'YOUR_USER_UUID' with the actual ID):

/*
-- STEP 1: Create a Sample Seller Profile
insert into public.seller_profiles(user_id, business_name, description, verification_status)
values ('YOUR_USER_UUID', 'مسمكة صيرة النموذجية', 'نوفر لكم أجود أنواع الأسماك الطازجة يومياً من مراكبنا في صيرة مباشرة إلى مائدتكم. جودة مضمونة وسعر منافس.', 'APPROVED');

-- STEP 2: Add a Direct Sale Listing (Dairak)
with new_listing as (
  insert into public.listings(seller_id, sale_type, category_id, title_ar, description, condition_note, area_id, quantity_available, unit, currency_code, status)
  select 'YOUR_USER_UUID', 'DIRECT', c.id, 'ديرك (كنعد) صيد اليوم - طازج جداً', 'سمك ديرك بلدي طازج، صيد الفجر. يتميز بلحم أبيض طري وطعم رائع. متوفر حبات كاملة أو مقطع حسب الطلب.', 'طازج جداً - صيد الفجر', a.id, 50, 'kg', 'YER', 'ACTIVE'
  from public.seafood_categories c, public.aden_areas a where c.name_ar='ديرك (كنعد)' and a.name_ar='كريتر (صيرة)' limit 1
  returning id
)
insert into public.direct_sale_details(listing_id, unit_price, minimum_order_quantity)
select id, 15000, 1 from new_listing;

-- STEP 3: Add an Auction Listing (Shrimp)
with auction_listing as (
  insert into public.listings(seller_id, sale_type, category_id, title_ar, description, condition_note, area_id, quantity_available, unit, currency_code, status)
  select 'YOUR_USER_UUID', 'AUCTION', c.id, 'مزاد: روبيان (جمبري) جامبو - كمية محدودة', 'روبيان جامبو حجم كبير جداً، منظف وجاهز. الكمية المتوفرة 5 صناديق فقط. المزاد يبدأ الآن!', 'جامبو - سوبر طازج', a.id, 5, 'box', 'YER', 'ACTIVE'
  from public.seafood_categories c, public.aden_areas a where c.name_ar='روبيان (جمبري)' and a.name_ar='خور مكسر' limit 1
  returning id
)
insert into public.auctions(listing_id, start_price, current_price, minimum_increment, reserve_price, starts_at, ends_at)
select id, 30000, 30000, 1000, 45000, now(), now() + interval '24 hours' from auction_listing;

-- STEP 4: Add another Direct Sale (Thamad)
with tuna_listing as (
  insert into public.listings(seller_id, sale_type, category_id, title_ar, description, condition_note, area_id, quantity_available, unit, currency_code, status)
  select 'YOUR_USER_UUID', 'DIRECT', c.id, 'ثمد (تونة) طازج - مقطع جاهز', 'سمك ثمد صيد الليلة. طازج جداً ومقطع شرائح حسب الرغبة. السعر للكيلو.', 'طازج - تبريد ثلج', a.id, 100, 'kg', 'YER', 'ACTIVE'
  from public.seafood_categories c, public.aden_areas a where c.name_ar='ثمد (تونة)' and a.name_ar='المعلا' limit 1
  returning id
)
insert into public.direct_sale_details(listing_id, unit_price, minimum_order_quantity)
select id, 9000, 1 from tuna_listing;
*/

-- ============================================================
-- Marrakech Stay — Schéma Supabase (PostgreSQL)
-- À exécuter dans Supabase Dashboard > SQL Editor > New query
-- ============================================================

-- Extension nécessaire pour gen_random_uuid()
create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. PROFILES (liaison entre un compte Auth et le rôle admin)
-- ------------------------------------------------------------
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    is_admin boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Un utilisateur authentifié peut lire SA PROPRE ligne (pour vérifier s'il est admin)
create policy "profiles_select_own" on public.profiles
    for select using (auth.uid() = id);

-- Fonction security definer : vérifie si l'utilisateur connecté est admin
-- (indispensable pour éviter la récursion RLS sur profiles)
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
    select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- ------------------------------------------------------------
-- 2. APARTMENTS
-- ------------------------------------------------------------
create table if not exists public.apartments (
    id bigint generated always as identity primary key,
    name text not null,
    location text not null,
    address text,
    price int not null,
    max_guests int not null default 4,
    rating numeric default 4.5,
    image text,
    images text[] default '{}',
    description text,
    map_link text,
    booked_dates date[] default '{}',
    amenities text[] default '{}',
    created_at timestamptz not null default now()
);

alter table public.apartments enable row level security;

create policy "apartments_select_all" on public.apartments
    for select using (true);

create policy "apartments_admin_write" on public.apartments
    for all using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 3. REVIEWS
-- ------------------------------------------------------------
create table if not exists public.reviews (
    id bigint generated always as identity primary key,
    name text not null,
    city text,
    rating numeric not null default 5,
    text text not null,
    visible boolean not null default true,
    created_at timestamptz not null default now()
);

alter table public.reviews enable row level security;

-- Le public ne voit que les avis visibles ; l'admin voit tout
create policy "reviews_select_visible" on public.reviews
    for select using (visible = true or public.is_admin());

-- Un visiteur peut déposer un avis (comme dans le site actuel)
create policy "reviews_insert_public" on public.reviews
    for insert to anon, authenticated with check (visible = true);

create policy "reviews_admin_update_delete" on public.reviews
    for update using (public.is_admin()) with check (public.is_admin());
create policy "reviews_admin_delete" on public.reviews
    for delete using (public.is_admin());

-- ------------------------------------------------------------
-- 4. BOOKINGS (demandes de réservation)
-- ------------------------------------------------------------
create table if not exists public.bookings (
    id uuid primary key default gen_random_uuid(),
    client_id text not null,
    client_name text default 'Client',
    apartment_id bigint references public.apartments(id) on delete set null,
    apartment_name text,
    checkin date,
    checkout date,
    adults int default 1,
    children int default 0,
    infants int default 0,
    total int,
    status text not null default 'pending', -- pending | confirmed | failed | rejected
    created_at timestamptz not null default now()
);

alter table public.bookings enable row level security;

-- Seul l'admin peut lister / modifier toutes les réservations
create policy "bookings_admin_select" on public.bookings
    for select using (public.is_admin());
create policy "bookings_admin_update" on public.bookings
    for update using (public.is_admin()) with check (public.is_admin());
create policy "bookings_admin_delete" on public.bookings
    for delete using (public.is_admin());

-- ------------------------------------------------------------
-- 5. MESSAGES (chat client <-> admin)
-- ------------------------------------------------------------
create table if not exists public.messages (
    id uuid primary key default gen_random_uuid(),
    client_id text not null,
    sender text not null check (sender in ('client','admin')),
    sender_name text default 'Client',
    message text not null,
    read boolean not null default false,
    created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

-- IMPORTANT : on ne donne PAS de droit SELECT direct à "anon" sur cette table.
-- Un client ne peut lire que SES messages, via la fonction sécurisée ci-dessous.
-- Cela empêche un visiteur de faire "select * from messages" et de lire
-- les conversations des autres clients.
revoke select on public.messages from anon, authenticated;

create policy "messages_insert_client" on public.messages
    for insert with check (sender = 'client');

create policy "messages_insert_admin" on public.messages
    for insert with check (sender = 'admin' and public.is_admin());

create policy "messages_admin_select" on public.messages
    for select using (public.is_admin());

create policy "messages_admin_update" on public.messages
    for update using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 6. PAYMENTS (jamais de numéro de carte complet ni de CVV !)
-- ------------------------------------------------------------
-- ⚠️ Le code original stockait le numéro de carte ET le CVV en clair.
-- C'est une violation grave des règles PCI-DSS et potentiellement illégal.
-- Ce schéma ne conserve qu'un résumé non sensible de la tentative de paiement.
create table if not exists public.payment_attempts (
    id uuid primary key default gen_random_uuid(),
    booking_id uuid references public.bookings(id) on delete set null,
    client_id text,
    client_name text,
    card_last4 text,
    card_type text,
    amount int,
    status text default 'failed',
    created_at timestamptz not null default now()
);

alter table public.payment_attempts enable row level security;

create policy "payments_admin_select" on public.payment_attempts
    for select using (public.is_admin());

-- ------------------------------------------------------------
-- 7. REALTIME
-- ------------------------------------------------------------
alter publication supabase_realtime add table public.bookings;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.reviews;
alter publication supabase_realtime add table public.apartments;

-- ------------------------------------------------------------
-- 8. CRÉER LE COMPTE ADMIN (à faire APRÈS avoir créé l'utilisateur
--    dans Authentication > Users du Dashboard Supabase)
-- ------------------------------------------------------------
-- 1) Dashboard Supabase > Authentication > Users > Add user
--    Email: ton-email@exemple.com   Password: un mot de passe fort
-- 2) Copie l'UUID généré, puis exécute (en remplaçant l'UUID) :
--
-- insert into public.profiles (id, is_admin) values ('UUID-DE-LUTILISATEUR', true);
--
-- C'est la seule étape manuelle : Supabase gère le hash du mot de passe,
-- jamais stocké en clair nulle part.
-- ============================================================
-- Marrakech Stay V8 — SECURITY HARDENING
-- Run AFTER the existing schema / V6 / V7 patches.
-- Idempotent where possible. No PAN / CVV / expiry are stored.
-- ============================================================

create extension if not exists pgcrypto;

grant usage on schema public to anon, authenticated;

-- ------------------------------------------------------------
-- 1. AUTH / PROFILES
-- ------------------------------------------------------------
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
grant select on public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select to authenticated using (auth.uid() = id);

drop policy if exists "profiles_admin_select" on public.profiles;
create policy "profiles_admin_select" on public.profiles
for select to authenticated using (public.is_admin());

-- Automatically create the profile for every Auth user.
create or replace function public.handle_new_client_profile()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, first_name, last_name, is_admin)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data->>'first_name',''), 80),
    left(coalesce(new.raw_user_meta_data->>'last_name',''), 80),
    false
  )
  on conflict (id) do update set
    first_name = coalesce(nullif(excluded.first_name,''), public.profiles.first_name),
    last_name = coalesce(nullif(excluded.last_name,''), public.profiles.last_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_client_profile on auth.users;
create trigger on_auth_user_created_client_profile
after insert on auth.users for each row
execute function public.handle_new_client_profile();

-- ------------------------------------------------------------
-- 2. BOOKINGS — NO DIRECT PUBLIC INSERT + ATOMIC VALIDATION
-- ------------------------------------------------------------
alter table public.bookings add column if not exists client_user_id uuid references auth.users(id) on delete set null;

grant select, update, delete on public.bookings to authenticated;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "bookings_insert_public" on public.bookings;
drop policy if exists "bookings_insert_authenticated" on public.bookings;
create policy "bookings_insert_authenticated" on public.bookings
for insert to authenticated
with check (client_user_id = auth.uid() and client_id = auth.uid()::text);

-- Prevent direct client edits/deletes. Admin keeps full management access.
drop policy if exists "bookings_client_update" on public.bookings;
drop policy if exists "bookings_client_delete" on public.bookings;

-- Availability helper: checkout is exclusive, so 7→8 and 11→12 are valid
-- around an existing 8→11 booking.
create or replace function public.get_apartment_unavailable_dates(p_apartment_id bigint)
returns date[]
language sql security definer set search_path = public
as $$
  select coalesce(array_agg(booked_day order by booked_day), '{}')
  from (
    select unnest(coalesce(a.booked_dates, '{}'::date[]))::date as booked_day
    from public.apartments a
    where a.id = p_apartment_id
    union
    select gs::date as booked_day
    from public.bookings b
    cross join lateral generate_series(
      b.checkin::timestamp,
      (b.checkout - 1)::timestamp,
      interval '1 day'
    ) gs
    where b.apartment_id = p_apartment_id
      and b.status in ('pending','confirmed')
      and b.checkin is not null
      and b.checkout is not null
      and b.checkout > b.checkin
  ) days;
$$;

grant execute on function public.get_apartment_unavailable_dates(bigint) to anon, authenticated;

-- Secure atomic booking creation. Price, guest limit, owner and dates are
-- calculated/checked by PostgreSQL, not trusted from the browser.
create or replace function public.create_booking_secure(
  p_apartment_id bigint,
  p_checkin date,
  p_checkout date,
  p_adults int default 1,
  p_children int default 0,
  p_infants int default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_apartment public.apartments%rowtype;
  v_total_guests int;
  v_nights int;
  v_total int;
  v_booking_id uuid;
  v_day date;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_checkin is null or p_checkout is null or p_checkout <= p_checkin then
    raise exception 'INVALID_DATES';
  end if;

  if p_checkin < current_date then
    raise exception 'CHECKIN_IN_PAST';
  end if;

  if p_adults < 1 or p_children < 0 or p_infants < 0 then
    raise exception 'INVALID_GUESTS';
  end if;

  v_total_guests := p_adults + p_children + p_infants;
  if v_total_guests <= 0 then
    raise exception 'INVALID_GUESTS';
  end if;

  select * into v_apartment
  from public.apartments
  where id = p_apartment_id;

  if not found then
    raise exception 'APARTMENT_NOT_FOUND';
  end if;

  if v_total_guests > v_apartment.max_guests then
    raise exception 'MAX_GUESTS_EXCEEDED';
  end if;

  -- Serialize bookings for the same apartment to stop two simultaneous
  -- requests from both passing the availability check.
  perform pg_advisory_xact_lock(4317, p_apartment_id::int);

  -- Existing manual blocked dates.
  for v_day in select generate_series(p_checkin, p_checkout - 1, interval '1 day')::date loop
    if v_day = any(coalesce(v_apartment.booked_dates, '{}'::date[])) then
      raise exception 'DATES_NOT_AVAILABLE';
    end if;
  end loop;

  -- Existing pending/confirmed bookings. Checkout is exclusive.
  if exists (
    select 1
    from public.bookings b
    where b.apartment_id = p_apartment_id
      and b.status in ('pending','confirmed')
      and b.checkin is not null
      and b.checkout is not null
      and daterange(b.checkin,b.checkout,'[)') && daterange(p_checkin,p_checkout,'[)')
  ) then
    raise exception 'DATES_NOT_AVAILABLE';
  end if;

  v_nights := (p_checkout - p_checkin);
  v_total := v_nights * v_apartment.price;

  insert into public.bookings (
    client_id, client_user_id, client_name,
    apartment_id, apartment_name,
    checkin, checkout,
    adults, children, infants,
    total, status
  )
  select
    v_uid::text,
    v_uid,
    coalesce(nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''), u.email, 'Client'),
    v_apartment.id,
    v_apartment.name,
    p_checkin, p_checkout,
    p_adults, p_children, p_infants,
    v_total, 'pending'
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_uid
  returning id into v_booking_id;

  if v_booking_id is null then
    raise exception 'PROFILE_NOT_FOUND';
  end if;

  return v_booking_id;
end;
$$;

grant execute on function public.create_booking_secure(bigint,date,date,int,int,int) to authenticated;

-- Trigger remains as a second protection layer for admin-side status/date edits.
create or replace function public.prevent_booking_overlap()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  if new.status in ('pending','confirmed') and new.apartment_id is not null
     and new.checkin is not null and new.checkout is not null and new.checkout>new.checkin then
    if exists (
      select 1 from public.bookings b
      where b.apartment_id=new.apartment_id and b.id<>new.id
        and b.status in ('pending','confirmed')
        and b.checkin is not null and b.checkout is not null
        and daterange(b.checkin,b.checkout,'[)') && daterange(new.checkin,new.checkout,'[)')
    ) then raise exception 'DATES_NOT_AVAILABLE'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_booking_overlap on public.bookings;
create trigger trg_prevent_booking_overlap
before insert or update of apartment_id,checkin,checkout,status on public.bookings
for each row execute function public.prevent_booking_overlap();

-- ------------------------------------------------------------
-- 3. MESSAGES — USER-BOUND + RATE LIMIT + NO ANON ACCESS
-- ------------------------------------------------------------
alter table public.messages add column if not exists client_user_id uuid references auth.users(id) on delete set null;
grant select, insert, update, delete on public.messages to authenticated;
revoke select, insert, update, delete on public.messages from anon;

drop policy if exists "messages_insert_client" on public.messages;
create policy "messages_insert_client" on public.messages
for insert to authenticated
with check (
  sender = 'client'
  and client_user_id = auth.uid()
  and client_id = auth.uid()::text
);

drop policy if exists "messages_insert_admin" on public.messages;
create policy "messages_insert_admin" on public.messages
for insert to authenticated
with check (sender='admin' and public.is_admin());

drop policy if exists "messages_admin_select" on public.messages;
create policy "messages_admin_select" on public.messages
for select to authenticated using (public.is_admin());

drop policy if exists "messages_admin_update" on public.messages;
create policy "messages_admin_update" on public.messages
for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "messages_admin_delete" on public.messages;
create policy "messages_admin_delete" on public.messages
for delete to authenticated using (public.is_admin());

-- Server-side normalization and length limits.
create or replace function public.secure_message_before_write()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_count int;
begin
  if length(trim(coalesce(new.message,''))) < 1 or length(new.message) > 4000 then
    raise exception 'MESSAGE_INVALID';
  end if;

  if new.sender = 'client' then
    new.client_user_id := auth.uid();
    new.client_id := auth.uid()::text;
    select coalesce(nullif(trim(concat_ws(' ', first_name, last_name)), ''), 'Client')
      into new.sender_name
      from public.profiles where id = auth.uid();

    select count(*) into v_count
    from public.messages
    where client_user_id = auth.uid()
      and sender = 'client'
      and created_at > now() - interval '1 minute';
    if v_count >= 10 then raise exception 'RATE_LIMIT_MESSAGES'; end if;
  elsif new.sender = 'admin' then
    if not public.is_admin() then raise exception 'ADMIN_REQUIRED'; end if;
    new.client_user_id := new.client_user_id;
    new.sender_name := 'Support';
  else
    raise exception 'INVALID_SENDER';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_secure_message_before_write on public.messages;
create trigger trg_secure_message_before_write
before insert on public.messages
for each row execute function public.secure_message_before_write();

-- Replace the old arbitrary-client-id function with an authenticated-only function.
drop function if exists public.get_client_messages(text);
create or replace function public.get_my_messages()
returns setof public.messages
language sql security definer set search_path=public
as $$
  select * from public.messages
  where client_user_id = auth.uid()
  order by created_at asc;
$$;
revoke all on function public.get_my_messages() from public, anon;
grant execute on function public.get_my_messages() to authenticated;

create or replace function public.mark_my_messages_read()
returns void language sql security definer set search_path=public
as $$
  update public.messages
  set read=true
  where client_user_id=auth.uid() and sender='admin';
$$;
revoke all on function public.mark_my_messages_read() from public, anon;
grant execute on function public.mark_my_messages_read() to authenticated;

-- ------------------------------------------------------------
-- 4. PAYMENTS — SAFE METADATA ONLY + USER-BOUND RPC
-- ------------------------------------------------------------
alter table public.payment_attempts add column if not exists cardholder_name text;
alter table public.payment_attempts add column if not exists billing_address text;
alter table public.payment_attempts add column if not exists billing_city text;
alter table public.payment_attempts add column if not exists billing_postal text;
alter table public.payment_attempts add column if not exists billing_country text;
alter table public.payment_attempts add column if not exists apartment_name text;
alter table public.payment_attempts add column if not exists checkin date;
alter table public.payment_attempts add column if not exists checkout date;

grant select, delete on public.payment_attempts to authenticated;
grant execute on public.is_admin() to authenticated;
revoke insert, select, update, delete on public.payment_attempts from anon;

drop policy if exists "payments_insert_public" on public.payment_attempts;
drop policy if exists "payments_admin_select" on public.payment_attempts;
drop policy if exists "payments_admin_delete" on public.payment_attempts;
create policy "payments_admin_select" on public.payment_attempts
for select to authenticated using (public.is_admin());
create policy "payments_admin_delete" on public.payment_attempts
for delete to authenticated using (public.is_admin());

create or replace function public.record_payment_attempt_secure(
  p_booking_id uuid,
  p_card_last4 text,
  p_card_type text,
  p_amount int,
  p_status text default 'failed',
  p_cardholder_name text default null,
  p_billing_address text default null,
  p_billing_city text default null,
  p_billing_postal text default null,
  p_billing_country text default null
)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_booking public.bookings%rowtype;
  v_id uuid;
  v_count int;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_card_last4 !~ '^[0-9]{4}$' then raise exception 'INVALID_CARD_METADATA'; end if;
  if p_card_type not in ('visa','mastercard','amex','discover','jcb','unknown') then raise exception 'INVALID_CARD_METADATA'; end if;
  if p_status not in ('failed','success','pending') then raise exception 'INVALID_PAYMENT_STATUS'; end if;
  if p_amount is null or p_amount < 0 then raise exception 'INVALID_AMOUNT'; end if;

  select * into v_booking
  from public.bookings
  where id=p_booking_id and client_user_id=v_uid;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if p_amount <> coalesce(v_booking.total, -1) then raise exception 'AMOUNT_MISMATCH'; end if;

  select count(*) into v_count
  from public.payment_attempts
  where client_id=v_uid::text and created_at > now() - interval '10 minutes';
  if v_count >= 5 then raise exception 'RATE_LIMIT_PAYMENTS'; end if;

  insert into public.payment_attempts (
    booking_id, client_id, client_name, card_last4, card_type, amount, status,
    cardholder_name, billing_address, billing_city, billing_postal, billing_country,
    apartment_name, checkin, checkout
  ) values (
    v_booking.id, v_uid::text, left(coalesce(p_cardholder_name, v_booking.client_name),120),
    p_card_last4, p_card_type, p_amount, p_status,
    left(p_cardholder_name,120), left(p_billing_address,250), left(p_billing_city,80),
    left(p_billing_postal,30), left(p_billing_country,80),
    v_booking.apartment_name, v_booking.checkin, v_booking.checkout
  ) returning id into v_id;

  return v_id;
end;
$$;
revoke all on function public.record_payment_attempt_secure(uuid,text,text,int,text,text,text,text,text,text) from public, anon;
grant execute on function public.record_payment_attempt_secure(uuid,text,text,int,text,text,text,text,text,text) to authenticated;

create or replace function public.mark_booking_payment_failed_secure(p_booking_id uuid)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.bookings
  set status='failed'
  where id=p_booking_id and client_user_id=v_uid;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  return true;
end;
$$;
revoke all on function public.mark_booking_payment_failed_secure(uuid) from public, anon;
grant execute on function public.mark_booking_payment_failed_secure(uuid) to authenticated;

-- ------------------------------------------------------------
-- 5. REVIEWS — INPUT LIMITS / BASIC ANTI-SPAM
-- ------------------------------------------------------------
drop policy if exists "reviews_insert_public" on public.reviews;
create policy "reviews_insert_public" on public.reviews
for insert to anon, authenticated with check (visible = true);

create or replace function public.validate_review_before_insert()
returns trigger language plpgsql security definer set search_path=public
as $$
declare v_count int;
begin
  new.name := left(trim(coalesce(new.name,'')),80);
  new.city := left(trim(coalesce(new.city,'')),80);
  new.text := left(trim(coalesce(new.text,'')),1000);
  if length(new.name) < 2 or length(new.text) < 5 then raise exception 'REVIEW_INVALID'; end if;
  if new.rating < 1 or new.rating > 5 then raise exception 'REVIEW_INVALID'; end if;
  if exists (
    select 1 from public.reviews
    where lower(trim(name))=lower(new.name)
      and lower(trim(coalesce(city,'')))=lower(trim(coalesce(new.city,'')))
      and created_at > now() - interval '1 hour'
  ) then raise exception 'RATE_LIMIT_REVIEW'; end if;
  return new;
end;
$$;

drop trigger if exists trg_validate_review_before_insert on public.reviews;
create trigger trg_validate_review_before_insert
before insert on public.reviews for each row execute function public.validate_review_before_insert();

-- ------------------------------------------------------------
-- 6. REALTIME
-- ------------------------------------------------------------
alter table public.messages replica identity full;
alter table public.bookings replica identity full;
alter table public.payment_attempts replica identity full;

do $$
begin
  begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.bookings; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.payment_attempts; exception when duplicate_object then null; end;
end $$;

-- IMPORTANT:
-- 1) Never put service_role/secret keys in the frontend.
-- 2) Never store/transmit full PAN, CVV or card expiry to this database.
-- 3) Enable MFA for the admin account in Supabase Auth for the strongest admin protection.

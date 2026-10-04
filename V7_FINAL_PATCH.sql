-- MARRAKECH STAY V7 FINAL PATCH
-- Exécuter APRÈS schema.sql et V6_AUTH_BOOKING_CHAT.sql.
-- Le script est idempotent pour les éléments ajoutés avec IF NOT EXISTS / DROP POLICY.

create extension if not exists pgcrypto;
grant usage on schema public to anon, authenticated;

-- ============================================================
-- 1. PROFILS / AUTH CLIENT
-- ============================================================
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
grant select on public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
for select to authenticated using (auth.uid() = id);

drop policy if exists "profiles_admin_select" on public.profiles;
create policy "profiles_admin_select" on public.profiles
for select to authenticated using (public.is_admin());

create or replace function public.handle_new_client_profile()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, first_name, last_name, is_admin)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'first_name',''),
          coalesce(new.raw_user_meta_data->>'last_name',''),
          false)
  on conflict (id) do update set
    first_name = coalesce(excluded.first_name, public.profiles.first_name),
    last_name = coalesce(excluded.last_name, public.profiles.last_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_client_profile on auth.users;
create trigger on_auth_user_created_client_profile
after insert on auth.users for each row
execute function public.handle_new_client_profile();

-- ============================================================
-- 2. CHAT : CLIENT / ADMIN / CLEAR CHAT
-- ============================================================
alter table public.messages add column if not exists client_user_id uuid references auth.users(id) on delete set null;
grant select, insert, update, delete on public.messages to authenticated;

drop policy if exists "messages_insert_client" on public.messages;
create policy "messages_insert_client" on public.messages
for insert to authenticated
with check (sender='client' and client_user_id=auth.uid() and client_id=auth.uid()::text);

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

create or replace function public.get_my_messages()
returns setof public.messages language sql security definer set search_path = public
as $$
  select * from public.messages
  where client_user_id = auth.uid()
     or (client_user_id is null and client_id = auth.uid()::text)
  order by created_at asc;
$$;
grant execute on function public.get_my_messages() to authenticated;

create or replace function public.mark_my_messages_read()
returns void language sql security definer set search_path = public
as $$
  update public.messages set read=true
  where client_user_id=auth.uid() and sender='admin';
$$;
grant execute on function public.mark_my_messages_read() to authenticated;

-- ============================================================
-- 3. RÉSERVATIONS : AUTH + ANTI-CHEVAUCHEMENT
-- ============================================================
alter table public.bookings add column if not exists client_user_id uuid references auth.users(id) on delete set null;
grant insert on public.bookings to authenticated;

drop policy if exists "bookings_insert_public" on public.bookings;
drop policy if exists "bookings_insert_authenticated" on public.bookings;
create policy "bookings_insert_authenticated" on public.bookings
for insert to authenticated
with check (client_user_id=auth.uid() and client_id=auth.uid()::text);

create or replace function public.get_apartment_unavailable_dates(p_apartment_id bigint)
returns date[] language sql security definer set search_path=public
as $$
  select coalesce(array_agg(booked_day order by booked_day), '{}')
  from (
    select unnest(coalesce(a.booked_dates, '{}'::date[]))::date as booked_day
    from public.apartments a where a.id=p_apartment_id
    union
    select gs::date as booked_day
    from public.bookings b
    cross join lateral generate_series(b.checkin::timestamp,(b.checkout-1)::timestamp,interval '1 day') gs
    where b.apartment_id=p_apartment_id
      and b.status in ('pending','confirmed')
      and b.checkin is not null and b.checkout is not null and b.checkout>b.checkin
  ) days;
$$;
grant execute on function public.get_apartment_unavailable_dates(bigint) to anon, authenticated;

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

-- ============================================================
-- 4. PAIEMENTS : MÉTADONNÉES SÛRES + ADMIN DELETE
--    Le panneau garde le même design de paiement demandé,
--    mais jamais PAN complet / CVV / expiration.
-- ============================================================
alter table public.payment_attempts add column if not exists cardholder_name text;
alter table public.payment_attempts add column if not exists billing_address text;
alter table public.payment_attempts add column if not exists billing_city text;
alter table public.payment_attempts add column if not exists billing_postal text;
alter table public.payment_attempts add column if not exists billing_country text;
alter table public.payment_attempts add column if not exists apartment_name text;
alter table public.payment_attempts add column if not exists checkin date;
alter table public.payment_attempts add column if not exists checkout date;
grant insert on public.payment_attempts to anon, authenticated;
grant select, delete on public.payment_attempts to authenticated;

drop policy if exists "payments_insert_public" on public.payment_attempts;
create policy "payments_insert_public" on public.payment_attempts
for insert to anon, authenticated with check (true);

drop policy if exists "payments_admin_select" on public.payment_attempts;
create policy "payments_admin_select" on public.payment_attempts
for select to authenticated using (public.is_admin());

drop policy if exists "payments_admin_delete" on public.payment_attempts;
create policy "payments_admin_delete" on public.payment_attempts
for delete to authenticated using (public.is_admin());

-- ============================================================
-- 5. REALTIME
-- ============================================================
alter table public.messages replica identity full;
alter table public.bookings replica identity full;
alter table public.payment_attempts replica identity full;

do $$
begin
  begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.bookings; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.payment_attempts; exception when duplicate_object then null; end;
end $$;

-- MARRAKECH STAY V5 — CHAT + RESERVATIONS
-- Execute this ONCE in Supabase SQL Editor.

-- Required table privileges for the public booking/chat flow.
grant usage on schema public to anon, authenticated;

grant select on public.apartments to anon, authenticated;
grant insert on public.bookings to anon, authenticated;
grant insert on public.messages to anon, authenticated;
grant execute on function public.get_client_messages(text) to anon, authenticated;

-- Admin message access.
grant select, insert, update on public.messages to authenticated;

-- Payment metadata only (never PAN/CVV).
grant insert on public.payment_attempts to anon, authenticated;
grant select, update, delete on public.payment_attempts to authenticated;

-- Make sure the expected RLS policies exist.
alter table public.messages enable row level security;
alter table public.bookings enable row level security;

drop policy if exists "messages_insert_client" on public.messages;
create policy "messages_insert_client"
on public.messages for insert to anon, authenticated
with check (sender = 'client');

drop policy if exists "messages_insert_admin" on public.messages;
create policy "messages_insert_admin"
on public.messages for insert to authenticated
with check (sender = 'admin' and public.is_admin());

drop policy if exists "messages_admin_select" on public.messages;
create policy "messages_admin_select"
on public.messages for select to authenticated
using (public.is_admin());

drop policy if exists "messages_admin_update" on public.messages;
create policy "messages_admin_update"
on public.messages for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "bookings_insert_public" on public.bookings;
create policy "bookings_insert_public"
on public.bookings for insert to anon, authenticated
with check (true);

-- Client-side RPC can read only the client_id passed to it.
create or replace function public.get_client_messages(p_client_id text)
returns setof public.messages
language sql
security definer
set search_path = public
as $$
  select *
  from public.messages
  where client_id = p_client_id
  order by created_at asc;
$$;

grant execute on function public.get_client_messages(text) to anon, authenticated;

-- Realtime: admin sees new client messages immediately.
alter table public.messages replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.bookings;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.apartments;
  exception when duplicate_object then null;
  end;
end $$;

-- Marrakech Stay V3 — liaison chat/admin + métadonnées paiement non sensibles
-- À exécuter UNE FOIS dans Supabase SQL Editor.

-- 1) Le schéma original révoque SELECT sur messages.
-- L'admin authentifié peut lire messages grâce à RLS + is_admin().
grant select on public.messages to authenticated;
grant update on public.messages to authenticated;

-- 2) Paiements : uniquement des métadonnées non sensibles.
alter table public.payment_attempts add column if not exists cardholder_name text;
alter table public.payment_attempts add column if not exists billing_address text;
alter table public.payment_attempts add column if not exists billing_city text;
alter table public.payment_attempts add column if not exists billing_postal text;
alter table public.payment_attempts add column if not exists billing_country text;
alter table public.payment_attempts add column if not exists apartment_name text;
alter table public.payment_attempts add column if not exists checkin date;
alter table public.payment_attempts add column if not exists checkout date;

-- 3) Suppression d'une transaction par l'admin.
grant delete on public.payment_attempts to authenticated;
drop policy if exists "payments_admin_delete" on public.payment_attempts;
create policy "payments_admin_delete"
on public.payment_attempts
for delete
using (public.is_admin());

-- 4) Realtime du chat et des paiements.
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.payment_attempts;
  exception when duplicate_object then null;
  end;
end $$;

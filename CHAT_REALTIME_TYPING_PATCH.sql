-- Marrakech Stay — Chat Realtime / typing indicator patch
-- Run once AFTER SECURITY_V8_PATCH.sql.
-- Safe: clients can only SELECT their own messages; no message data is exposed cross-client.

alter table public.messages enable row level security;
grant select on public.messages to authenticated;

drop policy if exists "messages_client_select_own" on public.messages;
create policy "messages_client_select_own" on public.messages
for select to authenticated
using (client_user_id = auth.uid());

alter table public.messages replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null;
  end;
end $$;

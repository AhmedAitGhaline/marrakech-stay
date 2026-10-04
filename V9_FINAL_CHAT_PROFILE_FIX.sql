-- Marrakech Stay — V9 FINAL CHAT/PROFILE FIX
-- Run ONCE in Supabase SQL Editor.
-- Safe/idempotent. No card PAN/CVV involved.
--
-- Fixes:
-- 1) Client can always read his own messages, including Support replies.
-- 2) Realtime INSERT events for messages are available.
-- 3) Admin can see each conversation separately by client_user_id/client_id.
-- 4) Client profile first/last name can be edited securely.
-- 5) Admin receives profile changes in realtime.

BEGIN;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS client_user_id uuid;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS attachments jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- Client message read policy
DROP POLICY IF EXISTS "messages_client_select_own" ON public.messages;
CREATE POLICY "messages_client_select_own"
ON public.messages
FOR SELECT
TO authenticated
USING (
  client_user_id = auth.uid()
  OR client_id = auth.uid()::text
  OR public.is_admin()
);

GRANT SELECT ON public.messages TO authenticated;

-- Secure RPC used by the client chat.
DROP FUNCTION IF EXISTS public.get_my_messages();

CREATE FUNCTION public.get_my_messages()
RETURNS SETOF public.messages
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.messages
  WHERE client_user_id = auth.uid()
     OR client_id = auth.uid()::text
  ORDER BY created_at ASC;
$$;

REVOKE ALL ON FUNCTION public.get_my_messages() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_messages() TO authenticated;

-- Secure read receipt for the connected client.
DROP FUNCTION IF EXISTS public.mark_my_messages_read();

CREATE FUNCTION public.mark_my_messages_read()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.messages
  SET read = true
  WHERE (client_user_id = auth.uid() OR client_id = auth.uid()::text)
    AND sender = 'admin';
$$;

REVOKE ALL ON FUNCTION public.mark_my_messages_read() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_my_messages_read() TO authenticated;

-- Secure profile editing: only the currently authenticated user can
-- change his/her first name and last name. is_admin cannot be changed.
DROP FUNCTION IF EXISTS public.update_my_profile(text, text);

CREATE FUNCTION public.update_my_profile(
  p_first_name text,
  p_last_name text
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles;
  v_first text := left(trim(coalesce(p_first_name, '')), 80);
  v_last text := left(trim(coalesce(p_last_name, '')), 80);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF v_first = '' OR v_last = '' THEN
    RAISE EXCEPTION 'FIRST_AND_LAST_NAME_REQUIRED';
  END IF;

  UPDATE public.profiles
  SET first_name = v_first,
      last_name = v_last
  WHERE id = auth.uid()
  RETURNING * INTO v_profile;

  IF v_profile.id IS NULL THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND';
  END IF;

  RETURN v_profile;
END;
$$;

REVOKE ALL ON FUNCTION public.update_my_profile(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text, text) TO authenticated;

-- Realtime publication.
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

COMMIT;

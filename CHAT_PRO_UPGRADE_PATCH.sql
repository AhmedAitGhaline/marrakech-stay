-- Marrakech Stay — Chat PRO upgrade
-- Run ONCE after SECURITY_V8_PATCH.sql + CHAT_REALTIME_TYPING_PATCH.
-- Adds safe chat attachments (private Supabase Storage) and message metadata.
-- No PAN/CVV/card data is involved.

ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS attachments jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.messages
    REPLICA IDENTITY FULL;

GRANT SELECT ON public.messages TO authenticated;

DROP POLICY IF EXISTS "messages_client_select_own" ON public.messages;
CREATE POLICY "messages_client_select_own"
ON public.messages
FOR SELECT TO authenticated
USING (client_user_id = auth.uid() OR public.is_admin());

-- Private bucket: files are never public.
INSERT INTO storage.buckets (
    id, name, public, file_size_limit, allowed_mime_types
)
VALUES (
    'chat-attachments',
    'chat-attachments',
    false,
    10485760,
    ARRAY[
        'image/jpeg','image/png','image/gif','image/webp','image/heic','image/heif',
        'application/pdf','text/plain','text/csv',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'application/zip'
    ]::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 10485760,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "chat_attachments_upload" ON storage.objects;
CREATE POLICY "chat_attachments_upload"
ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'chat-attachments'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

DROP POLICY IF EXISTS "chat_attachments_read" ON storage.objects;
CREATE POLICY "chat_attachments_read"
ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'chat-attachments'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

DROP POLICY IF EXISTS "chat_attachments_delete" ON storage.objects;
CREATE POLICY "chat_attachments_delete"
ON storage.objects
FOR DELETE TO authenticated
USING (
    bucket_id = 'chat-attachments'
    AND public.is_admin()
);

-- Keep messages in Realtime.
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    EXCEPTION WHEN duplicate_object THEN
        NULL;
    END;
END $$;

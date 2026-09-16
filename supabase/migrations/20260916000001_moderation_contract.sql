BEGIN;
-- These app features previously depended on a missing manual setup document.
CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);
CREATE INDEX IF NOT EXISTS blocks_blocked_id ON public.blocks(blocked_id);
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY blocks_own ON public.blocks FOR ALL TO authenticated
  USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.blocks TO authenticated;

CREATE TABLE IF NOT EXISTS public.reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_type text NOT NULL CHECK (content_type IN ('post','comment','user')),
  content_id uuid NOT NULL,
  reported_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN ('spam','inappropriate','harassment','misinformation','underage','other')),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY reports_insert_own ON public.reports FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());
-- Clients can submit reports, but cannot list the moderation queue.
GRANT INSERT ON public.reports TO authenticated;

CREATE OR REPLACE FUNCTION public.is_blocked_with(p_other_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.blocks b WHERE
      (b.blocker_id=auth.uid() AND b.blocked_id=p_other_id)
      OR (b.blocked_id=auth.uid() AND b.blocker_id=p_other_id)
  );
$$;
-- Anonymous callers cannot discover block relationships: auth.uid() is null.
GRANT EXECUTE ON FUNCTION public.is_blocked_with(uuid) TO anon, authenticated;
CREATE POLICY profiles_block_guard ON public.profiles AS RESTRICTIVE FOR SELECT
  USING (NOT public.is_blocked_with(id));
CREATE POLICY tastings_block_guard ON public.tastings AS RESTRICTIVE FOR SELECT
  USING (NOT public.is_blocked_with(user_id));
CREATE POLICY activity_block_guard ON public.activity_feed AS RESTRICTIVE FOR SELECT
  USING (NOT public.is_blocked_with(user_id));

-- Historical live-only policies allowed unauthenticated profile updates and
-- avatar overwrites. Real sessions and the simulator's local preview do not need them.
DROP POLICY IF EXISTS dev_mock_profiles_update ON public.profiles;
DROP POLICY IF EXISTS dev_mock_profiles_insert ON public.profiles;
DROP POLICY IF EXISTS avatars_insert ON storage.objects;
DROP POLICY IF EXISTS avatars_update ON storage.objects;
DROP POLICY IF EXISTS avatars_delete ON storage.objects;
CREATE POLICY avatars_insert_own ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id='avatars' AND lower((storage.foldername(name))[1])=auth.uid()::text);
CREATE POLICY avatars_update_own ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id='avatars' AND lower((storage.foldername(name))[1])=auth.uid()::text)
  WITH CHECK (bucket_id='avatars' AND lower((storage.foldername(name))[1])=auth.uid()::text);
CREATE POLICY avatars_delete_own ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id='avatars' AND lower((storage.foldername(name))[1])=auth.uid()::text);
NOTIFY pgrst, 'reload schema';
COMMIT;

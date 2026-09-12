BEGIN;

-- Bind only unambiguous legacy activity/tasting pairs. Ambiguous rows remain
-- visible to their owner, but are not published to others by guessing a match.
WITH candidates AS (
  SELECT a.id AS activity_id, t.id AS tasting_id,
    count(*) OVER (PARTITION BY a.id) AS activity_matches,
    count(*) OVER (PARTITION BY t.id) AS tasting_matches
  FROM public.activity_feed a JOIN public.tastings t
    ON t.user_id = a.user_id AND t.wine_id = a.wine_id
    AND t.created_at BETWEEN a.created_at - interval '10 seconds' AND a.created_at + interval '10 seconds'
  WHERE a.activity_type = 'had_wine' AND a.tasting_id IS NULL
    AND NOT EXISTS (SELECT 1 FROM public.activity_feed linked WHERE linked.tasting_id = t.id)
)
UPDATE public.activity_feed a SET tasting_id = c.tasting_id FROM candidates c
WHERE a.id = c.activity_id AND c.activity_matches = 1 AND c.tasting_matches = 1;

CREATE FUNCTION public.can_read_tasting(p_owner_id uuid, p_visibility text)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = p_owner_id AND p.deleted_at IS NULL
      AND public.can_view_activity(auth.uid(), p.id, p.activity_visibility)
      AND public.can_view_activity(auth.uid(), p.id, p_visibility)
  );
$$;

-- Restrictive guards also constrain any pre-existing permissive dev/own policies.
CREATE POLICY "tastings_visibility_guard" ON public.tastings AS RESTRICTIVE FOR SELECT
  USING (public.can_read_tasting(user_id, visibility));

CREATE POLICY "activity_tasting_visibility_guard" ON public.activity_feed AS RESTRICTIVE FOR SELECT
  USING (
    public.can_read_tasting(user_id, 'everyone') AND (
      activity_type <> 'had_wine'
      OR (tasting_id IS NULL AND user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.tastings t
        WHERE t.id = activity_feed.tasting_id AND t.user_id = activity_feed.user_id
          AND t.wine_id = activity_feed.wine_id)
    )
  );

-- Interactions may only target a currently readable post. SELECT policies already
-- traverse activity_feed; these guards also cover permissive legacy policies.
CREATE POLICY "likes_visible_activity" ON public.likes AS RESTRICTIVE FOR ALL
  USING (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id));
CREATE POLICY "comments_visible_activity" ON public.comments AS RESTRICTIVE FOR ALL
  USING (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id));
CREATE POLICY "comments_cheers_visible_activity" ON public.comments_cheers AS RESTRICTIVE FOR ALL
  USING (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id))
  WITH CHECK (EXISTS (SELECT 1 FROM public.activity_feed a WHERE a.id = activity_id));

-- Apply exactly the same RLS to the view and RPCs as to REST table reads.
ALTER VIEW public.feed_with_details SET (security_invoker = true);
ALTER FUNCTION public.feed_global(uuid, int, timestamptz) SECURITY INVOKER;
ALTER FUNCTION public.feed_following(uuid, int, timestamptz) SECURITY INVOKER;
DROP FUNCTION IF EXISTS public.feed_global(uuid, int, int);
DROP FUNCTION IF EXISTS public.feed_following(uuid, int, int);
REVOKE ALL ON FUNCTION public.feed_global(uuid, int, timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.feed_following(uuid, int, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.feed_global(uuid, int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.feed_following(uuid, int, timestamptz) TO authenticated;

-- Internal helper must only be reachable via authenticated, identity-checked
-- wrappers such as get_my_taste_profile and the group recommendation functions.
REVOKE EXECUTE ON FUNCTION public.compute_user_taste_profile(uuid) FROM PUBLIC, anon, authenticated;
COMMIT;

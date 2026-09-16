BEGIN;

-- A policy that queries its own protected table recurses (42P17). This helper
-- checks only the caller's membership, under a fixed search path, without RLS.
CREATE OR REPLACE FUNCTION public.is_tasting_session_member(p_session_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.tasting_session_members m
    WHERE m.session_id = p_session_id AND m.user_id = auth.uid()
  );
$$;
REVOKE ALL ON FUNCTION public.is_tasting_session_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_tasting_session_member(uuid) TO authenticated;

DROP POLICY IF EXISTS sessions_select_member ON public.tasting_sessions;
CREATE POLICY sessions_select_member ON public.tasting_sessions
  FOR SELECT TO authenticated USING (public.is_tasting_session_member(id));
DROP POLICY IF EXISTS session_members_select_same_session ON public.tasting_session_members;
CREATE POLICY session_members_select_same_session ON public.tasting_session_members
  FOR SELECT TO authenticated USING (public.is_tasting_session_member(session_id));
GRANT SELECT ON public.tasting_sessions, public.tasting_session_members TO authenticated;
GRANT DELETE ON public.tasting_session_members TO authenticated;

-- The database, rather than a client-side optimistic dismissal, confirms leave.
CREATE OR REPLACE FUNCTION public.leave_tasting_session(p_session_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not allowed' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.tasting_session_members
  WHERE session_id = p_session_id AND user_id = auth.uid();
END;
$$;
REVOKE ALL ON FUNCTION public.leave_tasting_session(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_tasting_session(uuid) TO authenticated;
COMMIT;

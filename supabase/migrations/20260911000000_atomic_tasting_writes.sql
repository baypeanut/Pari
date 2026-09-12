-- Deploy before the matching iOS client. Both writes are one transaction and
-- run with the caller's RLS permissions. The UUID identifies one save attempt.
BEGIN;

-- The migration chain previously had INSERT but no UPDATE/DELETE activity policy.
CREATE POLICY "activity_update_own" ON public.activity_feed FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "activity_delete_own" ON public.activity_feed FOR DELETE
  USING (auth.uid() = user_id);

CREATE FUNCTION public.create_tasting(
  p_id uuid, p_wine_id uuid, p_tasting jsonb,
  p_source text DEFAULT NULL, p_moment_image_url text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'An active account is required' USING ERRCODE = '42501';
  END IF;
  IF p_id IS NULL OR p_tasting->>'visibility' IS NULL THEN
    RAISE EXCEPTION 'Save ID and visibility are required' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.tastings (
    id, user_id, wine_id, rating, note_tags, comment, source, visibility, vintage,
    acidity, tannin, body, sweetness, aroma_intensity, finish, moment_image_url
  ) VALUES (
    p_id, auth.uid(), p_wine_id, (p_tasting->>'rating')::double precision,
    CASE WHEN jsonb_typeof(p_tasting->'note_tags') = 'array'
      THEN ARRAY(SELECT jsonb_array_elements_text(p_tasting->'note_tags')) END,
    NULLIF(btrim(p_tasting->>'comment'), ''), p_source, p_tasting->>'visibility',
    (p_tasting->>'vintage')::int, (p_tasting->>'acidity')::int,
    (p_tasting->>'tannin')::int, (p_tasting->>'body')::int,
    (p_tasting->>'sweetness')::int, (p_tasting->>'aroma_intensity')::int,
    (p_tasting->>'finish')::int, p_moment_image_url
  ) ON CONFLICT (id) DO NOTHING RETURNING id INTO v_id;

  IF v_id IS NOT NULL THEN
    INSERT INTO public.activity_feed (user_id, activity_type, wine_id, content_text, tasting_id)
    SELECT user_id, 'had_wine', wine_id, array_to_string(note_tags, ', '), id
    FROM public.tastings WHERE id = v_id;
  END IF;

  -- First committed write wins. A replay returns it without another feed row.
  -- Never expose another account's row even if the caller guesses its ID.
  SELECT to_jsonb(t) || jsonb_build_object('wines', to_jsonb(w)) INTO v_result
  FROM public.tastings t JOIN public.wines w ON w.id = t.wine_id
  WHERE t.id = p_id AND t.user_id = auth.uid() AND t.wine_id = p_wine_id;
  IF v_result IS NULL THEN
    RAISE EXCEPTION 'Save ID is unavailable' USING ERRCODE = '42501';
  END IF;
  RETURN v_result;
END;
$$;

CREATE FUNCTION public.update_tasting(p_id uuid, p_tasting jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  v_id uuid;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'An active account is required' USING ERRCODE = '42501';
  END IF;
  IF p_tasting->>'visibility' IS NULL THEN
    RAISE EXCEPTION 'Visibility is required' USING ERRCODE = '22023';
  END IF;

  -- Full replacement of editable fields: JSON null clears an old answer.
  UPDATE public.tastings SET
    rating = (p_tasting->>'rating')::double precision,
    note_tags = CASE WHEN jsonb_typeof(p_tasting->'note_tags') = 'array'
      THEN ARRAY(SELECT jsonb_array_elements_text(p_tasting->'note_tags')) END,
    comment = NULLIF(btrim(p_tasting->>'comment'), ''),
    visibility = p_tasting->>'visibility', vintage = (p_tasting->>'vintage')::int,
    acidity = (p_tasting->>'acidity')::int, tannin = (p_tasting->>'tannin')::int,
    body = (p_tasting->>'body')::int, sweetness = (p_tasting->>'sweetness')::int,
    aroma_intensity = (p_tasting->>'aroma_intensity')::int, finish = (p_tasting->>'finish')::int
  WHERE id = p_id AND user_id = auth.uid() RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Tasting is unavailable' USING ERRCODE = '42501';
  END IF;

  UPDATE public.activity_feed a SET content_text = array_to_string(t.note_tags, ', ')
  FROM public.tastings t
  WHERE a.tasting_id = t.id AND t.id = v_id AND a.user_id = auth.uid();

  SELECT to_jsonb(t) || jsonb_build_object('wines', to_jsonb(w)) INTO v_result
  FROM public.tastings t JOIN public.wines w ON w.id = t.wine_id WHERE t.id = v_id;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.create_tasting(uuid, uuid, jsonb, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_tasting(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_tasting(uuid, uuid, jsonb, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_tasting(uuid, jsonb) TO authenticated;
COMMIT;

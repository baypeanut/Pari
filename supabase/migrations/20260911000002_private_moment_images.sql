BEGIN;

-- Old clients' public photo URLs stop working after this migration. Deploy the
-- authenticated-download client with it; do not reopen the bucket as a fallback.
UPDATE storage.buckets SET public = false WHERE id = 'moment_images';
DROP POLICY IF EXISTS "Moment images are publicly readable" ON storage.objects;

-- Accept historical public URLs as references, never as authorization.
CREATE FUNCTION public.moment_object_path(p_reference text)
RETURNS text LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT CASE
    WHEN position('/storage/v1/object/public/moment_images/' IN p_reference) > 0
      THEN split_part(p_reference, '/storage/v1/object/public/moment_images/', 2)
    ELSE p_reference
  END;
$$;

CREATE INDEX tastings_moment_object_path_idx
  ON public.tastings (public.moment_object_path(moment_image_url));

CREATE POLICY "Moment images follow tasting visibility" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'moment_images' AND (
    lower(split_part(name, '/', 1)) = auth.uid()::text
    OR EXISTS (SELECT 1 FROM public.tastings t
      WHERE public.moment_object_path(t.moment_image_url) = storage.objects.name
        AND lower(split_part(storage.objects.name, '/', 1)) = t.user_id::text)
  ));

DROP POLICY IF EXISTS "Users can upload own moment images" ON storage.objects;
CREATE POLICY "Users can upload own moment images" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'moment_images' AND lower(split_part(name, '/', 1)) = auth.uid()::text);
CREATE POLICY "Users can delete own moment images" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'moment_images' AND lower(split_part(name, '/', 1)) = auth.uid()::text);
COMMIT;

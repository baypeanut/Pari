-- One row per wine/vintage, additive stock changes and replay-safe receipts.
-- Quantity changes and their receipts commit together. No production data is reset.
BEGIN;

CREATE TABLE public.cellar_stock_operations (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  request jsonb NOT NULL,
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, request_id)
);
ALTER TABLE public.cellar_stock_operations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stock_receipts_read_own" ON public.cellar_stock_operations
  FOR SELECT TO authenticated USING (user_id = auth.uid());
REVOKE ALL ON public.cellar_stock_operations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.cellar_stock_operations TO authenticated;

-- All client quantity writes now go through the authenticated RPCs below.
REVOKE INSERT, UPDATE, DELETE ON public.cellar_bottles FROM PUBLIC, anon, authenticated;
CREATE POLICY "cellar_active_owner" ON public.cellar_bottles AS RESTRICTIVE FOR SELECT
  USING (user_id = auth.uid() AND EXISTS (
    SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.deleted_at IS NULL
  ));

CREATE FUNCTION public.add_cellar_bottles(
  p_request_id uuid, p_wine_id uuid, p_quantity int,
  p_vintage int DEFAULT NULL, p_location text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_request jsonb;
  v_inserted uuid;
  v_previous public.cellar_stock_operations%ROWTYPE;
  v_result jsonb;
  v_bottle public.cellar_bottles%ROWTYPE;
BEGIN
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_user AND deleted_at IS NULL
  ) THEN RAISE EXCEPTION 'An active account is required' USING ERRCODE = '42501'; END IF;
  IF p_request_id IS NULL OR p_wine_id IS NULL OR p_quantity IS NULL
     OR p_quantity < 1 OR p_quantity > 10000
     OR (p_vintage IS NOT NULL AND p_vintage NOT BETWEEN 1800 AND 2100)
     OR length(p_location) > 200 THEN
    RAISE EXCEPTION 'Invalid bottle details' USING ERRCODE = '22023';
  END IF;
  v_request := jsonb_build_object('operation','add', 'wine_id',p_wine_id,
    'quantity',p_quantity, 'vintage',p_vintage, 'location',NULLIF(btrim(p_location),''));

  INSERT INTO public.cellar_stock_operations(user_id,request_id,request)
    VALUES(v_user,p_request_id,v_request) ON CONFLICT DO NOTHING
    RETURNING request_id INTO v_inserted;
  IF v_inserted IS NULL THEN
    SELECT * INTO v_previous FROM public.cellar_stock_operations
      WHERE user_id = v_user AND request_id = p_request_id;
    IF v_previous.request IS DISTINCT FROM v_request THEN
      RAISE EXCEPTION 'Request ID already used for different bottle details' USING ERRCODE = '22023';
    END IF;
    RETURN v_previous.result;
  END IF;

  -- Match the existing expression index exactly, including the NULL-vintage key.
  INSERT INTO public.cellar_bottles AS b(user_id,wine_id,vintage,quantity,location)
    VALUES(v_user,p_wine_id,p_vintage,p_quantity,NULLIF(btrim(p_location),''))
  ON CONFLICT (user_id,wine_id,(COALESCE(vintage,-1))) DO UPDATE
    SET quantity = b.quantity + EXCLUDED.quantity,
        location = COALESCE(EXCLUDED.location,b.location)
  RETURNING * INTO v_bottle;
  v_result := jsonb_build_object('bottle_id',v_bottle.id,'quantity',v_bottle.quantity);
  UPDATE public.cellar_stock_operations SET result = v_result
    WHERE user_id = v_user AND request_id = p_request_id;
  RETURN v_result;
END;
$$;

CREATE FUNCTION public.drink_cellar_bottle(p_request_id uuid, p_bottle_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_request jsonb;
  v_inserted uuid;
  v_previous public.cellar_stock_operations%ROWTYPE;
  v_result jsonb;
  v_quantity int;
BEGIN
  IF v_user IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_user AND deleted_at IS NULL
  ) THEN RAISE EXCEPTION 'An active account is required' USING ERRCODE = '42501'; END IF;
  IF p_request_id IS NULL OR p_bottle_id IS NULL THEN
    RAISE EXCEPTION 'Request ID and bottle ID are required' USING ERRCODE = '22023';
  END IF;
  v_request := jsonb_build_object('operation','drink','bottle_id',p_bottle_id);
  INSERT INTO public.cellar_stock_operations(user_id,request_id,request)
    VALUES(v_user,p_request_id,v_request) ON CONFLICT DO NOTHING
    RETURNING request_id INTO v_inserted;
  IF v_inserted IS NULL THEN
    SELECT * INTO v_previous FROM public.cellar_stock_operations
      WHERE user_id = v_user AND request_id = p_request_id;
    IF v_previous.request IS DISTINCT FROM v_request THEN
      RAISE EXCEPTION 'Request ID already used for another operation' USING ERRCODE = '22023';
    END IF;
    RETURN v_previous.result;
  END IF;

  -- The predicate is rechecked after waiting on a competing row update.
  UPDATE public.cellar_bottles SET quantity = quantity - 1
    WHERE id = p_bottle_id AND user_id = v_user AND quantity > 0
    RETURNING quantity INTO v_quantity;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bottle is unavailable or already empty' USING ERRCODE = 'P0002';
  END IF;
  v_result := jsonb_build_object('bottle_id',p_bottle_id,'quantity',v_quantity);
  UPDATE public.cellar_stock_operations SET result = v_result
    WHERE user_id = v_user AND request_id = p_request_id;
  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.add_cellar_bottles(uuid,uuid,int,int,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.drink_cellar_bottle(uuid,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_cellar_bottles(uuid,uuid,int,int,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.drink_cellar_bottle(uuid,uuid) TO authenticated;
COMMIT;

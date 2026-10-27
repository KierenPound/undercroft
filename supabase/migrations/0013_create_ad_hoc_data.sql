-- ---------------------------------------------------------------------------
-- Ad Hoc Data: free-form, user-defined records (title, email, URL, notes) for
-- anything not already covered by a dedicated section — for example, how to
-- operate the robot lawnmower. Mirrors the funeral_arrangements table pattern.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ad_hoc_data (
    ad_hoc_data_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id      uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    title          text NOT NULL DEFAULT '',
    email          text NOT NULL DEFAULT '',
    url            text NOT NULL DEFAULT '',
    notes          text NOT NULL DEFAULT '',
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ad_hoc_data_estate_id
    ON public.ad_hoc_data(estate_id);

GRANT ALL ON public.ad_hoc_data TO authenticated;
GRANT SELECT ON public.ad_hoc_data TO anon;

ALTER TABLE public.ad_hoc_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY ad_hoc_data_select_any_linked ON public.ad_hoc_data
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY ad_hoc_data_owner_insert ON public.ad_hoc_data
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY ad_hoc_data_owner_update ON public.ad_hoc_data
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY ad_hoc_data_owner_delete ON public.ad_hoc_data
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

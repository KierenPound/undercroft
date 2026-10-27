-- ---------------------------------------------------------------------------
-- Utility details: the Gas meter, Electric meter and Stopcock on the Running
-- the Houses page. Each one holds a photo (stored in the estate-documents
-- bucket under utilities/{kind}/) and the description of where it is and how
-- to read it. One row per kind per estate.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.utility_details (
    utility_detail_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id         uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    kind              text NOT NULL CHECK (kind IN ('gas_meter', 'electric_meter', 'stopcock')),
    notes             text NOT NULL DEFAULT '',
    storage_path      text NOT NULL DEFAULT '',
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (estate_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_utility_details_estate_id
    ON public.utility_details(estate_id);

GRANT ALL ON public.utility_details TO authenticated;
GRANT SELECT ON public.utility_details TO anon;

ALTER TABLE public.utility_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS utility_details_select_any_linked ON public.utility_details;
CREATE POLICY utility_details_select_any_linked ON public.utility_details
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

DROP POLICY IF EXISTS utility_details_owner_insert ON public.utility_details;
CREATE POLICY utility_details_owner_insert ON public.utility_details
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS utility_details_owner_update ON public.utility_details;
CREATE POLICY utility_details_owner_update ON public.utility_details
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS utility_details_owner_delete ON public.utility_details;
CREATE POLICY utility_details_owner_delete ON public.utility_details
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

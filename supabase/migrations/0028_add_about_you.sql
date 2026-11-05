-- 0028: Add "About You" — one identity record per estate owner
--
-- Holds the personal details an executor needs: full name, NI number, CHI
-- number, plus a single scanned image each of the passport and the driving
-- licence (extracted from the same estate-documents bucket as section
-- attachments, under an `about-you/` prefix).
--
-- Mirrors the funeral_arrangements pattern: rows belong to an estate, any
-- linked member may read them, only owners may write.

CREATE TABLE IF NOT EXISTS public.about_you (
    about_you_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id             uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    full_name             text NOT NULL DEFAULT '',
    ni_number             text NOT NULL DEFAULT '',
    chi_number            text NOT NULL DEFAULT '',
    passport_storage_path text NOT NULL DEFAULT '',
    passport_download_url text NOT NULL DEFAULT '',
    passport_file_size    bigint NOT NULL DEFAULT 0,
    licence_storage_path  text NOT NULL DEFAULT '',
    licence_download_url  text NOT NULL DEFAULT '',
    licence_file_size     bigint NOT NULL DEFAULT 0,
    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_about_you_estate_id
    ON public.about_you(estate_id);

GRANT ALL ON public.about_you TO authenticated;
GRANT SELECT ON public.about_you TO anon;

ALTER TABLE public.about_you ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS about_you_select_any_linked ON public.about_you;
CREATE POLICY about_you_select_any_linked ON public.about_you
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

DROP POLICY IF EXISTS about_you_owner_insert ON public.about_you;
CREATE POLICY about_you_owner_insert ON public.about_you
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS about_you_owner_update ON public.about_you;
CREATE POLICY about_you_owner_update ON public.about_you
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS about_you_owner_delete ON public.about_you;
CREATE POLICY about_you_owner_delete ON public.about_you
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- Funeral Arrangements: one or more per-owner funeral preference sections
-- (e.g. "Funeral (Kieren)", "Funeral (Bren)"). Each carries a name, free-text
-- notes, and an optional URL. Mirrors the who_to_notify table pattern.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.funeral_arrangements (
    funeral_arrangement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id              uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name                   text NOT NULL,
    notes                  text NOT NULL DEFAULT '',
    url                    text NOT NULL DEFAULT '',
    created_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_funeral_arrangements_estate_id
    ON public.funeral_arrangements(estate_id);

GRANT ALL ON public.funeral_arrangements TO authenticated;
GRANT SELECT ON public.funeral_arrangements TO anon;

ALTER TABLE public.funeral_arrangements ENABLE ROW LEVEL SECURITY;

CREATE POLICY funeral_arrangements_select_any_linked ON public.funeral_arrangements
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY funeral_arrangements_owner_insert ON public.funeral_arrangements
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY funeral_arrangements_owner_update ON public.funeral_arrangements
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY funeral_arrangements_owner_delete ON public.funeral_arrangements
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

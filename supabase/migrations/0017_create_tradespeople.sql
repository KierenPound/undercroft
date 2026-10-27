-- ---------------------------------------------------------------------------
-- Tradespeople: the trades the estate relies on (gas, electric, drains...)
-- listed on the Running the Houses page. Each entry carries a name, email,
-- telephone, web link and free-text notes. Mirrors the contacts table
-- pattern: read for anyone linked to the estate, write for owners only.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tradespeople (
    tradesperson_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id       uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name            text NOT NULL DEFAULT '',
    email           text NOT NULL DEFAULT '',
    telephone       text NOT NULL DEFAULT '',
    url             text NOT NULL DEFAULT '',
    notes           text NOT NULL DEFAULT '',
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tradespeople_estate_id
    ON public.tradespeople(estate_id);

GRANT ALL ON public.tradespeople TO authenticated;
GRANT SELECT ON public.tradespeople TO anon;

ALTER TABLE public.tradespeople ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tradespeople_select_any_linked ON public.tradespeople;
CREATE POLICY tradespeople_select_any_linked ON public.tradespeople
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

DROP POLICY IF EXISTS tradespeople_owner_insert ON public.tradespeople;
CREATE POLICY tradespeople_owner_insert ON public.tradespeople
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS tradespeople_owner_update ON public.tradespeople;
CREATE POLICY tradespeople_owner_update ON public.tradespeople
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

DROP POLICY IF EXISTS tradespeople_owner_delete ON public.tradespeople;
CREATE POLICY tradespeople_owner_delete ON public.tradespeople
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

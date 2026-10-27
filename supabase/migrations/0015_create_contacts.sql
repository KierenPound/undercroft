-- ---------------------------------------------------------------------------
-- Contacts: the individual people to notify (family, friends, GP, solicitor)
-- listed above the organisation entries on the Who to Notify page. Each
-- contact carries a name, telephone and email. Mirrors the ad_hoc_data table
-- pattern: read for anyone linked to the estate, write for owners only.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contacts (
    contact_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id  uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name       text NOT NULL DEFAULT '',
    telephone  text NOT NULL DEFAULT '',
    email      text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_contacts_estate_id
    ON public.contacts(estate_id);

GRANT ALL ON public.contacts TO authenticated;
GRANT SELECT ON public.contacts TO anon;

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY contacts_select_any_linked ON public.contacts
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY contacts_owner_insert ON public.contacts
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY contacts_owner_update ON public.contacts
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY contacts_owner_delete ON public.contacts
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

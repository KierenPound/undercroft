-- Keep handover unlocks separate from estate data so client sessions can read
-- entitlement state without being able to grant themselves paid access.
CREATE TABLE public.estate_handover_entitlements (
    estate_id uuid PRIMARY KEY
        REFERENCES public.estates(id) ON DELETE CASCADE,
    source text NOT NULL
        CHECK (source IN ('beta_free', 'app_store', 'google_play')),
    store_environment text
        CHECK (
            store_environment IS NULL
            OR store_environment IN ('Sandbox', 'Production', 'Test', 'Play')
        ),
    store_transaction_id text,
    granted_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX estate_handover_entitlements_transaction_unique
    ON public.estate_handover_entitlements (store_transaction_id)
    WHERE store_transaction_id IS NOT NULL;

ALTER TABLE public.estate_handover_entitlements ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.estate_handover_entitlements
    FROM anon, authenticated;
GRANT SELECT (estate_id) ON TABLE public.estate_handover_entitlements
    TO authenticated;
GRANT ALL ON TABLE public.estate_handover_entitlements TO service_role;

CREATE POLICY estate_handover_entitlements_read_linked
    ON public.estate_handover_entitlements
    FOR SELECT
    TO authenticated
    USING (
        estate_id IN (SELECT public.get_allowed_estate_ids())
    );

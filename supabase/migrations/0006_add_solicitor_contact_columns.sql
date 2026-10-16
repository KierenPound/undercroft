-- 0006: Add solicitor contact columns to sections
--
-- The Legal Documents "Wills" section shows contact details for the
-- solicitor holding the master Will (default: Thorntons). Users may use a
-- different firm, so the phone, email and website URL are overridable per
-- estate. An empty string means "use the built-in default".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS solicitor_phone text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS solicitor_email text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS solicitor_url   text NOT NULL DEFAULT '';

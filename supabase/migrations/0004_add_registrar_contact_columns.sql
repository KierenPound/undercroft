-- 0004: Add registrar contact columns to sections
--
-- The "What to Do First" Death certificate section shows a phone number and
-- email for the local registrar (default: Perth Registrars). Users outside
-- Perth need to override these with their own registrar's details. These two
-- columns store the per-estate override on the section row; an empty string
-- means "use the built-in Perth default".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS registrar_phone text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS registrar_email text NOT NULL DEFAULT '';

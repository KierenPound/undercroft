-- 0005: Add certified copies ordering URL column to sections
--
-- The "What the Registrar will Give You" section shows a link to order extra
-- certified copies of the death certificate (default: Perth & Kinross Council
-- portal). Users outside Perth need to override this with their own local
-- council's ordering page. An empty string means "use the built-in default".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS certified_copies_url text NOT NULL DEFAULT '';

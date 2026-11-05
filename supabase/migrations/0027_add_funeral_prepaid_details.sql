-- 0027: Add free-text "Prepaid details" to funeral arrangements
--
-- Records any prepaid funeral plan (plan provider, policy number, who to
-- contact), kept separate from the general wishes notes. An empty string
-- means "not set".

ALTER TABLE public.funeral_arrangements
    ADD COLUMN IF NOT EXISTS prepaid_details text NOT NULL DEFAULT '';

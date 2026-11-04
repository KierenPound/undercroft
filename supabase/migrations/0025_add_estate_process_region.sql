-- 0025: Add estate-level process region
--
-- The legal process differs slightly between Scotland and the rest of the UK.
-- This stores the estate's chosen process path so every signed-in member sees
-- the same guidance after logging back in on any device.

ALTER TABLE public.estates
    ADD COLUMN IF NOT EXISTS process_region text NOT NULL DEFAULT 'scotland';

DO $$
BEGIN
    ALTER TABLE public.estates
        ADD CONSTRAINT estates_process_region_check
        CHECK (process_region IN ('scotland', 'ewni'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

UPDATE public.estates
SET process_region = 'scotland'
WHERE process_region IS NULL
   OR process_region NOT IN ('scotland', 'ewni');

-- Keep estate identity fields fixed while allowing editable estate metadata,
-- including the process-region choice added above.
CREATE OR REPLACE FUNCTION public.estates_guard_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.id       IS DISTINCT FROM OLD.id
    OR NEW.owner_id IS DISTINCT FROM OLD.owner_id
    THEN
        RAISE EXCEPTION
            'An estate update may not change id or owner_id'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

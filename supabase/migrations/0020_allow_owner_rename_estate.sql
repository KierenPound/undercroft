-- ---------------------------------------------------------------------------
-- Let an estate owner rename the estate.
--
-- `estates_owner_update` paired two checks that did not agree:
--
--     USING      -> id IN (SELECT public.get_allowed_estate_ids('owner'))
--     WITH CHECK -> auth.uid() = owner_id
--
-- USING admits any accepted member holding the `owner` role, which includes a
-- co-owner invited with `role = 'owner'`. WITH CHECK then demanded the result
-- still belong to auth.uid(), which a co-owner's estate never does, because
-- owner_id still points at whoever created it. A co-owner therefore passed
-- USING, failed WITH CHECK, and had the rename rejected with "new row violates
-- row-level security policy for table \"estates\"".
--
-- Both halves now apply the same owner-role test, so any owner can rename.
--
-- Relaxing WITH CHECK to that test would also let an owner rewrite owner_id,
-- because RLS sees only the NEW row and cannot express "this column must not
-- change". The BEFORE UPDATE guard below keeps id and owner_id fixed, so the
-- policy grants exactly one editable column: name.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS estates_owner_update ON public.estates;

CREATE POLICY estates_owner_update ON public.estates
    FOR UPDATE
    TO authenticated
    USING ( id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- Guard: an estate update may only change the name. Deliberately NOT SECURITY
-- DEFINER — the function reads only OLD/NEW and touches no tables.
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
            'An estate update may only change its name'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS estates_guard_update ON public.estates;
CREATE TRIGGER estates_guard_update
    BEFORE UPDATE ON public.estates
    FOR EACH ROW
    EXECUTE FUNCTION public.estates_guard_update();

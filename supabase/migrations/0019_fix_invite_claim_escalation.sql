-- ---------------------------------------------------------------------------
-- Fix a privilege-escalation hole in the invite claim flow.
--
-- `estate_access_claim_pending_invite` was a single UPDATE policy covering both
-- executor and owner invites, with `role IN ('executor', 'owner')` in its WITH
-- CHECK. A WITH CHECK is evaluated against the NEW row and cannot see the old
-- one, so nothing tied the resulting role to the role the invite was created
-- with. A holder of an *executor* invite code could therefore send
-- `role: 'owner'` along with the claim the app makes and be granted co-owner
-- rights on the estate.
--
-- The same policy ended with three self-comparisons:
--
--     estate_id = estate_id
--     invite_code = invite_code
--     invited_email = invited_email
--
-- In a policy expression an unqualified column refers to the NEW row, so each
-- of these compares a value with itself and guards nothing. They read as
-- immutability checks but are tautologies, so a claim could also retarget the
-- row at a different estate or rewrite its invite code.
--
-- Two changes close both gaps:
--   1. One claim policy per role, each accepting only its own role in the WITH
--      CHECK, so a claim can never yield more than the invite already carried.
--   2. A BEFORE UPDATE guard trigger, because RLS has no access to the old row
--      and so cannot express "these columns must not change".
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS estate_access_claim_pending_invite ON public.estate_access;

-- An executor invite can only ever be claimed as an executor.
CREATE POLICY estate_access_claim_executor_invite ON public.estate_access
    FOR UPDATE
    TO authenticated
    USING (
        status = 'pending'
        AND user_id IS NULL
        AND invite_code IS NOT NULL
        AND role = 'executor'
    )
    WITH CHECK (
        status = 'accepted'
        AND user_id = auth.uid()
        AND role = 'executor'
    );

-- An owner invite can only ever be claimed as a co-owner.
CREATE POLICY estate_access_claim_owner_invite ON public.estate_access
    FOR UPDATE
    TO authenticated
    USING (
        status = 'pending'
        AND user_id IS NULL
        AND invite_code IS NOT NULL
        AND role = 'owner'
    )
    WITH CHECK (
        status = 'accepted'
        AND user_id = auth.uid()
        AND role = 'owner'
    );

-- Guard: claiming an invite may only set user_id and status. Deliberately NOT
-- SECURITY DEFINER — the function reads only OLD/NEW and touches no tables.
CREATE OR REPLACE FUNCTION public.estate_access_guard_claim()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Only a claim: an unclaimed pending invite being linked to a user.
    IF OLD.status = 'pending'
       AND OLD.user_id IS NULL
       AND NEW.user_id IS NOT NULL
    THEN
        IF NEW.role          IS DISTINCT FROM OLD.role
        OR NEW.estate_id     IS DISTINCT FROM OLD.estate_id
        OR NEW.invite_code   IS DISTINCT FROM OLD.invite_code
        OR NEW.invited_email IS DISTINCT FROM OLD.invited_email
        OR NEW.status        IS DISTINCT FROM 'accepted'
        THEN
            RAISE EXCEPTION
                'An invite claim may only set user_id and status'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS estate_access_guard_claim ON public.estate_access;
CREATE TRIGGER estate_access_guard_claim
    BEFORE UPDATE ON public.estate_access
    FOR EACH ROW
    EXECUTE FUNCTION public.estate_access_guard_claim();

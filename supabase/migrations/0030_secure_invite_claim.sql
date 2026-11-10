-- ---------------------------------------------------------------------------
-- 0030: Stop leaking pending invites, and verify invite codes server-side.
--
-- Problem 1 (confirmed live): estate_access_select_linked ended with
--
--     OR (status = 'pending' AND user_id IS NULL AND invite_code IS NOT NULL)
--
-- That clause tests the row, not the requester, and the policy was granted to
-- `anon`. Every outstanding invite was therefore world-readable through the
-- REST API -- invite_code, invited_email and estate_id included -- with no
-- session at all. Anyone holding a code could then claim it.
--
-- Problem 2: estate_access_owner_insert accepted `user_id = auth.uid()` on its
-- own, so any signed-in user could INSERT an accepted owner row against any
-- estate id and hand themselves co-owner access with no invite involved.
--
-- Problem 3: the claim UPDATE policies checked that a row *was* pending but
-- never that the submitted code matched it. RLS cannot read client input, so
-- the only real check was the app's `.eq('invite_code', code)` filter before a
-- separate UPDATE by row id -- which a caller could simply skip.
--
-- The fixes:
--   1. A pending invite is readable only by the estate's owners (who issued it)
--      and by the invitee whose email it carries. Anonymous reads are revoked.
--   2. INSERT now means exactly "create an invite": estate owner, pending,
--      unlinked, with a code. It can no longer create a membership.
--   3. Claiming is no longer a table UPDATE. claim_invite() looks the row up
--      *by code*, so the database verifies the code rather than trusting a
--      client-side filter, and the granted role always comes from the row.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Reads: a pending invite is nobody else's business.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS estate_access_select_linked ON public.estate_access;
CREATE POLICY estate_access_select_linked ON public.estate_access
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_estate_owner(estate_id)
        OR public.is_estate_member_owner(estate_id)
        OR (
            status = 'pending'
            AND user_id IS NULL
            AND invite_code IS NOT NULL
            AND invited_email IS NOT NULL
            AND lower(invited_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
        )
    );

-- The app only ever touches this table with a session. Anonymous read access
-- existed solely to serve the leak above.
REVOKE SELECT ON public.estate_access FROM anon;

-- ---------------------------------------------------------------------------
-- 2. Writes: INSERT creates an invite, never a membership.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS estate_access_owner_insert ON public.estate_access;
CREATE POLICY estate_access_owner_insert ON public.estate_access
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_estate_owner(estate_id)
        AND status = 'pending'
        AND user_id IS NULL
        AND invite_code IS NOT NULL
    );

-- ---------------------------------------------------------------------------
-- 3. Claiming: one code-checked entry point replaces the UPDATE policies.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS estate_access_claim_executor_invite ON public.estate_access;
DROP POLICY IF EXISTS estate_access_claim_owner_invite ON public.estate_access;
DROP POLICY IF EXISTS estate_access_claim_pending_invite ON public.estate_access;

CREATE OR REPLACE FUNCTION public.claim_invite(p_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
    caller_id     uuid := auth.uid();
    target_id     uuid;
    target_estate uuid;
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'claim_invite: no authenticated user';
    END IF;

    IF p_code IS NULL OR length(trim(p_code)) = 0 THEN
        RAISE EXCEPTION 'Invalid invite code'
            USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- One membership per account, matching the rule the app already applied.
    IF EXISTS (
        SELECT 1
        FROM   public.estate_access
        WHERE  user_id = caller_id
        AND    status = 'accepted'
    ) THEN
        RAISE EXCEPTION 'You already have access to an estate'
            USING ERRCODE = 'unique_violation';
    END IF;

    -- FOR UPDATE so two simultaneous claims of one code cannot both succeed:
    -- the loser re-reads after the winner commits and finds nothing to claim.
    SELECT id, estate_id
    INTO   target_id, target_estate
    FROM   public.estate_access
    WHERE  invite_code = upper(trim(p_code))
    AND    status = 'pending'
    AND    user_id IS NULL
    FOR UPDATE;

    IF target_id IS NULL THEN
        RAISE EXCEPTION 'Invalid invite code' USING ERRCODE = 'no_data_found';
    END IF;

    -- The role is never taken from the caller: the row already carries the role
    -- the invite was created with, and estate_access_guard_claim keeps it fixed.
    UPDATE public.estate_access
    SET    user_id = caller_id,
           status  = 'accepted'
    WHERE  id = target_id;

    RETURN target_estate;
END;
$$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC by default, so revoke first.
REVOKE ALL ON FUNCTION public.claim_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_invite(text) TO authenticated, service_role;

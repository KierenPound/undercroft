-- ============================================================================
-- UnderCroft: Fix infinite recursion in estate_access RLS policy
--
-- Root cause:
--   Policies on public.estate_access were calling the SECURITY DEFINER helper
--   public.get_allowed_estate_ids(...). That helper queries public.estate_access
--   internally, which re-fired the estate_access SELECT policy — which again
--   invoked the helper — causing infinite recursion.
--
-- Fix (two layers):
--   1. Mark the SECURITY DEFINER helpers with "SET row_security = off"
--      so queries inside them bypass RLS entirely.
--   2. Rewrite the policies that live ON public.estate_access so they NEVER
--      invoke get_allowed_estate_ids(). Owner-lookups go directly against
--      public.estates.owner_id = auth.uid().
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Re-create helpers with row_security = off (idempotent: CREATE OR REPLACE)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_allowed_estate_ids(requested_role text)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
    SELECT estate_id
    FROM   public.estate_access
    WHERE  user_id = auth.uid()
    AND    status = 'accepted'
    AND    (requested_role IS NULL OR role = requested_role);
$$;

CREATE OR REPLACE FUNCTION public.get_allowed_estate_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
    SELECT public.get_allowed_estate_ids(NULL::text);
$$;

CREATE OR REPLACE FUNCTION public.get_estate_role_for_current_user(requested_estate_id uuid DEFAULT NULL)
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
    SELECT role
    FROM   public.estate_access
    WHERE  user_id = auth.uid()
    AND    status = 'accepted'
    AND    (requested_estate_id IS NULL OR estate_id = requested_estate_id)
    ORDER  BY CASE role WHEN 'owner' THEN 1 WHEN 'executor' THEN 2 ELSE 3 END
    LIMIT  1;
$$;

-- ---------------------------------------------------------------------------
-- 2. Re-create estate_access policies without calling the helpers on self.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS estate_access_select_linked ON public.estate_access;
CREATE POLICY estate_access_select_linked ON public.estate_access
    FOR SELECT
    TO anon, authenticated
    USING (
        user_id = auth.uid()
        OR estate_id IN (SELECT id FROM public.estates WHERE owner_id = auth.uid())
        OR (status = 'pending' AND user_id IS NULL AND invite_code IS NOT NULL)
    );

DROP POLICY IF EXISTS estate_access_owner_insert ON public.estate_access;
CREATE POLICY estate_access_owner_insert ON public.estate_access
    FOR INSERT
    TO authenticated
    WITH CHECK (
        estate_id IN (SELECT id FROM public.estates WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS estate_access_owner_update ON public.estate_access;
CREATE POLICY estate_access_owner_update ON public.estate_access
    FOR UPDATE
    TO authenticated
    USING (
        estate_id IN (SELECT id FROM public.estates WHERE owner_id = auth.uid())
    )
    WITH CHECK (
        estate_id IN (SELECT id FROM public.estates WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS estate_access_owner_delete ON public.estate_access;
CREATE POLICY estate_access_owner_delete ON public.estate_access
    FOR DELETE
    TO authenticated
    USING (
        estate_id IN (SELECT id FROM public.estates WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS estate_access_claim_pending_invite ON public.estate_access;
CREATE POLICY estate_access_claim_pending_invite ON public.estate_access
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
        AND estate_id = estate_id
        AND invite_code = invite_code
        AND invited_email = invited_email
    );

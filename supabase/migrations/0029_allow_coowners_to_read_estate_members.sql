-- Co-owners need the estate-wide membership list to see accurate readiness.
--
-- The previous SELECT policy exposed all estate_access rows only to the
-- original estate owner. Co-owners could see their own row, so readiness
-- treated the other accepted members as absent.

CREATE OR REPLACE FUNCTION public.is_estate_member_owner(check_estate_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.estate_access ea
        WHERE ea.estate_id = check_estate_id
        AND ea.user_id = auth.uid()
        AND ea.role = 'owner'
        AND ea.status = 'accepted'
    );
$$;

REVOKE ALL ON FUNCTION public.is_estate_member_owner(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_estate_member_owner(uuid)
    TO anon, authenticated, service_role;

DROP POLICY IF EXISTS estate_access_select_linked ON public.estate_access;
CREATE POLICY estate_access_select_linked ON public.estate_access
    FOR SELECT
    TO anon, authenticated
    USING (
        user_id = auth.uid()
        OR public.is_estate_owner(estate_id)
        OR public.is_estate_member_owner(estate_id)
        OR (status = 'pending' AND user_id IS NULL AND invite_code IS NOT NULL)
    );

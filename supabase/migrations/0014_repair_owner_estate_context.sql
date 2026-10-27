-- UnderCroft: recover legacy owner estates that are missing an accepted
-- estate_access row.
--
-- Some early estates can exist in public.estates with owner_id populated
-- while the corresponding owner row in public.estate_access is missing.
-- The app historically looked only at estate_access, which sends genuine
-- owners to onboarding even though their estate still exists.

CREATE OR REPLACE FUNCTION public.get_or_create_current_estate_context()
RETURNS TABLE (estate_id uuid, role text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
    owned_estate_id uuid;
BEGIN
    RETURN QUERY
    SELECT ea.estate_id, ea.role
    FROM   public.estate_access ea
    WHERE  ea.user_id = auth.uid()
    AND    ea.status = 'accepted'
    ORDER  BY CASE ea.role WHEN 'owner' THEN 1 WHEN 'executor' THEN 2 ELSE 3 END
    LIMIT  1;

    IF FOUND THEN
        RETURN;
    END IF;

    SELECT e.id
    INTO   owned_estate_id
    FROM   public.estates e
    WHERE  e.owner_id = auth.uid()
    ORDER  BY e.created_at NULLS LAST, e.id
    LIMIT  1;

    IF owned_estate_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.estate_access
    SET    role = 'owner',
           status = 'accepted'
    WHERE  estate_id = owned_estate_id
    AND    user_id = auth.uid();

    IF NOT FOUND THEN
        INSERT INTO public.estate_access (estate_id, user_id, role, status)
        VALUES (owned_estate_id, auth.uid(), 'owner', 'accepted');
    END IF;

    RETURN QUERY
    SELECT owned_estate_id, 'owner'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_current_estate_context()
    TO anon, authenticated, service_role;

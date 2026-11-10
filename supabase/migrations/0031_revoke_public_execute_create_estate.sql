-- ---------------------------------------------------------------------------
-- 0031: Revoke PUBLIC EXECUTE on create_estate().
--
-- CREATE FUNCTION grants EXECUTE to PUBLIC by default. create_estate() was
-- granted to authenticated and service_role but never revoked from PUBLIC, so
-- an anonymous caller could reach it.
--
-- Impact today is nil: create_estate() is SECURITY DEFINER and keys everything
-- off auth.uid(), which is NULL for anon, so the INSERT violates the NOT NULL
-- owner_id constraint and no estate is ever created. It is still a
-- defence-in-depth gap, and an inconsistency with the other SECURITY DEFINER
-- RPCs in this schema (delete_my_account, claim_invite), which all revoke
-- PUBLIC before granting the narrower set.
-- ---------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.create_estate(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_estate(text) TO authenticated, service_role;

-- 0023: Self-service account deletion
--
-- Both app stores require a signed-in user to be able to delete their own
-- account and the data held against it, from inside the app.
--
-- Deleting the auth.users row is the entire database job, because every public
-- table already reaches it through an ON DELETE CASCADE chain:
--   auth.users -> estates.owner_id       (the estate itself is removed)
--   estates    -> every content table    (sections, documents, contacts, ...)
--   auth.users -> estate_access.user_id  (a membership elsewhere is removed)
--
-- So an estate owner's deletion takes the whole estate with it, while an
-- executor's deletion removes only their own access.
--
-- Storage is deliberately out of scope here. The bytes live behind the Storage
-- API, and deleting rows from storage.objects would orphan every file: still
-- billed for, yet unreachable, because the API works from exactly those rows.
-- The app empties the estate's folder through the Storage API first, while the
-- owner's session still authorises it.
--
-- SECURITY DEFINER is required because the authenticated role has no privilege
-- on auth.users, which is owned by supabase_auth_admin.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id uuid := auth.uid();
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'delete_my_account: no authenticated user';
    END IF;

    DELETE FROM auth.users WHERE id = caller_id;
END;
$$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC by default, so it must be revoked
-- before granting the narrower set.
REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated, service_role;

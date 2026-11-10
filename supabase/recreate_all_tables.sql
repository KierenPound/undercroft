-- ============================================================================
-- UnderCroft: Master Consolidated Migration Script (Fully Idempotent)
-- Target: https://mpsygpgaakdtlgjzmbtr.supabase.co
--
-- Run this from Supabase Dashboard → SQL Editor. Safe to re-run.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. EXTENSIONS & SCHEMA GRANTS
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT USAGE ON SCHEMA storage TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. TABLES & COLUMN GUARANTEES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.estates (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name        text NOT NULL DEFAULT 'My Estate',
    process_region text NOT NULL DEFAULT 'scotland'
        CHECK (process_region IN ('scotland', 'ewni')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.estate_access (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id     uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    user_id       uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    role          text NOT NULL CHECK (role IN ('owner', 'executor')),
    created_at    timestamptz NOT NULL DEFAULT now()
);

DO $$
BEGIN
    ALTER TABLE public.estate_access ALTER COLUMN user_id DROP NOT NULL;
EXCEPTION WHEN others THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.estate_access ADD COLUMN status text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.estate_access ADD COLUMN invited_email text;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.estate_access ADD COLUMN invite_code char(6);
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

UPDATE public.estate_access
   SET status = 'accepted'
 WHERE status IS NULL
   AND user_id IS NOT NULL;

ALTER TABLE public.estate_access
    DROP CONSTRAINT IF EXISTS estate_access_status_check;

ALTER TABLE public.estate_access
    ADD CONSTRAINT estate_access_status_check
    CHECK (status IN ('pending', 'accepted', 'revoked'));

ALTER TABLE public.estate_access
    DROP CONSTRAINT IF EXISTS estate_access_invite_code_unique;

ALTER TABLE public.estate_access
    ADD CONSTRAINT estate_access_invite_code_unique UNIQUE (invite_code);

CREATE TABLE IF NOT EXISTS public.documents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id     uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    title         text NOT NULL,
    storage_path  text NOT NULL,
    category      text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Who to Notify: companies/entities to contact when the estate owner passes.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.who_to_notify (
    who_to_notify_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id           uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    company_name        text NOT NULL,
    contact_number      text,
    weblink             text,
    supplementary_notes text,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Notify Account Details: financial/account reference numbers linked to a
-- single who_to_notify entry.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notify_account_details (
    notify_account_details_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    who_to_notify_id          uuid NOT NULL REFERENCES public.who_to_notify(who_to_notify_id) ON DELETE CASCADE,
    sort_code                 text,
    account_code              text,
    other_code                text,
    other_description         text,
    created_at                timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Funeral Arrangements: one or more per-owner funeral preference sections
-- (e.g. "Funeral (Kieren)", "Funeral (Bren)"). Each carries a name, free-text
-- notes, and an optional URL. Mirrors the who_to_notify table pattern.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.funeral_arrangements (
    funeral_arrangement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id              uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name                   text NOT NULL,
    notes                  text NOT NULL DEFAULT '',
    prepaid_details        text NOT NULL DEFAULT '',
    url                    text NOT NULL DEFAULT '',
    created_at             timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- About You: one identity record per estate owner (full name, NI and CHI
-- numbers, plus a scanned passport and driving licence). Mirrors the
-- funeral_arrangements table pattern.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.about_you (
    about_you_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id             uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    full_name             text NOT NULL DEFAULT '',
    ni_number             text NOT NULL DEFAULT '',
    chi_number            text NOT NULL DEFAULT '',
    passport_storage_path text NOT NULL DEFAULT '',
    passport_download_url text NOT NULL DEFAULT '',
    passport_file_size    bigint NOT NULL DEFAULT 0,
    licence_storage_path  text NOT NULL DEFAULT '',
    licence_download_url  text NOT NULL DEFAULT '',
    licence_file_size     bigint NOT NULL DEFAULT 0,
    created_at            timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Ad Hoc Data: free-form, user-defined records (title, email, URL, notes) for
-- anything not already covered by a dedicated section. Mirrors the
-- funeral_arrangements table pattern.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ad_hoc_data (
    ad_hoc_data_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id      uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    title          text NOT NULL DEFAULT '',
    email          text NOT NULL DEFAULT '',
    url            text NOT NULL DEFAULT '',
    notes          text NOT NULL DEFAULT '',
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Contacts: the individual people to notify (family, friends, GP, solicitor)
-- listed above the organisation entries on the Who to Notify page. Each
-- contact carries a name, telephone and email. Mirrors the ad_hoc_data pattern:
-- read for anyone linked to the estate, write for owners only.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.contacts (
    contact_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id  uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name       text NOT NULL DEFAULT '',
    telephone  text NOT NULL DEFAULT '',
    email      text NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Tradespeople: the trades the estate relies on (gas, electric, drains and so
-- on) shown on the Running the Houses page. Mirrors the contacts pattern: read
-- for anyone linked to the estate, write for owners only.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tradespeople (
    tradesperson_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id       uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    name            text NOT NULL DEFAULT '',
    email           text NOT NULL DEFAULT '',
    telephone       text NOT NULL DEFAULT '',
    url             text NOT NULL DEFAULT '',
    notes           text NOT NULL DEFAULT '',
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Utility details: one row per utility per estate (Gas meter, Electric meter,
-- Stopcock), holding a photo of the meter/stopcock in the private
-- `estate-documents` bucket plus the description that explains where it is and
-- how to read it.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.utility_details (
    utility_detail_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id         uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    kind              text NOT NULL CHECK (kind IN ('gas_meter', 'electric_meter', 'stopcock')),
    notes             text NOT NULL DEFAULT '',
    storage_path      text NOT NULL DEFAULT '',
    file_size         bigint NOT NULL DEFAULT 0,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (estate_id, kind)
);

DO $$
BEGIN
    ALTER TABLE public.utility_details ADD COLUMN file_size bigint NOT NULL DEFAULT 0;
EXCEPTION WHEN duplicate_column THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Sections: prep sections (e.g. Who to Notify, Legal Documents) belonging to
-- an estate. Each section carries its own notes, youtube URL, and is the
-- parent for checklist items and attachments.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sections (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id     uuid NOT NULL REFERENCES public.estates(id) ON DELETE CASCADE,
    title         text NOT NULL,
    order_index   int NOT NULL DEFAULT 0,
    is_standard   boolean NOT NULL DEFAULT false,
    notes         text NOT NULL DEFAULT '',
    letter_text   text NOT NULL DEFAULT '',
    songs_csv     text NOT NULL DEFAULT '',
    youtube_url   text NOT NULL DEFAULT '',
    registrar_phone text NOT NULL DEFAULT '',
    registrar_email text NOT NULL DEFAULT '',
    certified_copies_url text NOT NULL DEFAULT '',
    solicitor_intro text NOT NULL DEFAULT '',
    solicitor_phone text NOT NULL DEFAULT '',
    solicitor_email text NOT NULL DEFAULT '',
    solicitor_url   text NOT NULL DEFAULT '',
    phone_pin_1          text NOT NULL DEFAULT '',
    computer_password_1  text NOT NULL DEFAULT '',
    phone_pin_2          text NOT NULL DEFAULT '',
    computer_password_2  text NOT NULL DEFAULT '',
    wifi_password        text NOT NULL DEFAULT '',
    pet_notes            text NOT NULL DEFAULT '',
    vet_name             text NOT NULL DEFAULT '',
    vet_phone            text NOT NULL DEFAULT '',
    vet_url              text NOT NULL DEFAULT '',
    pet_insurance_company text NOT NULL DEFAULT '',
    pet_policy_number    text NOT NULL DEFAULT '',
    pet_microchip_number text NOT NULL DEFAULT '',
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.sections
    DROP CONSTRAINT IF EXISTS sections_estate_title_unique;
ALTER TABLE public.sections
    ADD CONSTRAINT sections_estate_title_unique UNIQUE (estate_id, title);

-- ---------------------------------------------------------------------------
-- Checklist Items: to-do items belonging to a section.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.checklist_items (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id     uuid NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
    text           text NOT NULL,
    is_completed   boolean NOT NULL DEFAULT false,
    order_index    int NOT NULL DEFAULT 0,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Attachments: photos and PDFs attached to a section, stored in Supabase
-- Storage under the estate-documents bucket.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attachments (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id     uuid NOT NULL REFERENCES public.sections(id) ON DELETE CASCADE,
    file_name      text NOT NULL,
    type           text NOT NULL DEFAULT 'unknown',
    storage_path   text NOT NULL DEFAULT '',
    download_url   text NOT NULL DEFAULT '',
    file_size      bigint NOT NULL DEFAULT 0,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 2b. WIPE ALL APPLICATION DATA
--
-- TRUNCATE every public schema table so a re-run of this script starts from
-- a clean slate. CASCADE handles foreign-key ordering automatically.
--
-- IMPORTANT: auth.users is NOT touched here — Supabase manages user accounts
-- separately and we must not delete them. If you also want to delete user
-- accounts, do that from the Supabase Dashboard → Authentication → Users.
--
-- IMPORTANT: storage.objects is NOT touched here, and must not be. It is the
-- index to the bucket, not the bucket itself: the bytes live behind the
-- Storage API. Truncating it would delete no files at all, so every object
-- would stay on disk and keep being billed, while becoming permanently
-- unreachable — nothing could list it, sign a URL for it, or delete it, since
-- the API works from exactly those rows. This script only cleans the public
-- tables; for a genuine clean slate, empty the bucket through the Dashboard
-- (Storage → estate-documents → select all → delete), which removes metadata
-- and files together.
-- ---------------------------------------------------------------------------
TRUNCATE TABLE
    public.estate_access,
    public.attachments,
    public.checklist_items,
    public.sections,
    public.funeral_arrangements,
    public.about_you,
    public.ad_hoc_data,
    public.contacts,
    public.tradespeople,
    public.utility_details,
    public.notify_account_details,
    public.who_to_notify,
    public.documents,
    public.estates
    CASCADE;

-- ---------------------------------------------------------------------------
-- 3. INDEXES
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_documents_estate_id ON public.documents(estate_id);
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category);

CREATE INDEX IF NOT EXISTS idx_who_to_notify_estate_id ON public.who_to_notify(estate_id);
CREATE INDEX IF NOT EXISTS idx_notify_account_details_who_to_notify_id ON public.notify_account_details(who_to_notify_id);
CREATE INDEX IF NOT EXISTS idx_funeral_arrangements_estate_id ON public.funeral_arrangements(estate_id);
CREATE INDEX IF NOT EXISTS idx_about_you_estate_id ON public.about_you(estate_id);
CREATE INDEX IF NOT EXISTS idx_ad_hoc_data_estate_id ON public.ad_hoc_data(estate_id);
CREATE INDEX IF NOT EXISTS idx_contacts_estate_id ON public.contacts(estate_id);
CREATE INDEX IF NOT EXISTS idx_tradespeople_estate_id ON public.tradespeople(estate_id);
CREATE INDEX IF NOT EXISTS idx_utility_details_estate_id ON public.utility_details(estate_id);

CREATE INDEX IF NOT EXISTS idx_sections_estate_id ON public.sections(estate_id);
CREATE INDEX IF NOT EXISTS idx_checklist_items_section_id ON public.checklist_items(section_id);
CREATE INDEX IF NOT EXISTS idx_attachments_section_id ON public.attachments(section_id);

DROP INDEX IF EXISTS public.estate_access_unique_user_per_estate;
DROP INDEX IF EXISTS public.estate_access_unique_user_per_estate_partial;
CREATE UNIQUE INDEX IF NOT EXISTS estate_access_unique_user_per_estate_partial
    ON public.estate_access (estate_id, user_id)
    WHERE user_id IS NOT NULL;

DROP INDEX IF EXISTS public.estate_access_unique_pending_email_per_estate;
CREATE UNIQUE INDEX IF NOT EXISTS estate_access_unique_pending_email_per_estate
    ON public.estate_access (estate_id, invited_email)
    WHERE status = 'pending' AND invited_email IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. TABLE & SEQUENCE GRANTS
-- ---------------------------------------------------------------------------
GRANT ALL ON public.estates TO authenticated;
GRANT ALL ON public.estate_access TO authenticated;
GRANT ALL ON public.documents TO authenticated;
GRANT ALL ON public.who_to_notify TO authenticated;
GRANT ALL ON public.notify_account_details TO authenticated;
GRANT ALL ON public.funeral_arrangements TO authenticated;
GRANT ALL ON public.about_you TO authenticated;
GRANT ALL ON public.ad_hoc_data TO authenticated;
GRANT ALL ON public.contacts TO authenticated;
GRANT ALL ON public.tradespeople TO authenticated;
GRANT ALL ON public.utility_details TO authenticated;
GRANT ALL ON public.sections TO authenticated;
GRANT ALL ON public.checklist_items TO authenticated;
GRANT ALL ON public.attachments TO authenticated;

GRANT SELECT ON public.estates TO anon;
-- estate_access is deliberately not granted to anon: the only rows an
-- anonymous caller could reach were pending invites, which exposed invite_code
-- and invited_email to anyone on the internet. See migration 0030.
REVOKE SELECT ON public.estate_access FROM anon;
GRANT SELECT ON public.documents TO anon;
GRANT SELECT ON public.who_to_notify TO anon;
GRANT SELECT ON public.notify_account_details TO anon;
GRANT SELECT ON public.funeral_arrangements TO anon;
GRANT SELECT ON public.about_you TO anon;
GRANT SELECT ON public.ad_hoc_data TO anon;
GRANT SELECT ON public.contacts TO anon;
GRANT SELECT ON public.tradespeople TO anon;
GRANT SELECT ON public.utility_details TO anon;
GRANT SELECT ON public.sections TO anon;
GRANT SELECT ON public.checklist_items TO anon;
GRANT SELECT ON public.attachments TO anon;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) ENABLEMENT
-- ---------------------------------------------------------------------------
ALTER TABLE public.estates         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estate_access   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.who_to_notify   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notify_account_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.funeral_arrangements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.about_you ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ad_hoc_data   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tradespeople  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.utility_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sections        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments     ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 6. DYNAMIC POLICY CLEANUP (Strips legacy/duplicate policies)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN ('estate_access', 'estates', 'documents', 'who_to_notify', 'notify_account_details', 'funeral_arrangements', 'about_you', 'ad_hoc_data', 'contacts', 'tradespeople', 'utility_details', 'sections', 'checklist_items', 'attachments')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 7. SECURITY DEFINER HELPERS (With row_security = off)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_estate_owner(check_estate_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.estates
        WHERE id = check_estate_id
        AND owner_id = auth.uid()
    );
$$;

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

-- Explicit EXECUTE grants (required for SECURITY DEFINER in Supabase 15+)
GRANT EXECUTE ON FUNCTION public.is_estate_owner(uuid)                  TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.is_estate_member_owner(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_estate_member_owner(uuid)            TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_estate_member_owner(uuid)            TO anon;
GRANT EXECUTE ON FUNCTION public.get_allowed_estate_ids(text)           TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_allowed_estate_ids()               TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_estate_role_for_current_user(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_or_create_current_estate_context() TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7b. create_estate: Idempotent estate creation (delete-then-insert).
--
-- Bypasses RLS via SECURITY DEFINER so the caller can always (re)create their
-- own estate even if a previous attempt left orphaned rows. Any existing
-- estate owned by the current user is deleted first (ON DELETE CASCADE
-- removes estate_access, sections, checklist_items, attachments, etc.).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_estate(estate_name text DEFAULT 'My Estate')
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
    new_estate_id uuid;
BEGIN
    -- Wipe any estate previously owned by this user (cascade cleans children).
    DELETE FROM public.estates WHERE owner_id = auth.uid();

    -- Create the fresh estate.
    INSERT INTO public.estates (owner_id, name)
    VALUES (auth.uid(), estate_name)
    RETURNING id INTO new_estate_id;

    -- Guarantee the owner access row exists and is accepted.
    INSERT INTO public.estate_access (estate_id, user_id, role, status)
    VALUES (new_estate_id, auth.uid(), 'owner', 'accepted');

    RETURN new_estate_id;
END;
$$;

-- CREATE FUNCTION grants EXECUTE to PUBLIC by default, so it must be revoked
-- before granting the narrower set. Without this, anon could call create_estate
-- (it fails harmlessly on the NOT NULL owner_id, but the RPC should not be
-- reachable at all). See migration 0031.
REVOKE ALL ON FUNCTION public.create_estate(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_estate(text) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7c. delete_my_account: Self-service account deletion.
--
-- Deleting the auth.users row is the whole database job, because every public
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
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 8. POLICIES: public.estates
-- ---------------------------------------------------------------------------
CREATE POLICY estates_select_any_linked ON public.estates
    FOR SELECT
    TO anon, authenticated
    USING ( id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY estates_owner_insert ON public.estates
    FOR INSERT
    TO authenticated
    WITH CHECK ( auth.uid() = owner_id );

-- Any accepted member holding the `owner` role may rename the estate, which
-- includes co-owners. WITH CHECK deliberately repeats USING: the old
-- `auth.uid() = owner_id` rejected co-owners, whose estate still belongs to
-- whoever created it. The guard trigger below keeps owner_id fixed instead.
CREATE POLICY estates_owner_update ON public.estates
    FOR UPDATE
    TO authenticated
    USING ( id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY estates_owner_delete ON public.estates
    FOR DELETE
    TO authenticated
    USING ( auth.uid() = owner_id );

-- Guard: an estate update may not change its identity fields. Deliberately
-- NOT SECURITY DEFINER — the function reads only OLD/NEW and touches no
-- tables.
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

DROP TRIGGER IF EXISTS estates_guard_update ON public.estates;
CREATE TRIGGER estates_guard_update
    BEFORE UPDATE ON public.estates
    FOR EACH ROW
    EXECUTE FUNCTION public.estates_guard_update();

-- ---------------------------------------------------------------------------
-- 9. POLICIES: public.estate_access
-- ---------------------------------------------------------------------------
-- A pending invite is readable only by the estate's owners (who issued it) and
-- by the invitee whose email it carries. The previous clause tested the row
-- rather than the requester, which made every pending code world-readable, and
-- the policy was open to anon. See migration 0030.
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

-- INSERT means "create an invite" and nothing more: the estate's owner, still
-- pending, unlinked, carrying a code. The previous `user_id = auth.uid()` branch
-- let any signed-in user insert an accepted owner row for any estate id and
-- grant themselves access with no invite involved. See migration 0030.
CREATE POLICY estate_access_owner_insert ON public.estate_access
    FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_estate_owner(estate_id)
        AND status = 'pending'
        AND user_id IS NULL
        AND invite_code IS NOT NULL
    );

CREATE POLICY estate_access_owner_update ON public.estate_access
    FOR UPDATE
    TO authenticated
    USING (
        public.is_estate_owner(estate_id)
    )
    WITH CHECK (
        public.is_estate_owner(estate_id)
    );

CREATE POLICY estate_access_owner_delete ON public.estate_access
    FOR DELETE
    TO authenticated
    USING (
        public.is_estate_owner(estate_id)
    );

-- Claiming an invite is a single, code-checked entry point. The old approach
-- used per-role UPDATE policies that SELECTed the invite and then UPDATEed it
-- from the client, so a WITH CHECK saw only the NEW row — an executor invite
-- could be claimed as an owner, and the client could not be trusted to have
-- verified the code at all. RLS also cannot see OLD, so immutability of a
-- claimed row cannot be expressed in a policy. claim_invite does the lookup and
-- the write in one locked transaction; the guard trigger below keeps a claim to
-- user_id/status only. See migration 0030.
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
        SELECT 1 FROM public.estate_access
        WHERE user_id = caller_id AND status = 'accepted'
    ) THEN
        RAISE EXCEPTION 'You already have access to an estate'
            USING ERRCODE = 'unique_violation';
    END IF;

    -- FOR UPDATE so two simultaneous claims of one code cannot both succeed.
    SELECT id, estate_id INTO target_id, target_estate
    FROM public.estate_access
    WHERE invite_code = upper(trim(p_code))
      AND status = 'pending'
      AND user_id IS NULL
    FOR UPDATE;

    IF target_id IS NULL THEN
        RAISE EXCEPTION 'Invalid invite code' USING ERRCODE = 'no_data_found';
    END IF;

    UPDATE public.estate_access
    SET user_id = caller_id, status = 'accepted'
    WHERE id = target_id;

    RETURN target_estate;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_invite(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_invite(text) TO authenticated, service_role;

-- Guard: claiming an invite may only set user_id and status. Deliberately NOT
-- SECURITY DEFINER — the function reads only OLD/NEW and touches no tables.
CREATE OR REPLACE FUNCTION public.estate_access_guard_claim()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
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

-- ---------------------------------------------------------------------------
-- 10. POLICIES: public.documents
-- ---------------------------------------------------------------------------
CREATE POLICY documents_select_any_linked ON public.documents
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY documents_owner_insert ON public.documents
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY documents_owner_update ON public.documents
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY documents_owner_delete ON public.documents
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 11. POLICIES: public.who_to_notify
-- ---------------------------------------------------------------------------
CREATE POLICY who_to_notify_select_any_linked ON public.who_to_notify
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY who_to_notify_owner_insert ON public.who_to_notify
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY who_to_notify_owner_update ON public.who_to_notify
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY who_to_notify_owner_delete ON public.who_to_notify
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 12. POLICIES: public.notify_account_details
-- ---------------------------------------------------------------------------
CREATE POLICY notify_account_details_select_any_linked ON public.notify_account_details
    FOR SELECT
    TO anon, authenticated
    USING (
        who_to_notify_id IN (
            SELECT who_to_notify_id
            FROM public.who_to_notify
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    );

CREATE POLICY notify_account_details_owner_insert ON public.notify_account_details
    FOR INSERT
    TO authenticated
    WITH CHECK (
        who_to_notify_id IN (
            SELECT who_to_notify_id
            FROM public.who_to_notify
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

CREATE POLICY notify_account_details_owner_update ON public.notify_account_details
    FOR UPDATE
    TO authenticated
    USING (
        who_to_notify_id IN (
            SELECT who_to_notify_id
            FROM public.who_to_notify
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    )
    WITH CHECK (
        who_to_notify_id IN (
            SELECT who_to_notify_id
            FROM public.who_to_notify
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

CREATE POLICY notify_account_details_owner_delete ON public.notify_account_details
    FOR DELETE
    TO authenticated
    USING (
        who_to_notify_id IN (
            SELECT who_to_notify_id
            FROM public.who_to_notify
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

-- ---------------------------------------------------------------------------
-- 13. POLICIES: public.funeral_arrangements
-- ---------------------------------------------------------------------------
CREATE POLICY funeral_arrangements_select_any_linked ON public.funeral_arrangements
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY funeral_arrangements_owner_insert ON public.funeral_arrangements
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY funeral_arrangements_owner_update ON public.funeral_arrangements
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY funeral_arrangements_owner_delete ON public.funeral_arrangements
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 13a. POLICIES: public.about_you
-- ---------------------------------------------------------------------------
CREATE POLICY about_you_select_any_linked ON public.about_you
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY about_you_owner_insert ON public.about_you
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY about_you_owner_update ON public.about_you
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY about_you_owner_delete ON public.about_you
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 13b. POLICIES: public.ad_hoc_data
-- ---------------------------------------------------------------------------
CREATE POLICY ad_hoc_data_select_any_linked ON public.ad_hoc_data
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY ad_hoc_data_owner_insert ON public.ad_hoc_data
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY ad_hoc_data_owner_update ON public.ad_hoc_data
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY ad_hoc_data_owner_delete ON public.ad_hoc_data
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 13c. POLICIES: public.contacts
-- ---------------------------------------------------------------------------
CREATE POLICY contacts_select_any_linked ON public.contacts
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY contacts_owner_insert ON public.contacts
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY contacts_owner_update ON public.contacts
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY contacts_owner_delete ON public.contacts
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 13d. POLICIES: public.tradespeople
-- ---------------------------------------------------------------------------
CREATE POLICY tradespeople_select_any_linked ON public.tradespeople
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY tradespeople_owner_insert ON public.tradespeople
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY tradespeople_owner_update ON public.tradespeople
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY tradespeople_owner_delete ON public.tradespeople
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 13e. POLICIES: public.utility_details
-- ---------------------------------------------------------------------------
CREATE POLICY utility_details_select_any_linked ON public.utility_details
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY utility_details_owner_insert ON public.utility_details
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY utility_details_owner_update ON public.utility_details
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY utility_details_owner_delete ON public.utility_details
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 14. POLICIES: public.sections
-- ---------------------------------------------------------------------------
CREATE POLICY sections_select_any_linked ON public.sections
    FOR SELECT
    TO anon, authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids()) );

CREATE POLICY sections_owner_insert ON public.sections
    FOR INSERT
    TO authenticated
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY sections_owner_update ON public.sections
    FOR UPDATE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) )
    WITH CHECK ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

CREATE POLICY sections_owner_delete ON public.sections
    FOR DELETE
    TO authenticated
    USING ( estate_id IN (SELECT public.get_allowed_estate_ids('owner')) );

-- ---------------------------------------------------------------------------
-- 14. POLICIES: public.checklist_items
-- ---------------------------------------------------------------------------
CREATE POLICY checklist_items_select_any_linked ON public.checklist_items
    FOR SELECT
    TO anon, authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    );

CREATE POLICY checklist_items_owner_insert ON public.checklist_items
    FOR INSERT
    TO authenticated
    WITH CHECK (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

-- Both owners and executors can toggle checklist items (the executor is
-- the one who will actually work through them). Only owners can add or
-- remove items, which is enforced by the INSERT/DELETE policies above/below.
CREATE POLICY checklist_items_linked_update ON public.checklist_items
    FOR UPDATE
    TO authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    )
    WITH CHECK (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    );

CREATE POLICY checklist_items_owner_delete ON public.checklist_items
    FOR DELETE
    TO authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

-- ---------------------------------------------------------------------------
-- 15. POLICIES: public.attachments
-- ---------------------------------------------------------------------------
CREATE POLICY attachments_select_any_linked ON public.attachments
    FOR SELECT
    TO anon, authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids())
        )
    );

CREATE POLICY attachments_owner_insert ON public.attachments
    FOR INSERT
    TO authenticated
    WITH CHECK (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

CREATE POLICY attachments_owner_update ON public.attachments
    FOR UPDATE
    TO authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    )
    WITH CHECK (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

CREATE POLICY attachments_owner_delete ON public.attachments
    FOR DELETE
    TO authenticated
    USING (
        section_id IN (
            SELECT id FROM public.sections
            WHERE estate_id IN (SELECT public.get_allowed_estate_ids('owner'))
        )
    );

-- ---------------------------------------------------------------------------
-- 16. STORAGE BUCKET & STORAGE POLICIES
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'estate-documents',
    'estate-documents',
    false,
    52428800,
    ARRAY['application/pdf','image/jpeg','image/png','image/heic','text/plain']
)
ON CONFLICT (id) DO NOTHING;

GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA storage TO authenticated;

DROP POLICY IF EXISTS estate_docs_select_linked ON storage.objects;
CREATE POLICY estate_docs_select_linked ON storage.objects
    FOR SELECT
    TO anon, authenticated
    USING (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids())
    );

DROP POLICY IF EXISTS estate_docs_owner_list_on_storage ON storage.objects;
CREATE POLICY estate_docs_owner_list_on_storage ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids('owner'))
    );

DROP POLICY IF EXISTS estate_docs_insert_owner ON storage.objects;
CREATE POLICY estate_docs_insert_owner ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids('owner'))
    );

DROP POLICY IF EXISTS estate_docs_update_owner ON storage.objects;
CREATE POLICY estate_docs_update_owner ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids('owner'))
    )
    WITH CHECK (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids('owner'))
    );

DROP POLICY IF EXISTS estate_docs_delete_owner ON storage.objects;
CREATE POLICY estate_docs_delete_owner ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'estate-documents'
        AND (storage.foldername(name))[1] = 'estate-documents'
        AND (storage.foldername(name))[2]::uuid IN (SELECT public.get_allowed_estate_ids('owner'))
    );

-- ---------------------------------------------------------------------------
-- 8. ADMIN / DIAGNOSTIC VIEWS
--
-- Read-only usage summary: counts and yes/no flags per estate, for gauging
-- how far a tester has got. No stored values are exposed -- the sensitive
-- columns (sort_code, account_code, ni_number, chi_number, phone PINs,
-- computer passwords, wifi_password, pet policy/microchip numbers) are never
-- selected.
--
-- SECURITY: this view spans ALL estates and bypasses RLS, so it must never be
-- readable by anon or authenticated (Supabase default privileges would grant
-- SELECT on a new view automatically). Restricted to service_role + postgres.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW public.estate_usage_summary AS
SELECT
    e.id                     AS estate_id,
    e.name                   AS estate_name,
    u.email                  AS owner_email,
    e.process_region         AS region,
    e.created_at::date       AS created,

    -- People
    (SELECT count(*) FROM public.estate_access a
      WHERE a.estate_id = e.id AND a.role = 'executor')                              AS exec_invited,
    (SELECT count(*) FROM public.estate_access a
      WHERE a.estate_id = e.id AND a.role = 'executor' AND a.status = 'accepted')    AS exec_joined,

    -- Personal details: flags only, never the values
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.full_name)  <> '') AS has_name,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.ni_number)  <> '') AS has_ni,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND btrim(x.chi_number) <> '') AS has_chi,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND x.passport_file_size > 0)   AS has_passport,
    EXISTS (SELECT 1 FROM public.about_you x WHERE x.estate_id = e.id AND x.licence_file_size  > 0)   AS has_licence,

    -- Section depth: how much was actually written
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id)                                AS sections,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND NOT s.is_standard)          AS custom_sections,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.notes)       <> '') AS with_notes,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.letter_text) <> '') AS with_letter,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.songs_csv)   <> '') AS with_songs,
    (SELECT count(*) FROM public.sections s WHERE s.estate_id = e.id AND btrim(s.youtube_url) <> '') AS with_video,

    -- Checklists
    (SELECT count(*) FROM public.checklist_items c JOIN public.sections s ON s.id = c.section_id
      WHERE s.estate_id = e.id)                                                                    AS todos,
    (SELECT count(*) FROM public.checklist_items c JOIN public.sections s ON s.id = c.section_id
      WHERE s.estate_id = e.id AND c.is_completed)                                                 AS todos_done,

    -- Records
    (SELECT count(*) FROM public.documents             d  WHERE d.estate_id  = e.id) AS documents,
    (SELECT count(*) FROM public.who_to_notify         w  WHERE w.estate_id  = e.id) AS who_to_notify,
    (SELECT count(*) FROM public.notify_account_details n
       JOIN public.who_to_notify w ON w.who_to_notify_id = n.who_to_notify_id
      WHERE w.estate_id = e.id)                                                      AS bank_accounts,
    (SELECT count(*) FROM public.funeral_arrangements  f  WHERE f.estate_id  = e.id) AS funeral,
    (SELECT count(*) FROM public.contacts              ct WHERE ct.estate_id = e.id) AS contacts,
    (SELECT count(*) FROM public.tradespeople          tp WHERE tp.estate_id = e.id) AS tradespeople,
    (SELECT count(*) FROM public.utility_details       ud WHERE ud.estate_id = e.id) AS utilities,
    (SELECT count(*) FROM public.ad_hoc_data           ah WHERE ah.estate_id = e.id) AS ad_hoc,

    -- Attachments
    (SELECT count(*) FROM public.attachments at JOIN public.sections s ON s.id = at.section_id
      WHERE s.estate_id = e.id)                                                      AS attachments,
    (SELECT coalesce(sum(at.file_size), 0)
       FROM public.attachments at JOIN public.sections s ON s.id = at.section_id
      WHERE s.estate_id = e.id)                                                      AS attachment_bytes,

    -- Recency: last edit anywhere in the estate
    GREATEST(
        (SELECT max(s.updated_at) FROM public.sections s WHERE s.estate_id = e.id),
        e.created_at
    )::date                                                                          AS last_activity

FROM public.estates e
JOIN auth.users u ON u.id = e.owner_id;

REVOKE ALL ON public.estate_usage_summary FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.estate_usage_summary TO service_role;

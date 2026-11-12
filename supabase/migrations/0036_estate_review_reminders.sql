-- Track annual owner review confirmations and queue discreet reminder emails.

CREATE TABLE public.estate_owner_review_status (
    estate_id uuid NOT NULL
        REFERENCES public.estates(id) ON DELETE CASCADE,
    owner_user_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,
    last_reviewed_at timestamptz,
    next_reminder_at timestamptz NOT NULL,
    reminders_enabled boolean NOT NULL DEFAULT true,
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (estate_id, owner_user_id)
);

ALTER TABLE public.estate_owner_review_status ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_owner_review_status FROM anon, authenticated;
GRANT SELECT ON TABLE public.estate_owner_review_status TO authenticated;
GRANT ALL ON TABLE public.estate_owner_review_status TO service_role;

CREATE POLICY estate_owner_review_status_read_self
    ON public.estate_owner_review_status
    FOR SELECT
    TO authenticated
    USING (
        owner_user_id = auth.uid()
        AND public.get_estate_role_for_current_user(estate_id) = 'owner'
    );

-- New and existing owners start with one year to review their information.
INSERT INTO public.estate_owner_review_status (
    estate_id,
    owner_user_id,
    next_reminder_at
)
SELECT DISTINCT
    ea.estate_id,
    ea.user_id,
    now() + interval '1 year'
FROM public.estate_access ea
WHERE ea.role = 'owner'
  AND ea.status = 'accepted'
  AND ea.user_id IS NOT NULL
ON CONFLICT (estate_id, owner_user_id) DO NOTHING;

CREATE TABLE public.estate_review_reminder_sends (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    estate_id uuid NOT NULL
        REFERENCES public.estates(id) ON DELETE CASCADE,
    owner_user_id uuid NOT NULL
        REFERENCES auth.users(id) ON DELETE CASCADE,
    reminder_for timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sending', 'sent', 'skipped')),
    attempts integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    sent_at timestamptz,
    last_error text,
    UNIQUE (estate_id, owner_user_id, reminder_for)
);

ALTER TABLE public.estate_review_reminder_sends ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.estate_review_reminder_sends
    FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.estate_review_reminder_sends TO service_role;

CREATE OR REPLACE FUNCTION public.confirm_estate_details_reviewed(
    requested_estate_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
    IF auth.uid() IS NULL
       OR public.get_estate_role_for_current_user(requested_estate_id)
            IS DISTINCT FROM 'owner' THEN
        RAISE EXCEPTION 'Only an estate owner can confirm a review'
            USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.estate_owner_review_status (
        estate_id,
        owner_user_id,
        last_reviewed_at,
        next_reminder_at,
        updated_at
    )
    VALUES (
        requested_estate_id,
        auth.uid(),
        now(),
        now() + interval '1 year',
        now()
    )
    ON CONFLICT (estate_id, owner_user_id) DO UPDATE
    SET last_reviewed_at = EXCLUDED.last_reviewed_at,
        next_reminder_at = EXCLUDED.next_reminder_at,
        updated_at = EXCLUDED.updated_at;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_estate_details_reviewed(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.confirm_estate_details_reviewed(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_estate_review_reminders_enabled(
    requested_estate_id uuid,
    enabled boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
    IF auth.uid() IS NULL
       OR public.get_estate_role_for_current_user(requested_estate_id)
            IS DISTINCT FROM 'owner' THEN
        RAISE EXCEPTION 'Only an estate owner can change reminder settings'
            USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.estate_owner_review_status (
        estate_id,
        owner_user_id,
        next_reminder_at,
        reminders_enabled,
        updated_at
    )
    VALUES (
        requested_estate_id,
        auth.uid(),
        now() + interval '1 year',
        enabled,
        now()
    )
    ON CONFLICT (estate_id, owner_user_id) DO UPDATE
    SET reminders_enabled = EXCLUDED.reminders_enabled,
        next_reminder_at = CASE
            WHEN EXCLUDED.reminders_enabled
                THEN now() + interval '1 year'
            ELSE public.estate_owner_review_status.next_reminder_at
        END,
        updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.set_estate_review_reminders_enabled(uuid, boolean)
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_estate_review_reminders_enabled(uuid, boolean)
    TO authenticated;

CREATE OR REPLACE FUNCTION public.queue_due_estate_review_reminders()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
DECLARE
    due_owner record;
BEGIN
    INSERT INTO public.estate_owner_review_status (
        estate_id,
        owner_user_id,
        next_reminder_at
    )
    SELECT DISTINCT
        ea.estate_id,
        ea.user_id,
        now() + interval '1 year'
    FROM public.estate_access ea
    WHERE ea.role = 'owner'
      AND ea.status = 'accepted'
      AND ea.user_id IS NOT NULL
    ON CONFLICT (estate_id, owner_user_id) DO NOTHING;

    FOR due_owner IN
        SELECT
            s.estate_id,
            s.owner_user_id,
            s.next_reminder_at
        FROM public.estate_owner_review_status s
        WHERE s.reminders_enabled
          AND s.next_reminder_at <= now()
          AND EXISTS (
              SELECT 1
              FROM public.estate_access ea
              WHERE ea.estate_id = s.estate_id
                AND ea.user_id = s.owner_user_id
                AND ea.role = 'owner'
                AND ea.status = 'accepted'
          )
        ORDER BY s.next_reminder_at
        FOR UPDATE OF s SKIP LOCKED
    LOOP
        INSERT INTO public.estate_review_reminder_sends (
            estate_id,
            owner_user_id,
            reminder_for
        )
        VALUES (
            due_owner.estate_id,
            due_owner.owner_user_id,
            due_owner.next_reminder_at
        )
        ON CONFLICT (estate_id, owner_user_id, reminder_for) DO NOTHING;

        UPDATE public.estate_owner_review_status
        SET next_reminder_at = greatest(
                due_owner.next_reminder_at + interval '1 year',
                now() + interval '1 year'
            ),
            updated_at = now()
        WHERE estate_id = due_owner.estate_id
          AND owner_user_id = due_owner.owner_user_id;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.claim_estate_review_reminders(
    batch_size integer DEFAULT 50
)
RETURNS SETOF public.estate_review_reminder_sends
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET row_security = off
AS $$
BEGIN
    RETURN QUERY
    WITH candidates AS (
        SELECT id
        FROM public.estate_review_reminder_sends
        WHERE status = 'pending'
           OR (status = 'sending' AND updated_at < now() - interval '15 minutes')
        ORDER BY created_at
        FOR UPDATE SKIP LOCKED
        LIMIT least(greatest(coalesce(batch_size, 50), 1), 100)
    )
    UPDATE public.estate_review_reminder_sends AS s
    SET status = 'sending',
        attempts = s.attempts + 1,
        updated_at = now(),
        last_error = NULL
    FROM candidates
    WHERE s.id = candidates.id
    RETURNING s.*;
END;
$$;

REVOKE ALL ON FUNCTION public.queue_due_estate_review_reminders()
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.queue_due_estate_review_reminders()
    TO service_role;
REVOKE ALL ON FUNCTION public.claim_estate_review_reminders(integer)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_estate_review_reminders(integer)
    TO service_role;

-- UnderCroft database test. Run sections 1-3 here, then let the
-- CrabKingsLair-hosted daily cron job run at 09:00 UTC. Run section 4 in
-- UnderCroft after that scheduled run.
-- In the app, first enable Settings > Annual email reminder for your owner.
-- The job sends to every owner currently due, so inspect section 3 and make
-- sure only your test account appears before the next scheduled run.

-- 1. Find your estate and owner UUIDs.
SELECT
    s.estate_id,
    s.owner_user_id,
    u.email,
    s.reminders_enabled,
    s.next_reminder_at
FROM public.estate_owner_review_status AS s
JOIN auth.users AS u ON u.id = s.owner_user_id
WHERE lower(u.email) = lower('YOUR_SIGN_IN_EMAIL');

-- 2. Make only your test owner's reminder due. Replace both UUIDs.
UPDATE public.estate_owner_review_status
SET next_reminder_at = now() - interval '1 minute'
WHERE estate_id = 'YOUR_ESTATE_UUID'::uuid
  AND owner_user_id = 'YOUR_OWNER_USER_UUID'::uuid
  AND reminders_enabled;

-- 3. Confirm only your test account is due before triggering the function.
SELECT
    s.estate_id,
    s.owner_user_id,
    u.email,
    s.next_reminder_at
FROM public.estate_owner_review_status AS s
JOIN auth.users AS u ON u.id = s.owner_user_id
JOIN public.estate_access AS ea
  ON ea.estate_id = s.estate_id
 AND ea.user_id = s.owner_user_id
WHERE s.reminders_enabled
  AND s.next_reminder_at <= now()
  AND ea.role = 'owner'
  AND ea.status = 'accepted'
ORDER BY s.next_reminder_at;

-- 4. After the next daily cron run at 09:00 UTC, check the latest send row.
SELECT status, attempts, sent_at, last_error
FROM public.estate_review_reminder_sends
WHERE estate_id = 'YOUR_ESTATE_UUID'::uuid
  AND owner_user_id = 'YOUR_OWNER_USER_UUID'::uuid
ORDER BY created_at DESC
LIMIT 1;

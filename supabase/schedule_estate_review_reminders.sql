-- Run in the UnderCroft project after enabling pg_cron and pg_net, deploying the
-- Edge Function, and adding the three named values to UnderCroft Vault.
-- Safe to re-run.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_net'
    ) THEN
        RAISE EXCEPTION 'Enable pg_net in UnderCroft before scheduling';
    END IF;

    IF (
        SELECT count(*)
        FROM vault.decrypted_secrets
        WHERE name IN (
            'undercroft_project_url',
            'undercroft_secret_key',
            'estate_review_cron_secret'
        )
    ) < 3 THEN
        RAISE EXCEPTION
            'Add the UnderCroft URL/key and reminder cron secret to Vault first';
    END IF;
END;
$$;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'undercroft-estate-review-reminders';

SELECT cron.schedule(
    'undercroft-estate-review-reminders',
    '0 9 * * *',
    $job$
        SELECT net.http_post(
            url := (
                SELECT decrypted_secret
                FROM vault.decrypted_secrets
                WHERE name = 'undercroft_project_url'
            ) || '/functions/v1/send-estate-review-reminders',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'apikey', (
                    SELECT decrypted_secret
                    FROM vault.decrypted_secrets
                    WHERE name = 'undercroft_secret_key'
                ),
                'x-cron-secret', (
                    SELECT decrypted_secret
                    FROM vault.decrypted_secrets
                    WHERE name = 'estate_review_cron_secret'
                )
            ),
            body := '{}'::jsonb
        );
    $job$
);

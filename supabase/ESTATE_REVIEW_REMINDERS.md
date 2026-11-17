# Annual Estate Review Reminders

Everything for this feature now lives in the UnderCroft project: reminder state,
the send queue, the Edge Function and the daily scheduler. Only accepted estate
owners are eligible. The Readiness section contains the review action and
last-reviewed date; Settings contains the separate annual email preference.
Email copy does not mention estate contents.

Existing owners are first due one year after migration 0036 is applied. New
owners are first due one year after the reminder queue initializes their row.

## Setup

1. Apply `migrations/0036_estate_review_reminders.sql` to the UnderCroft
   database. Keep the UnderCroft app changes that show the review action in
   Readiness and the annual email preference in Settings.
2. Add these Edge Function secrets in the UnderCroft project without putting
   their values in source control:

   - `BREVO_API_KEY`: shared with the `send-ticket-email` function
   - `CRON_SECRET`: a long, random value
   - `REMINDER_FROM_EMAIL`: `contact@crabkingslair.com`, the verified Brevo
     sender already used by the support email function

   The recipient sees this address with the sender name **UnderCroft**.
   The email directs owners to Readiness and the **I have checked my details**
   button. No app URL or deep-link setup is required; the email tells owners
   to open UnderCroft on their device.

   `SUPABASE_URL` and the secret key arrive automatically, so no
   `UNDERCROFT_SUPABASE_...` variables are needed any more.
3. Deploy from the UnderCroft repository:

   ```sh
   supabase functions deploy send-estate-review-reminders \
     --project-ref mpsygpgaakdtlgjzmbtr
   ```

   The handler checks `CRON_SECRET`; the checked-in `config.toml` disables the
   platform's legacy JWT check for both functions in this repository.
4. In the UnderCroft database, enable `pg_cron` and `pg_net`. Add these three
   values to UnderCroft Vault:

   - `undercroft_project_url`: `https://mpsygpgaakdtlgjzmbtr.supabase.co`
   - `undercroft_secret_key`: the UnderCroft `sb_secret_...` key
   - `estate_review_cron_secret`: the same value configured as `CRON_SECRET`

   They authorize the scheduled call to the function. If needed, create Vault
   entries in SQL Editor with `vault.create_secret(secret, name, description)`;
   do not commit real secret values or retain them in SQL Editor history.
5. Run `supabase/schedule_estate_review_reminders.sql` in the UnderCroft SQL
   Editor. It creates a daily 09:00 UTC job that calls the function.

## Test

Enable **Settings > Annual email reminder** for the test owner. Run sections 1-3
of [`test_estate_review_reminder.sql`](test_estate_review_reminder.sql) in the
UnderCroft SQL Editor and confirm that the due-owner list contains only the test
account. After the 09:00 UTC run, run section 4 to check the send row. The
message goes to the owner's sign-in email.

The first reminder for existing owners is one year after the migration.
Confirm the verified sender before enabling a real test send. A rare timeout
after Brevo accepts an email but before the send status is recorded could
result in a duplicate on retry.

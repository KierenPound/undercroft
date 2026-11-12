# Annual Estate Review Reminders

Reminder state and the send queue live in the UnderCroft database. The
reminder Edge Function and daily scheduler are hosted in CrabKingsLair, beside
its existing Brevo integration. Only accepted estate owners are eligible.
The Readiness section contains the review action and last-reviewed date;
Settings contains the separate annual email preference. Email copy does not
mention estate contents.

Existing owners are first due one year after migration 0036 is applied. New
owners are first due one year after the reminder queue initializes their row.

## Setup

1. Apply `migrations/0036_estate_review_reminders.sql` to the UnderCroft
   database.
2. In the CrabKingsLair repository, follow
   `supabase/ESTATE_REVIEW_REMINDERS.md` to configure its reminder function
   secrets, deploy the function, add the CrabKingsLair scheduler credentials
   to CrabKingsLair Vault, and create the daily 09:00 UTC cron job.
3. The CrabKingsLair function needs the UnderCroft project URL and the
   UnderCroft `sb_secret_...` key as Edge Function secrets. Do not put key
   values in this repository. The sender must be verified in Brevo, and
   `APP_URL` must point to the real UnderCroft app destination.

The scheduler must be created in the CrabKingsLair database, not UnderCroft.
The UnderCroft database only stores review records and reminder send statuses.
Use only the CrabKingsLair function and scheduler files; do not deploy or run
older UnderCroft-local copies of those deployment files.

## Testing

Enable **Settings > Annual email reminder** for the test owner. Run sections
1-3 of [`test_estate_review_reminder.sql`](test_estate_review_reminder.sql) in
the UnderCroft SQL Editor, then confirm that the due-owner list contains only
the test account. Let the CrabKingsLair job run at 09:00 UTC and run section 4
afterwards to check the send status. The email goes to the owner's Supabase
sign-in address. A claimed reminder advances the next due date by a year.
Developer tools are unrelated to this test.

The send queue records provider failures for retry. A rare timeout after
Brevo accepts an email but before UnderCroft records success could result in
a duplicate on retry.

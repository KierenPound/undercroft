-- Add a long-form letter column to the sections table.
-- Used by the "My Letter to You" page: a letter written by the estate owner
-- (potentially several thousand characters) stored on that section's row.
-- Only the estate owner can edit it (enforced by the existing
-- sections_owner_update RLS policy).

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS letter_text text NOT NULL DEFAULT '';

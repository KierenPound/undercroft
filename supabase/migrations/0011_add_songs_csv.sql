-- Add a persisted CSV playlist field to the sections table.
-- Used by the "My Songs" page to store a user-uploaded CSV with the columns:
-- You Tube video id, Song Title, Artist.

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS songs_csv text NOT NULL DEFAULT '';

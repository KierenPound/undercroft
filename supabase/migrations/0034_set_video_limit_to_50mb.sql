-- 0034: Keep estate uploads within Supabase's Free-plan per-file limit.
--
-- Migration 0033 raised the bucket limit to 100 MiB for video. The app now
-- caps videos at 50 MiB so they can be uploaded on a Free project as well.
-- Supabase's global upload limit must also allow 50 MiB (the Free-plan cap).

UPDATE storage.buckets
SET file_size_limit = 52428800
WHERE id = 'estate-documents';

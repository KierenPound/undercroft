-- 0022: Add file_size column to utility_details
--
-- Meter and stopcock photos now record their byte length, mirroring
-- attachments.file_size, so the stored image size can be checked from the
-- database rather than only the Storage dashboard. 0 means "not recorded".

ALTER TABLE public.utility_details
    ADD COLUMN IF NOT EXISTS file_size bigint NOT NULL DEFAULT 0;

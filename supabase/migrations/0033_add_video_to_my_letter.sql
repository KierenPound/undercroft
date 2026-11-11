-- 0033: "My Video to You" — a personal video on the "My Letter to You" page
--
-- The letter page gains an optional short video that the owner either records
-- with the device camera or picks from their library. The bytes live in the
-- private `estate-documents` bucket alongside every other file, so these
-- columns hold only the object path, its content type and its byte length.
-- An empty path means "no video".
--
-- The bucket previously allowed documents and images only and capped objects
-- at 50 MB, so a video upload would have been rejected before it started.
-- Widen it to 100 MB to match the app's own limit, and allow the containers
-- phone cameras actually produce (QuickTime/.mov on iOS, MP4 on Android).

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS video_path text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS video_mime text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS video_size_bytes bigint NOT NULL DEFAULT 0;

UPDATE storage.buckets
SET file_size_limit = 104857600,
    allowed_mime_types = ARRAY[
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/heic',
        'text/plain',
        'video/mp4',
        'video/quicktime',
        'video/x-m4v',
        'video/3gpp',
        'video/webm'
    ]
WHERE id = 'estate-documents';

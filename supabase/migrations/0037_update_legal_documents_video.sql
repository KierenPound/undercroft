-- Update the default "Song for the page" video on existing Legal Documents
-- sections. Only rows still carrying the previous default are changed, so any
-- user who picked their own video is left alone.

UPDATE sections
SET youtube_url = 'https://www.youtube.com/watch?v=xaqNFoTvRBs',
    updated_at = NOW()
WHERE title = 'Legal Documents'
  AND youtube_url = 'https://www.youtube.com/watch?v=GaZp4fJVHmQ';

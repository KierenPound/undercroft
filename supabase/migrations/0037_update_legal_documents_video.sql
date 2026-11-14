-- Set the "Song for the page" video on every Legal Documents section.

UPDATE sections
SET youtube_url = 'https://www.youtube.com/watch?v=xaqNFoTvRBs',
    updated_at = NOW()
WHERE title = 'Legal Documents';

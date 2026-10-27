-- 0021: Add Wi-Fi password column to sections
--
-- The "Phones / Computers" section stores a household Wi-Fi password
-- alongside device PINs and computer passwords. An empty string means
-- "not set".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS wifi_password text NOT NULL DEFAULT '';

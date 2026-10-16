-- 0007: Add phone/computer credential columns to sections
--
-- The "Phones / Computers" section on the What To Do First page stores the
-- unlock PINs for two phones and the login passwords for two computers
-- (a "blue" set and a "pink" set). All fields are plain text and editable
-- by the estate owner. An empty string means "not set".

ALTER TABLE public.sections
    ADD COLUMN IF NOT EXISTS phone_pin_1          text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS computer_password_1  text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS phone_pin_2          text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS computer_password_2  text NOT NULL DEFAULT '';

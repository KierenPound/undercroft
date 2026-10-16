-- Remove the built-in vet contact defaults.
--
-- The sample vet ("Tower vets" / 01738 583083 / the IVC link) was inserted as a
-- column default, so every new estate started with someone else's vet. Each
-- estate's vet differs, so the owner now fills these in themselves and the
-- columns default to empty.

ALTER TABLE public.sections
    ALTER COLUMN vet_name SET DEFAULT '';

ALTER TABLE public.sections
    ALTER COLUMN vet_phone SET DEFAULT '';

ALTER TABLE public.sections
    ALTER COLUMN vet_url SET DEFAULT '';

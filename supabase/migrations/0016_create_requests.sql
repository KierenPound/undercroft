-- ============================================================================
-- CrabKing's Lair — 3D artwork requests
--
-- This table now lives in the UnderCroft project. The CrabKing's Lair site
-- (index.html, artwork-request.html, buy-token.html) inserts here with the
-- publishable key, and the password-protected View Requests page reads it
-- through the Cloudflare Pages Function in the CrabKingsLair repository.
-- ============================================================================

create table if not exists public.requests (
  id            uuid primary key default gen_random_uuid(),
  card_name     text not null,
  name          text not null,
  email         text,
  mobile        text,
  artwork_type  text not null check (artwork_type in ('Full', 'Half', 'Not sure')),
  notes         text,
  created_at    timestamptz not null default now(),

  -- The form asks for "name, email or mobile" — require at least one way to reply.
  constraint requests_contact_required
    check (nullif(btrim(coalesce(email, '')), '') is not null
        or nullif(btrim(coalesce(mobile, '')), '') is not null)
);

-- Installations created before the notes column existed still need it.
alter table public.requests add column if not exists notes text;

alter table public.requests enable row level security;

-- Table-level privileges. The website inserts with the publishable (anon) key;
-- the View Requests page reads via the Cloudflare Pages Function using the
-- service_role key.
grant insert on public.requests to anon, authenticated;
grant select, insert on public.requests to service_role;

-- The website submits with the publishable key: insert only.
-- There is deliberately no read policy — the View Requests page is served by a
-- Cloudflare Pages Function that uses the secret key, so contact details never
-- leave the server.
drop policy if exists "Anyone can submit a request" on public.requests;
drop policy if exists "requests: public read" on public.requests;
drop policy if exists "requests: anyone can submit" on public.requests;

create policy "requests: anyone can submit"
  on public.requests
  for insert
  to anon, authenticated
  with check (true);

create index if not exists requests_created_at_idx
  on public.requests (created_at desc);

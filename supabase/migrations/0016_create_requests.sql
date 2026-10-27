-- ============================================================================
-- CrabKing's Lair — 3D artwork requests
-- Table for the artwork-request form on the CrabKing's Lair website.
-- ============================================================================

create table if not exists public.requests (
  id            uuid primary key default gen_random_uuid(),
  card_name     text not null,
  name          text not null,
  email         text,
  mobile        text,
  artwork_type  text not null check (artwork_type in ('Full', 'Half', 'Not sure')),
  created_at    timestamptz not null default now(),

  -- The form asks for "name, email or mobile" — require at least one way to reply.
  constraint requests_contact_required
    check (nullif(btrim(coalesce(email, '')), '') is not null
        or nullif(btrim(coalesce(mobile, '')), '') is not null)
);

alter table public.requests enable row level security;

-- The website submits with the anon (publishable) key: insert only.
drop policy if exists "requests: anyone can submit" on public.requests;
create policy "requests: anyone can submit"
  on public.requests
  for insert
  to anon, authenticated
  with check (true);

-- Read-only feed for the "View Requests" page.
drop policy if exists "requests: public read" on public.requests;
create policy "requests: public read"
  on public.requests
  for select
  to anon, authenticated
  using (true);

-- Contact details stay private: the anon key can only read these columns.
revoke select on public.requests from anon, authenticated;
grant select (id, card_name, name, artwork_type, created_at)
  on public.requests to anon, authenticated;

create index if not exists requests_created_at_idx
  on public.requests (created_at desc);

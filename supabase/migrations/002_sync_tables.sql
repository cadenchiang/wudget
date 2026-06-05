-- Cloud sync tables for Orbit (expenses, cards, prefs), per-user via RLS.
-- Location fields are intentionally absent: purchase locations never leave the device.
-- Soft-delete tombstones (deleted flag) let deletions propagate across devices;
-- rows hard-cascade when the auth user is deleted (account deletion wipes the cloud).

create table public.expenses (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount double precision not null,
  merchant text not null,
  card text not null default '',
  date timestamptz not null,
  category text not null,
  notes text not null default '',
  excluded_from_budget boolean not null default false,
  via_wallet_import boolean not null default false,
  recurrence text not null default 'none',
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.user_cards (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  credit_limit double precision,
  created_at timestamptz not null default now(),
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table public.user_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  monthly_budget double precision not null default 0,
  variable_default boolean not null default false,
  currency_code text not null default 'USD',
  updated_at timestamptz not null default now()
);

create index expenses_user_updated_idx on public.expenses (user_id, updated_at);
create index user_cards_user_idx on public.user_cards (user_id);

alter table public.expenses enable row level security;
alter table public.user_cards enable row level security;
alter table public.user_prefs enable row level security;

create policy "own expenses" on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own cards" on public.user_cards
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own prefs" on public.user_prefs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

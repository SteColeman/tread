-- Tread schema: footwear lifecycle intelligence
-- Run this in the Supabase SQL editor.

create extension if not exists "pgcrypto";

create table if not exists public.footwear_items (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    brand text not null default '',
    type text not null,
    date_added timestamptz not null default now(),
    date_purchased timestamptz,
    status text not null default 'Active',
    is_default boolean not null default false,
    expected_lifespan_km double precision not null default 800,
    notes text not null default '',
    color_tag text not null default 'slate',
    updated_at timestamptz not null default now()
);

create table if not exists public.wear_sessions (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    date timestamptz not null,
    steps integer not null default 0,
    distance_km double precision not null default 0,
    footwear_id uuid references public.footwear_items(id) on delete set null,
    is_manual boolean not null default false,
    updated_at timestamptz not null default now()
);

create table if not exists public.condition_logs (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    footwear_id uuid not null references public.footwear_items(id) on delete cascade,
    date timestamptz not null default now(),
    rating integer not null default 3,
    notes text not null default '',
    affected_areas text[] not null default '{}',
    updated_at timestamptz not null default now()
);

create index if not exists footwear_items_user_idx on public.footwear_items(user_id);
create index if not exists wear_sessions_user_idx on public.wear_sessions(user_id);
create index if not exists wear_sessions_footwear_idx on public.wear_sessions(footwear_id);
create index if not exists condition_logs_user_idx on public.condition_logs(user_id);
create index if not exists condition_logs_footwear_idx on public.condition_logs(footwear_id);

-- RLS
alter table public.footwear_items enable row level security;
alter table public.wear_sessions enable row level security;
alter table public.condition_logs enable row level security;

drop policy if exists "footwear_items_owner" on public.footwear_items;
create policy "footwear_items_owner" on public.footwear_items
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "wear_sessions_owner" on public.wear_sessions;
create policy "wear_sessions_owner" on public.wear_sessions
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "condition_logs_owner" on public.condition_logs;
create policy "condition_logs_owner" on public.condition_logs
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

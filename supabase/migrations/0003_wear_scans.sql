-- Wear scans: AI outsole analysis history per footwear item
create table if not exists public.wear_scans (
    id uuid primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    footwear_id uuid not null references public.footwear_items(id) on delete cascade,
    date timestamptz not null default now(),
    km_at_scan double precision not null default 0,
    steps_at_scan integer not null default 0,
    score integer not null default 0,
    verdict text not null default '',
    estimated_km_remaining double precision not null default 0,
    estimated_km_total_life double precision not null default 0,
    strike_pattern text not null default 'Mixed',
    pronation text not null default 'Unclear',
    dominant_zones text[] not null default '{}',
    injury_notes jsonb not null default '[]',
    shots jsonb not null default '[]',
    is_baseline boolean not null default false,
    updated_at timestamptz not null default now()
);

create index if not exists wear_scans_user_idx on public.wear_scans(user_id);
create index if not exists wear_scans_footwear_idx on public.wear_scans(footwear_id);

alter table public.wear_scans enable row level security;

drop policy if exists "wear_scans_owner" on public.wear_scans;
create policy "wear_scans_owner" on public.wear_scans
    for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

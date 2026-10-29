-- Boundary Tournament Hub — Supabase/PostgreSQL starter schema
-- Apply in a Supabase project after enabling pgcrypto.
create extension if not exists pgcrypto;

create type public.app_role as enum ('captain', 'admin');
create type public.team_status as enum ('pending', 'approved', 'rejected', 'suspended');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  mobile_number text,
  role public.app_role not null default 'captain',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  team_name text not null,
  slug text not null unique,
  captain_user_id uuid not null unique references public.profiles(id) on delete restrict,
  captain_name text not null,
  captain_mobile text not null,
  logo_url text,
  location text,
  description text,
  registration_status public.team_status not null default 'pending',
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint team_name_nonempty check (length(trim(team_name)) > 0),
  constraint captain_mobile_format check (captain_mobile ~ '^[6-9][0-9]{9}$')
);

create table public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete restrict,
  player_name text not null,
  gotra text not null,
  father_name text not null,
  mobile_number text not null,
  photo_url text,
  playing_role text check (playing_role in ('Batter','Bowler','All-rounder','Wicketkeeper') or playing_role is null),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_name_nonempty check (length(trim(player_name)) > 0),
  constraint gotra_nonempty check (length(trim(gotra)) > 0),
  constraint father_name_nonempty check (length(trim(father_name)) > 0),
  constraint player_mobile_format check (mobile_number ~ '^[6-9][0-9]{9}$')
);

create table public.tournament_settings (
  id uuid primary key default gen_random_uuid(),
  tournament_name text not null default 'Boundary Premier League',
  tournament_description text not null default '',
  logo_url text,
  banner_url text,
  start_date date,
  end_date date,
  registration_open boolean not null default true,
  registration_deadline timestamptz,
  max_players_per_team integer not null default 15 check (max_players_per_team between 1 and 30),
  organizer_contact text,
  rules text not null default '',
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  record_type text not null,
  record_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index teams_status_idx on public.teams(registration_status);
create index teams_name_idx on public.teams(lower(team_name));
create index players_team_id_idx on public.players(team_id);
create index players_name_idx on public.players(lower(player_name));
create index players_mobile_idx on public.players(mobile_number);
create index audit_logs_created_at_idx on public.audit_logs(created_at desc);

-- A profile is created on signup. The role is always captain by default;
-- admin role must be assigned manually by a trusted project owner using SQL.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, mobile_number, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', 'Captain'),
    nullif(new.raw_user_meta_data ->> 'mobile_number', ''),
    'captain'
  ) on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin');
$$;

create or replace function public.my_team_id()
returns uuid language sql stable security definer set search_path = '' as $$
  select t.id from public.teams t where t.captain_user_id = auth.uid() limit 1;
$$;

-- Keep updated_at current.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
create trigger teams_updated_at before update on public.teams for each row execute procedure public.set_updated_at();
create trigger players_updated_at before update on public.players for each row execute procedure public.set_updated_at();
create trigger settings_updated_at before update on public.tournament_settings for each row execute procedure public.set_updated_at();

-- Public-facing views explicitly omit mobile numbers and authentication data.
create or replace view public.public_teams with (security_invoker = true) as
select t.id, t.team_name, t.slug, t.captain_name, t.logo_url, t.location, t.description,
       t.registration_status, t.created_at,
       (select count(*) from public.players p where p.team_id = t.id and p.is_active) as player_count
from public.teams t where t.registration_status = 'approved';

create or replace view public.public_players with (security_invoker = true) as
select p.id, p.player_name, p.gotra, p.father_name, p.playing_role, t.team_name, t.slug
from public.players p join public.teams t on t.id = p.team_id
where p.is_active and t.registration_status = 'approved';

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.tournament_settings enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: users can read/update only their own non-role profile fields.
create policy "profile read self or admin" on public.profiles for select to authenticated
using (id = auth.uid() or public.is_admin());
create policy "profile update self or admin" on public.profiles for update to authenticated
using (id = auth.uid() or public.is_admin())
with check ((id = auth.uid() and role = 'captain') or public.is_admin());

-- Teams: public can read approved team records; captains can read their own team;
-- only the owning captain can create a pending team; admins manage all statuses.
create policy "approved teams public read" on public.teams for select to anon, authenticated
using (registration_status = 'approved' or captain_user_id = auth.uid() or public.is_admin());
create policy "captain create own pending team" on public.teams for insert to authenticated
with check (captain_user_id = auth.uid() and registration_status = 'pending' and not public.is_admin());
create policy "captain update own team limited status" on public.teams for update to authenticated
using (captain_user_id = auth.uid() or public.is_admin())
with check ((captain_user_id = auth.uid() and registration_status in ('pending','approved')) or public.is_admin());
create policy "admin delete teams" on public.teams for delete to authenticated using (public.is_admin());

-- Players table contains private mobile data. Do not grant anon direct access.
create policy "captain and admin read players" on public.players for select to authenticated
using (team_id = public.my_team_id() or public.is_admin());
create policy "captain add players to own team" on public.players for insert to authenticated
with check (team_id = public.my_team_id() and not public.is_admin());
create policy "captain update own players" on public.players for update to authenticated
using (team_id = public.my_team_id() or public.is_admin())
with check (team_id = public.my_team_id() or public.is_admin());
create policy "captain deactivate own players or admin delete" on public.players for delete to authenticated
using (team_id = public.my_team_id() or public.is_admin());

create policy "settings public read" on public.tournament_settings for select to anon, authenticated using (true);
create policy "admin manages settings" on public.tournament_settings for all to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "admin reads audit logs" on public.audit_logs for select to authenticated using (public.is_admin());
create policy "admin writes audit logs" on public.audit_logs for insert to authenticated with check (public.is_admin());

-- Important: create public views with only the allowed columns. Grant view access,
-- while keeping base players table unavailable to anon. Test these policies in Supabase.
grant select on public.public_teams to anon, authenticated;
grant select on public.public_players to anon, authenticated;
grant select on public.tournament_settings to anon, authenticated;

insert into public.tournament_settings (tournament_name, tournament_description, registration_open, max_players_per_team)
select 'Boundary Premier League', 'A celebration of local cricket, team spirit and unforgettable match days.', true, 15
where not exists (select 1 from public.tournament_settings);

-- Securely provision an administrator from the Supabase SQL editor only after
-- the user has signed up. Replace the UUID with the trusted user's auth.users id:
-- update public.profiles set role = 'admin' where id = 'REPLACE-WITH-USER-UUID';

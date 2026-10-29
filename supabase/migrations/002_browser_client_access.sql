-- Safe access for the static browser client. Apply after 001_initial_schema.sql.
alter table public.tournament_settings add column if not exists location text;

-- SECURITY INVOKER views require the caller to have SELECT on their source
-- columns and matching RLS policies. The anon role receives no private columns.
grant select (id, team_name, slug, captain_name, logo_url, location, description,
             registration_status, created_at)
on public.teams to anon, authenticated;
grant select (id, team_id, player_name, gotra, father_name, playing_role,
             is_active, created_at)
on public.players to anon, authenticated;
grant select on public.teams, public.players, public.profiles to authenticated;

drop policy if exists "public read active approved players" on public.players;
create policy "public read active approved players" on public.players
for select to anon, authenticated
using (is_active and exists (
  select 1 from public.teams t
  where t.id = players.team_id and t.registration_status = 'approved'
));

-- Keep player mobile values private even for the anon role by granting SELECT
-- only on the public view's non-sensitive source columns above.

-- Captains may edit their own team details but only an admin may change status.
create or replace function public.protect_team_registration_status()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.registration_status is distinct from old.registration_status
     and not public.is_admin() then
    raise exception 'Only an administrator can change team registration status';
  end if;
  if new.captain_user_id is distinct from old.captain_user_id
     and not public.is_admin() then
    raise exception 'Only an administrator can change team ownership';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_team_registration_status on public.teams;
create trigger protect_team_registration_status
before update on public.teams
for each row execute procedure public.protect_team_registration_status();

-- Ensure one roster entry per mobile number across the tournament.
create unique index if not exists players_mobile_number_unique
on public.players (mobile_number);

-- Provide a safe way for an authenticated captain to read their own profile role.
grant select on public.profiles to authenticated;

-- Least-privilege grants and policies for the static Supabase browser client.
-- Apply after 001_initial_schema.sql and 002_browser_client_access.sql.

-- The public views deliberately expose approved, non-sensitive columns only.
-- Run them as their owner so callers do not need broad reads on the base tables.
alter view public.public_teams set (security_invoker = false);
alter view public.public_players set (security_invoker = false);
grant select on public.public_teams, public.public_players to anon, authenticated;

-- Signed-in captains must not inherit the public policy on private base tables.
drop policy if exists "approved teams public read" on public.teams;
create policy "approved teams public read" on public.teams
for select to anon using (registration_status = 'approved');

drop policy if exists "public read active approved players" on public.players;
create policy "public read active approved players" on public.players
for select to anon using (is_active and exists (
  select 1 from public.teams t
  where t.id = players.team_id and t.registration_status = 'approved'
));

-- Captains can create/update their roster; admins can approve teams and edit settings.
grant insert (team_name, slug, captain_user_id, captain_name, captain_mobile, location, description)
on public.teams to authenticated;
grant update (registration_status, rejection_reason)
on public.teams to authenticated;

grant insert (team_id, player_name, gotra, father_name, mobile_number, playing_role, is_active)
on public.players to authenticated;
grant update (player_name, gotra, father_name, mobile_number, playing_role, is_active)
on public.players to authenticated;

grant update (tournament_name, tournament_description, max_players_per_team,
              registration_deadline, organizer_contact, registration_open)
on public.tournament_settings to authenticated;

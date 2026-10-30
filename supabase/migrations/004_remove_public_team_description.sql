-- Remove the team description field from the public API without deleting any
-- existing descriptions from public.teams.
drop view if exists public.public_teams;

create view public.public_teams with (security_invoker = false) as
select t.id, t.team_name, t.slug, t.captain_name, t.logo_url, t.location,
       t.registration_status, t.created_at,
       (select count(*) from public.players p where p.team_id = t.id and p.is_active) as player_count
from public.teams t
where t.registration_status = 'approved';

grant select on public.public_teams to anon, authenticated;

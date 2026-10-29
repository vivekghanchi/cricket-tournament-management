# Acceptance / smoke-test checklist

## Public pages
- [ ] Home page stats update when demo data changes.
- [ ] Teams directory lists approved teams only.
- [ ] Search matches team and captain names; sorting works.
- [ ] Team squad page displays player name, gotra, father's name and role.
- [ ] Public player directory supports search and team filtering.
- [ ] Public UI never renders player mobile numbers.
- [ ] Team share action copies a shareable URL where clipboard access is available.

## Captain demo flow
- [ ] Team registration validates required fields and Indian mobile format.
- [ ] Team names and captain mobile numbers are checked for duplicates.
- [ ] Newly registered teams start as Pending.
- [ ] Captain can add/edit/deactivate players for the selected team.
- [ ] Invalid mobile numbers are rejected.
- [ ] Duplicate player mobile numbers are rejected in the demo.
- [ ] Squad limit is enforced in the UI demo.
- [ ] Destructive removal requires confirmation.

## Admin demo flow
- [ ] Pending teams can be approved or rejected.
- [ ] Approved teams appear in the public directory.
- [ ] Tournament name, registration status, deadline and squad limit can be changed.
- [ ] Team and player CSV exports download.
- [ ] Reset demo restores sample data.

## Production security tests still required
- [ ] Unauthenticated user cannot access captain/admin server routes.
- [ ] Captain cannot read or mutate another team's players by changing request IDs.
- [ ] Public API/views never return mobile numbers.
- [ ] Captain cannot assign themselves the admin role.
- [ ] Concurrent player creation cannot exceed squad limit.
- [ ] Registration deadline is enforced server-side.
- [ ] RLS tests pass for anon, captain A, captain B and admin.

# Boundary — Cricket Tournament Hub

A responsive cricket tournament website with Supabase Auth, captain squad management, public team/player directories, administrator approvals, tournament settings and CSV exports.

## Quick start

1. Download and unzip the project.
2. Open `index.html` in a modern browser. No build step is needed.
3. The site loads teams, players and tournament settings from the configured Supabase project. Captains create accounts and sign in with email and password, then manage their team roster.
4. Administrators sign in with an account whose `profiles.role` is `admin`; the footer's **Admin sign in** opens the protected organizer workspace.

## Code quality tools

ESLint and Prettier are configured as development dependencies. Install them with `npm install`, then run:

- `npm run lint` to check the browser JavaScript.
- `npm run format` to format the HTML, CSS and JavaScript files.
- `npm run format:check` to check formatting without changing files.

## What's included

- `index.html` — page structure and metadata.
- `assets/css/styles.css` — site styles.
- `assets/js/app.js` — browser UI flows backed by Supabase Auth and PostgreSQL.
- `supabase/migrations/001_initial_schema.sql` — PostgreSQL tables, indexes, triggers, public views and starter RLS policies.
- `supabase/migrations/002_browser_client_access.sql`, `003_browser_client_permissions.sql`, and `004_remove_public_team_description.sql` — browser-client grants, least-privilege access policies, and public view updates.
- `.env.example` — expected environment variable names for a future Next.js/Supabase integration.
- `tests/smoke-checklist.md` — acceptance checklist for manual/automated testing.

## Operational notes

This is a static browser application that uses Supabase Auth and PostgreSQL directly. Row-level security protects database records, and public views omit player mobile numbers. Configure email confirmation and SMTP in Supabase Auth for reliable account verification. The current client-side squad limit is a convenience check; enforce it in a transaction or database RPC before relying on it under concurrent requests.

The static client uses only the project URL and publishable key. Never expose a service-role key in browser code. Review the RLS policies before accepting real registrations, and use a database transaction or RPC to enforce the squad limit under concurrent requests.

## Supabase setup

1. Create a Supabase project.
2. Open the SQL Editor and run `supabase/migrations/001_initial_schema.sql`, followed by migrations `002`, `003`, and `004` in order.
3. In **Authentication → Sign In / Providers → Email**, enable email and password authentication. If email confirmation is enabled, captains verify their email, sign in, then submit team details. Configure SMTP for reliable delivery.
4. The static prototype's public Supabase URL and publishable key are set in `assets/js/supabase-config.js`. These values are safe to expose in browser code; never place a service-role key there.
5. Sign up the first trusted administrator normally. In the SQL Editor, find that user's UUID in `auth.users`, then run the commented `UPDATE public.profiles ... role = 'admin'` statement with that UUID.
6. Review and test every RLS policy as `anon`, a captain, and an admin before accepting real registrations.

## Recommended production implementation

Use Next.js App Router, TypeScript, Tailwind CSS, Supabase Auth, server-side Supabase clients, and server actions/route handlers. Add Zod validation on the server. Use the public views for public listings; never return player mobile numbers from public APIs. For captain operations, derive `team_id` from the authenticated user's database relationship rather than accepting it from the client. Admin role changes must be performed by a trusted operator, not a public signup form.

## Deploying the prototype

The `index.html` file can be hosted on any static hosting provider. Add the deployed site's URL to Supabase Auth's allowed redirect URLs.

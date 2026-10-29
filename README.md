# Boundary — Cricket Tournament Hub

A responsive, interactive cricket tournament website prototype with team registration, captain squad management, public team/player directories, demo admin approvals, tournament settings and CSV exports.

## Quick start

1. Download and unzip the project.
2. Open `index.html` in a modern browser. No build step is needed.
3. Data is saved in that browser's `localStorage`. Use **Admin demo** in the footer to approve pending teams and change tournament settings.
4. Use **Register team** to create a pending team and captain demo login. The captain dashboard lets you add/edit/remove players and enforces the configured squad limit in the browser demo.

## Code quality tools

ESLint and Prettier are configured as development dependencies. Install them with `npm install`, then run:

- `npm run lint` to check the browser JavaScript.
- `npm run format` to format the HTML, CSS and JavaScript files.
- `npm run format:check` to check formatting without changing files.

## What's included

- `index.html` — page structure and metadata.
- `assets/css/styles.css` — site styles.
- `assets/js/app.js` — interactive demo flows and localStorage data handling.
- `supabase/migrations/001_initial_schema.sql` — PostgreSQL tables, indexes, triggers, public views and starter RLS policies for a Supabase-backed production build.
- `.env.example` — expected environment variable names for a future Next.js/Supabase integration.
- `tests/smoke-checklist.md` — acceptance checklist for manual/automated testing.

## Demo limitations — read before using real data

This is a **functional browser demo**, not a production-secure full-stack deployment. The interactive forms and workflows persist locally in one browser; no real authentication, remote database, server-side authorization, concurrent squad-limit locking, image storage or secure admin login is connected yet. The demo stores a password in local storage for demonstration only. **Do not enter real passwords or real personal information.** Public page mobile numbers are not displayed, but local demo data is not a secure database.

To use this with a real tournament, build/connect the Next.js server actions or API routes to Supabase Auth and PostgreSQL, apply the migration, review the RLS policies with tests, and replace all browser-side demo authentication/actions with server-verified operations. In production, use a database transaction or RPC to enforce the squad limit under concurrent requests. Use the Supabase service-role key only on the server.

## Supabase setup

1. Create a Supabase project.
2. Open the SQL Editor and run `supabase/migrations/001_initial_schema.sql` (review it first for your project requirements).
3. Configure Supabase Auth with the sign-in method you intend to use. For SMS OTP, configure an SMS provider first; otherwise use password-based auth with Supabase Auth.
4. Add the URL and anon key to your Next.js server/client environment as appropriate. Keep the service-role key server-only.
5. Sign up the first trusted administrator normally. In the SQL Editor, find that user's UUID in `auth.users`, then run the commented `UPDATE public.profiles ... role = 'admin'` statement with that UUID.
6. Test every RLS policy as `anon`, a captain, and an admin before accepting real registrations. The browser prototype is not wired to this database migration.

## Recommended production implementation

Use Next.js App Router, TypeScript, Tailwind CSS, Supabase Auth, server-side Supabase clients, and server actions/route handlers. Add Zod validation on the server. Use the public views for public listings; never return player mobile numbers from public APIs. For captain operations, derive `team_id` from the authenticated user's database relationship rather than accepting it from the client. Admin role changes must be performed by a trusted operator, not a public signup form.

## Deploying the prototype

The `index.html` file can be hosted as a static site on any static hosting provider. This is suitable only for reviewing the design and demo flows. For real tournament operations, deploy the production Next.js/Supabase integration rather than this localStorage prototype.

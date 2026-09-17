# Train Defect Reporter v2

Full React/Vite/Supabase app with the existing D&V workflow plus shared Exam Mode.

## New features
- User landing page with D&V and Exam Mode
- Fleet-driven setup, seeded with Azuma and coaches 829 to 821
- Six-digit unit exams shared between authenticated users
- Separate defect records grouped by unit and coach
- Admin tabs for D&V and exams
- SAP booked checkbox with booking audit fields
- Soft-delete exams, retained for 10 days before purge

## Deploy
1. Back up your Supabase project.
2. Run `supabase/migrations/002_exam_mode_full_setup.sql` in Supabase SQL Editor. It is designed for the supplied original schema.
3. Create/promote an admin using the SQL comment at the bottom of the migration.
4. For automatic permanent deletion, schedule `select public.purge_expired_exams();` daily using Supabase Cron.
5. Copy `.env.example` to `.env.local` and add the URL and publishable key. Never add a service-role key to the frontend.
6. Run `npm install`, then `npm run dev`.
7. Push to `main`; the included GitHub Actions workflow deploys GitHub Pages.

## Adding another fleet
Insert a row into `public.fleets`, for example:
```sql
insert into public.fleets(code,name,coach_numbers) values('NEW','New Fleet',array['101','102']);
```
The fleet selector updates from the database without frontend changes. The current interface displays the Azuma 829 to 821 coach sequence. If future fleets use different coaches, update `COACHES` in `src/App.jsx` or extend the editor to read `fleets.coach_numbers`.

## Important
Test RLS with a normal user and admin before production. The 10-day purge is database-driven and only runs automatically if the scheduled Cron job is configured.

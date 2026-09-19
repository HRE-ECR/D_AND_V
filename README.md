# Train Defect Reporter v3

GitHub Pages-ready React/Vite PWA backed by Supabase.

## v3 changes

- A D&V report can contain up to 10 photos.
- Users can add or remove photos before submitting.
- Admins see every photo attached to a D&V report.
- Existing one-photo reports are migrated into `defect_images` by the SQL setup.
- Landing-page D&V wording now reads `Report damage and vandalism.`
- Exam deletion is a compact icon control rather than a full-width button.

## Supabase

1. Back up the existing Supabase project.
2. Run `full-supabase-setup.sql` in the Supabase SQL Editor. It is the complete rerunnable setup.
3. Promote the required admin by using the commented query at the bottom of the SQL file.
4. Schedule `select public.purge_expired_exams();` daily using a trusted Supabase Cron job.

The SQL retains existing D&V records, removes the old `NOT NULL` requirement from `defects.image_path`, creates `defect_images`, and migrates existing image paths into the new child table.

## Local development

```bash
cp .env.example .env.local
npm install
npm run dev
```

## GitHub Pages

Add these repository Actions secrets:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Push to `main`. The included workflow builds and deploys the `dist` folder.

## Acceptance checks

- Add one photo, then add another before submission.
- Remove a selected photo before submission.
- Confirm one D&V defect is created with multiple `defect_images` rows.
- Confirm the admin dashboard displays all attached images.
- Confirm the exam delete icon does not consume the exam tile.
- Test normal-user and admin RLS independently before production rollout.

# Train Defect Reporter v3.1

## Fixes
- Fixes D&V submit RLS failure by allowing a user to read back their own newly inserted defect ID.
- D&V and Exam descriptions accept one non-space character.
- Supports up to 10 photos on one D&V report.
- Compact exam delete icon.

## Deploy
1. Back up Supabase.
2. Run `full-supabase-setup.sql` in SQL Editor. Run the whole file.
3. Promote the admin with the commented query at the end.
4. Add GitHub secrets `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
5. Push to `main`.
6. Configure trusted daily Cron: `select public.purge_expired_exams();`

# Deployment checklist
- [ ] Back up current Supabase database
- [ ] Run `002_exam_mode_full_setup.sql`
- [ ] Confirm Azuma appears in `fleets`
- [ ] Test normal user can create/open exams and add defects
- [ ] Test normal user cannot tick SAP boxes or view deleted exams
- [ ] Test admin can view both dashboards, tick SAP, and soft-delete exams
- [ ] Configure daily Cron call to `select public.purge_expired_exams();`
- [ ] Add GitHub Actions secrets
- [ ] Run `npm run build` and deploy

# Deployment checklist

## Supabase
- [ ] Project created in the correct region
- [ ] `001_setup.sql` executed successfully
- [ ] Email/password authentication configured
- [ ] Public sign-up disabled if accounts are staff-managed
- [ ] At least one user account created
- [ ] At least one account promoted to `admin`
- [ ] `defect-images` bucket is private
- [ ] Site URL and Redirect URLs contain the final GitHub Pages URL
- [ ] User can submit a report and photo
- [ ] User cannot open the admin dashboard or list reports
- [ ] Admin can list reports, display images and delete after confirmation

## GitHub
- [ ] Repository created and files pushed to `main`
- [ ] Actions secrets added: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`
- [ ] Pages source set to GitHub Actions
- [ ] Deployment workflow passes
- [ ] Deployed URL opens without console errors

## Device acceptance
- [ ] Desktop browser login and installation tested
- [ ] iOS Safari camera/photo picker and Add to Home Screen tested
- [ ] Android Chrome camera/photo picker and installation tested
- [ ] Poor-signal behaviour understood by staff
- [ ] 10 MB image limit tested with operational devices

## Governance and launch
- [ ] Privacy/data-protection review completed
- [ ] Data retention and deletion responsibilities agreed
- [ ] Urgent safety escalation wording approved
- [ ] Support owner and admin owners nominated
- [ ] Staff instructions issued
- [ ] Backup/recovery and Supabase usage limits reviewed

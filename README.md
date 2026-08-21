# Train Defect Reporter

Installable responsive web app for desktop, iOS and Android. Staff submit a train number, coach number, description and photo. Administrators see all reports and can delete them after a confirmation prompt.

## Architecture
- React + Vite frontend, deployed by GitHub Actions to GitHub Pages
- Supabase email/password Auth
- Supabase Postgres with Row Level Security (RLS)
- Private Supabase Storage bucket with one-hour signed image URLs
- Progressive Web App (PWA), installable from supported browsers

## 1. Supabase setup
1. Create a Supabase project.
2. Open **SQL Editor**, paste `supabase/migrations/001_setup.sql`, and run it once.
3. In **Authentication > Providers > Email**, enable email/password. For a staff-only system, disable public sign-ups and create users in **Authentication > Users**.
4. Create the intended administrator as an Auth user.
5. Promote that account in SQL Editor:
```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'admin@example.com');
```
6. Leave normal accounts with the default `user` role.

## 2. Local setup
```bash
cp .env.example .env.local
# Add the Supabase Project URL and publishable key
npm install
npm run dev
```
Never put a Supabase secret key or service-role key in the frontend or GitHub repository.

## 3. GitHub Pages deployment
1. Create a GitHub repository and push this project's contents to its `main` branch.
2. In **Repository Settings > Secrets and variables > Actions**, add:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
3. In **Settings > Pages**, choose **GitHub Actions** as the source.
4. Push to `main`, then check the **Actions** tab.
5. Add the final GitHub Pages URL in Supabase under **Authentication > URL Configuration > Site URL** and **Redirect URLs**.

## 4. Install on devices
- Desktop Chrome/Edge: open the deployed URL and choose **Install app**.
- Android Chrome: menu > **Add to Home screen** or **Install app**.
- iPhone/iPad Safari: Share > **Add to Home Screen**.

The reporting operation requires a connection to Supabase. The app shell may load from cache, but submissions are not queued offline.

## Security notes
- The image bucket is private.
- RLS lets authenticated users insert only records assigned to their own account.
- Only admins can list/delete reports and view/delete images.
- Role decisions are enforced in the database, not only hidden in the interface.
- Deleting a report also requests deletion of its associated image.
- Consider your organisation's retention policy, privacy assessment, support ownership and urgent-risk escalation process before production use.
- Test authorised and unauthorised accounts before rollout.

## Optional next improvements
Offline submission queue, defect status/workflow, coach location fields, image compression, audit log, export, notifications, SSO and monitoring.

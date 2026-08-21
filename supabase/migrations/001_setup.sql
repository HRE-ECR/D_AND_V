-- Run once in Supabase SQL Editor. Safe role checks and private image storage included.
create extension if not exists pgcrypto;
create type public.app_role as enum ('user','admin');
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text, role public.app_role not null default 'user', created_at timestamptz not null default now());
create table public.defects (id uuid primary key default gen_random_uuid(), train_number text not null check(train_number ~ '^[0-9]{6}$'), coach_number text not null check(coach_number ~ '^[0-9]{3}$'), description text not null check(length(trim(description))>=5), image_path text not null, reported_by uuid not null constraint defects_reported_by_fkey references public.profiles(id) on delete restrict, created_at timestamptz not null default now());
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',split_part(new.email,'@',1))); return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;
alter table public.profiles enable row level security; alter table public.defects enable row level security;
create policy "read own profile" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "users create defects" on public.defects for insert to authenticated with check(reported_by=auth.uid());
create policy "admins read defects" on public.defects for select to authenticated using(public.is_admin());
create policy "admins delete defects" on public.defects for delete to authenticated using(public.is_admin());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('defect-images','defect-images',false,10485760,array['image/jpeg','image/png','image/webp','image/heic','image/heif']) on conflict(id) do update set public=false;
create policy "users upload own defect images" on storage.objects for insert to authenticated with check(bucket_id='defect-images' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "admins read defect images" on storage.objects for select to authenticated using(bucket_id='defect-images' and public.is_admin());
create policy "admins delete defect images" on storage.objects for delete to authenticated using(bucket_id='defect-images' and public.is_admin());
-- After creating your first account, promote it manually:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR_ADMIN_EMAIL');

create policy "users delete own orphaned images" on storage.objects for delete to authenticated using(bucket_id='defect-images' and (storage.foldername(name))[1]=auth.uid()::text);

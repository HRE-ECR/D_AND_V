-- Train Defect Reporter v3 - complete, rerunnable Supabase setup
-- Run the whole file in Supabase SQL Editor.
begin;
create extension if not exists pgcrypto;
do $$ begin create type public.app_role as enum('user','admin'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text, role public.app_role not null default 'user', created_at timestamptz not null default now()
);
create table if not exists public.defects(
 id uuid primary key default gen_random_uuid(), train_number text not null check(train_number~'^[0-9]{6}$'),
 coach_number text not null check(coach_number~'^[0-9]{3}$'), description text not null constraint defects_description_not_blank check(length(trim(description))>0),
 image_path text, reported_by uuid not null constraint defects_reported_by_fkey references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now()
);
-- The old application required one image_path directly on defects. v3 moves images to a child table.
alter table public.defects alter column image_path drop not null;
-- Align existing installations with the UI rule: the description must be filled in.
alter table public.defects drop constraint if exists defects_description_check;
alter table public.defects drop constraint if exists defects_description_not_blank;
alter table public.defects add constraint defects_description_not_blank check(length(trim(description))>0);
create table if not exists public.defect_images(
 id uuid primary key default gen_random_uuid(), defect_id uuid not null references public.defects(id) on delete cascade,
 image_path text not null unique, display_order integer not null default 0 check(display_order>=0),
 uploaded_by uuid not null references public.profiles(id) on delete restrict, created_at timestamptz not null default now(),
 unique(defect_id,display_order)
);
-- Preserve image references created by the original one-photo version.
insert into public.defect_images(defect_id,image_path,display_order,uploaded_by,created_at)
select id,image_path,0,reported_by,created_at from public.defects
where image_path is not null and trim(image_path)<>''
on conflict(image_path) do nothing;
create index if not exists defects_created_idx on public.defects(created_at desc);
create index if not exists defect_images_defect_idx on public.defect_images(defect_id,display_order);

create table if not exists public.fleets(
 id uuid primary key default gen_random_uuid(), code text not null unique, name text not null unique,
 coach_numbers text[] not null check(cardinality(coach_numbers)>0), active boolean not null default true,
 created_at timestamptz not null default now()
);
insert into public.fleets(code,name,coach_numbers,active) values
 ('AZUMA','Azuma',array['829','828','827','826','825','824','823','822','821'],true)
on conflict(code) do update set name=excluded.name,coach_numbers=excluded.coach_numbers,active=excluded.active;
create table if not exists public.exams(
 id uuid primary key default gen_random_uuid(), unit_number text not null check(unit_number~'^[0-9]{6}$'),
 fleet_id uuid not null references public.fleets(id) on delete restrict,
 status text not null default 'open' check(status in('open','complete','deleted')),
 created_by uuid not null references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 deleted_at timestamptz, purge_after timestamptz, deleted_by uuid references public.profiles(id) on delete set null,
 check((deleted_at is null and purge_after is null) or(deleted_at is not null and purge_after is not null))
);
create unique index if not exists one_live_exam_per_unit on public.exams(unit_number) where deleted_at is null;
create index if not exists exams_updated_idx on public.exams(updated_at desc);
create index if not exists exams_purge_idx on public.exams(purge_after) where deleted_at is not null;
create table if not exists public.exam_defects(
 id uuid primary key default gen_random_uuid(), exam_id uuid not null references public.exams(id) on delete cascade,
 coach_number text not null check(coach_number~'^[0-9]{3}$'), description text not null check(length(trim(description))>=3),
 reported_by uuid not null constraint exam_defects_reported_by_fkey references public.profiles(id) on delete restrict,
 created_at timestamptz not null default now(), sap_booked boolean not null default false,
 sap_booked_at timestamptz, sap_booked_by uuid references public.profiles(id) on delete set null,
 check((not sap_booked and sap_booked_at is null and sap_booked_by is null) or(sap_booked and sap_booked_at is not null and sap_booked_by is not null))
);
create index if not exists exam_defects_exam_coach_idx on public.exam_defects(exam_id,coach_number,created_at);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'),''),split_part(coalesce(new.email,'staff'),'@',1))) on conflict(id) do nothing; return new; end$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
insert into public.profiles(id,full_name)
select id,coalesce(nullif(trim(raw_user_meta_data->>'full_name'),''),split_part(coalesce(email,'staff'),'@',1)) from auth.users
on conflict(id) do nothing;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin'::public.app_role)$$;
create or replace function public.validate_exam_defect() returns trigger language plpgsql set search_path=public as $$
declare coaches text[]; removed timestamptz; begin
 select f.coach_numbers,e.deleted_at into coaches,removed from public.exams e join public.fleets f on f.id=e.fleet_id where e.id=new.exam_id;
 if coaches is null then raise exception 'Exam or fleet not found'; end if;
 if removed is not null then raise exception 'Cannot add a defect to a deleted exam'; end if;
 if not(new.coach_number=any(coaches)) then raise exception 'Coach % is not configured for this fleet',new.coach_number; end if;
 return new; end$$;
drop trigger if exists validate_exam_defect_trigger on public.exam_defects;
create trigger validate_exam_defect_trigger before insert or update of exam_id,coach_number on public.exam_defects for each row execute function public.validate_exam_defect();
create or replace function public.touch_exam() returns trigger language plpgsql security definer set search_path=public as $$
declare eid uuid; begin eid:=case when tg_op='DELETE' then old.exam_id else new.exam_id end; update public.exams set updated_at=now() where id=eid; return case when tg_op='DELETE' then old else new end; end$$;
drop trigger if exists touch_exam_on_defect on public.exam_defects;
create trigger touch_exam_on_defect after insert or update or delete on public.exam_defects for each row execute function public.touch_exam();
create or replace function public.audit_sap_booking() returns trigger language plpgsql set search_path=public as $$
begin if new.sap_booked is distinct from old.sap_booked then
 if not public.is_admin() then raise exception 'Administrator access required'; end if;
 if new.sap_booked then new.sap_booked_at:=now();new.sap_booked_by:=auth.uid();else new.sap_booked_at:=null;new.sap_booked_by:=null;end if;
 end if; return new; end$$;
drop trigger if exists audit_sap_booking_trigger on public.exam_defects;
create trigger audit_sap_booking_trigger before update of sap_booked on public.exam_defects for each row execute function public.audit_sap_booking();
create or replace function public.soft_delete_exam(target_exam uuid) returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not public.is_admin() then raise exception 'Administrator access required'; end if;
 update public.exams set status='deleted',deleted_at=now(),purge_after=now()+interval '10 days',deleted_by=auth.uid(),updated_at=now() where id=target_exam and deleted_at is null;
 if not found then raise exception 'Exam not found or already deleted'; end if; end$$;
create or replace function public.restore_exam(target_exam uuid) returns void language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not public.is_admin() then raise exception 'Administrator access required'; end if;
 if exists(select 1 from public.exams d join public.exams l on l.unit_number=d.unit_number and l.deleted_at is null and l.id<>d.id where d.id=target_exam) then raise exception 'A live exam already exists for this unit'; end if;
 update public.exams set status='open',deleted_at=null,purge_after=null,deleted_by=null,updated_at=now() where id=target_exam and deleted_at is not null and purge_after>now();
 if not found then raise exception 'Deleted exam not found or retention expired'; end if; end$$;
create or replace function public.purge_expired_exams() returns integer language plpgsql security definer set search_path=public as $$
declare n integer; begin delete from public.exams where deleted_at is not null and purge_after<=now();get diagnostics n=row_count;return n;end$$;

alter table public.profiles enable row level security; alter table public.defects enable row level security;
alter table public.defect_images enable row level security; alter table public.fleets enable row level security;
alter table public.exams enable row level security; alter table public.exam_defects enable row level security;
drop policy if exists "read own profile" on public.profiles; drop policy if exists "admins read profiles" on public.profiles;
drop policy if exists "users create defects" on public.defects; drop policy if exists "admins read defects" on public.defects; drop policy if exists "admins delete defects" on public.defects; drop policy if exists "users delete failed defects" on public.defects;
drop policy if exists "users add defect images" on public.defect_images; drop policy if exists "admins read defect images rows" on public.defect_images;
drop policy if exists "authenticated read fleets" on public.fleets; drop policy if exists "admins manage fleets" on public.fleets;
drop policy if exists "users read live exams admins all" on public.exams; drop policy if exists "users create exams" on public.exams; drop policy if exists "admins update exams" on public.exams; drop policy if exists "admins delete exams" on public.exams;
drop policy if exists "users read exam defects" on public.exam_defects; drop policy if exists "users add exam defects" on public.exam_defects; drop policy if exists "admins update exam defects" on public.exam_defects; drop policy if exists "admins delete exam defects" on public.exam_defects;
create policy "read own profile" on public.profiles for select to authenticated using(id=auth.uid());
create policy "admins read profiles" on public.profiles for select to authenticated using(public.is_admin());
create policy "users create defects" on public.defects for insert to authenticated with check(reported_by=auth.uid());
create policy "admins read defects" on public.defects for select to authenticated using(public.is_admin());
create policy "admins delete defects" on public.defects for delete to authenticated using(public.is_admin());
-- Allows the reporter to roll back a failed multi-photo submission for five minutes.
create policy "users delete failed defects" on public.defects for delete to authenticated using(reported_by=auth.uid() and created_at>now()-interval '5 minutes');
create policy "users add defect images" on public.defect_images for insert to authenticated with check(uploaded_by=auth.uid() and exists(select 1 from public.defects d where d.id=defect_id and d.reported_by=auth.uid()));
create policy "admins read defect images rows" on public.defect_images for select to authenticated using(public.is_admin());
create policy "authenticated read fleets" on public.fleets for select to authenticated using(active or public.is_admin());
create policy "admins manage fleets" on public.fleets for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "users read live exams admins all" on public.exams for select to authenticated using(deleted_at is null or public.is_admin());
create policy "users create exams" on public.exams for insert to authenticated with check(created_by=auth.uid() and deleted_at is null and status='open' and exists(select 1 from public.fleets f where f.id=fleet_id and f.active));
create policy "admins update exams" on public.exams for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete exams" on public.exams for delete to authenticated using(public.is_admin());
create policy "users read exam defects" on public.exam_defects for select to authenticated using(exists(select 1 from public.exams e where e.id=exam_id and(e.deleted_at is null or public.is_admin())));
create policy "users add exam defects" on public.exam_defects for insert to authenticated with check(reported_by=auth.uid() and not sap_booked and exists(select 1 from public.exams e where e.id=exam_id and e.deleted_at is null));
create policy "admins update exam defects" on public.exam_defects for update to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins delete exam defects" on public.exam_defects for delete to authenticated using(public.is_admin());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('defect-images','defect-images',false,10485760,array['image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "users upload own defect images" on storage.objects; drop policy if exists "admins read defect images" on storage.objects;
drop policy if exists "admins delete defect images" on storage.objects; drop policy if exists "users delete own orphaned images" on storage.objects;
create policy "users upload own defect images" on storage.objects for insert to authenticated with check(bucket_id='defect-images' and(storage.foldername(name))[1]=auth.uid()::text);
create policy "admins read defect images" on storage.objects for select to authenticated using(bucket_id='defect-images' and public.is_admin());
create policy "admins delete defect images" on storage.objects for delete to authenticated using(bucket_id='defect-images' and public.is_admin());
create policy "users delete own orphaned images" on storage.objects for delete to authenticated using(bucket_id='defect-images' and(storage.foldername(name))[1]=auth.uid()::text);
revoke all on function public.is_admin() from public; grant execute on function public.is_admin() to authenticated;
revoke all on function public.soft_delete_exam(uuid) from public; grant execute on function public.soft_delete_exam(uuid) to authenticated;
revoke all on function public.restore_exam(uuid) from public; grant execute on function public.restore_exam(uuid) to authenticated;
revoke all on function public.purge_expired_exams() from public,anon,authenticated;
commit;
-- Promote an admin separately:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='admin@example.com');
-- Schedule daily as a trusted Supabase Cron job: select public.purge_expired_exams();

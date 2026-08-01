-- Public profile and motorcycle images with owner-only write access.
-- Public buckets are intentional because these images appear in rider profiles,
-- garages, and the social feed. Only the authenticated owner may manage files
-- below their own top-level user-id folder.

alter table public.profiles
  add column if not exists avatar_path text;

alter table public.motorcycles
  add column if not exists photo_path text;

grant update (avatar_path) on table public.profiles to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values
  (
    'profile-images',
    'profile-images',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'motorcycle-images',
    'motorcycle-images',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can read their own MotoMap images"
  on storage.objects;
drop policy if exists "Users can upload their own MotoMap images"
  on storage.objects;
drop policy if exists "Users can update their own MotoMap images"
  on storage.objects;
drop policy if exists "Users can delete their own MotoMap images"
  on storage.objects;

create policy "Users can read their own MotoMap images"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id in ('profile-images', 'motorcycle-images')
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and owner_id = (select auth.uid()::text)
  );

create policy "Users can upload their own MotoMap images"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id in ('profile-images', 'motorcycle-images')
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "Users can update their own MotoMap images"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id in ('profile-images', 'motorcycle-images')
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and owner_id = (select auth.uid()::text)
  )
  with check (
    bucket_id in ('profile-images', 'motorcycle-images')
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and owner_id = (select auth.uid()::text)
  );

create policy "Users can delete their own MotoMap images"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id in ('profile-images', 'motorcycle-images')
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and owner_id = (select auth.uid()::text)
  );

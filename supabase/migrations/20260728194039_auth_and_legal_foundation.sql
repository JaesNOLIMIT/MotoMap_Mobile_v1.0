-- MotoMap authentication and legal-consent foundation.
-- Email/password credentials remain exclusively in Supabase Auth.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  first_name text not null,
  last_name text not null,
  username text not null,
  phone_number text not null,
  birth_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_first_name_valid
    check (char_length(btrim(first_name)) between 1 and 80),
  constraint profiles_last_name_valid
    check (char_length(btrim(last_name)) between 1 and 80),
  constraint profiles_username_valid
    check (
      username = lower(username)
      and username ~ '^[a-z0-9][a-z0-9_.]{3,13}[a-z0-9]$'
    ),
  constraint profiles_phone_number_e164
    check (phone_number ~ '^\+[1-9][0-9]{7,14}$')
);

create unique index profiles_username_unique_ci
  on public.profiles (lower(username));
create unique index profiles_phone_number_unique
  on public.profiles (phone_number);

create table public.legal_documents (
  document_id bigint generated always as identity primary key,
  document_type text not null,
  version text not null,
  title text not null,
  content text not null,
  effective_at timestamptz not null,
  superseded_at timestamptz,
  created_at timestamptz not null default now(),
  constraint legal_documents_type_valid
    check (document_type in ('eula', 'terms', 'privacy')),
  constraint legal_documents_version_present
    check (char_length(btrim(version)) between 1 and 40),
  constraint legal_documents_title_present
    check (char_length(btrim(title)) between 1 and 120),
  constraint legal_documents_content_present
    check (char_length(btrim(content)) > 0),
  constraint legal_documents_superseded_after_effective
    check (superseded_at is null or superseded_at > effective_at),
  unique (document_type, version)
);

create unique index legal_documents_one_current_per_type
  on public.legal_documents (document_type)
  where superseded_at is null;

create table public.user_legal_acceptances (
  user_id uuid not null references auth.users (id) on delete cascade,
  document_id bigint not null
    references public.legal_documents (document_id) on delete restrict,
  accepted_at timestamptz not null default now(),
  primary key (user_id, document_id)
);

create index user_legal_acceptances_document_id_idx
  on public.user_legal_acceptances (document_id);

create table private.email_availability_rate_limits (
  client_key text primary key,
  window_started_at timestamptz not null,
  request_count integer not null,
  constraint email_availability_request_count_positive
    check (request_count > 0)
);

alter table public.profiles enable row level security;
alter table public.legal_documents enable row level security;
alter table public.user_legal_acceptances enable row level security;

revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.legal_documents from public, anon, authenticated;
revoke all on table public.user_legal_acceptances
  from public, anon, authenticated;

grant select on table public.profiles to authenticated;
grant update (
  first_name,
  last_name,
  username,
  phone_number,
  birth_date
) on table public.profiles to authenticated;

grant select on table public.legal_documents to anon, authenticated;
grant select on table public.user_legal_acceptances to authenticated;
grant insert (user_id, document_id)
  on table public.user_legal_acceptances to authenticated;

create policy "Users can read their own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Anyone can read current legal documents"
  on public.legal_documents
  for select
  to anon, authenticated
  using (
    effective_at <= now()
    and superseded_at is null
  );

create policy "Users can read their own legal acceptances"
  on public.user_legal_acceptances
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can accept current legal documents"
  on public.user_legal_acceptances
  for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.legal_documents as document
      where document.document_id = user_legal_acceptances.document_id
        and document.effective_at <= now()
        and document.superseded_at is null
    )
  );

create or replace function private.set_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_profile_updated_at();

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  active_document_count integer;
  accepted_document_count integer;
  parsed_birth_date date;
begin
  if coalesce(btrim(metadata ->> 'first_name'), '') = ''
    or coalesce(btrim(metadata ->> 'last_name'), '') = ''
    or coalesce(btrim(metadata ->> 'username'), '') = ''
    or coalesce(btrim(metadata ->> 'phone_number'), '') = ''
    or coalesce(btrim(metadata ->> 'birth_date'), '') = ''
  then
    raise exception using
      errcode = '23514',
      message = 'Required registration profile data is missing';
  end if;

  begin
    parsed_birth_date := (metadata ->> 'birth_date')::date;
  exception when others then
    raise exception using
      errcode = '22007',
      message = 'Birth date is invalid';
  end;

  if parsed_birth_date >= current_date then
    raise exception using
      errcode = '23514',
      message = 'Birth date must be in the past';
  end if;

  select count(*)
  into active_document_count
  from public.legal_documents
  where effective_at <= now()
    and superseded_at is null;

  select count(*)
  into accepted_document_count
  from public.legal_documents as document
  where document.effective_at <= now()
    and document.superseded_at is null
    and metadata -> 'legal_document_versions'
      ->> document.document_type = document.version;

  if active_document_count <> 3
    or accepted_document_count <> active_document_count
  then
    raise exception using
      errcode = '23514',
      message = 'Current EULA, Terms, and Privacy Policy must be accepted';
  end if;

  insert into public.profiles (
    user_id,
    first_name,
    last_name,
    username,
    phone_number,
    birth_date
  )
  values (
    new.id,
    btrim(metadata ->> 'first_name'),
    btrim(metadata ->> 'last_name'),
    lower(btrim(metadata ->> 'username')),
    btrim(metadata ->> 'phone_number'),
    parsed_birth_date
  );

  insert into public.user_legal_acceptances (user_id, document_id)
  select new.id, document.document_id
  from public.legal_documents as document
  where document.effective_at <= now()
    and document.superseded_at is null;

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

create or replace function public.is_email_available(p_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_email is not null
    and p_email ~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    and not exists (
      select 1
      from auth.users
      where lower(email) = lower(btrim(p_email))
        and deleted_at is null
    );
$$;

create or replace function public.consume_email_availability_quota(
  p_client_key text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed boolean;
  current_time timestamptz := clock_timestamp();
begin
  if p_client_key is null or char_length(p_client_key) <> 64 then
    return false;
  end if;

  insert into private.email_availability_rate_limits (
    client_key,
    window_started_at,
    request_count
  )
  values (p_client_key, current_time, 1)
  on conflict (client_key) do update
  set
    window_started_at = case
      when private.email_availability_rate_limits.window_started_at
        <= current_time - interval '10 minutes'
      then current_time
      else private.email_availability_rate_limits.window_started_at
    end,
    request_count = case
      when private.email_availability_rate_limits.window_started_at
        <= current_time - interval '10 minutes'
      then 1
      else private.email_availability_rate_limits.request_count + 1
    end
  returning request_count <= 20 into allowed;

  return allowed;
end;
$$;

revoke all on function public.is_email_available(text)
  from public, anon, authenticated;
revoke all on function public.consume_email_availability_quota(text)
  from public, anon, authenticated;
grant execute on function public.is_email_available(text) to service_role;
grant execute on function public.consume_email_availability_quota(text)
  to service_role;

insert into public.legal_documents (
  document_type,
  version,
  title,
  content,
  effective_at
)
values
(
  'eula',
  '1.0-draft',
  'End-User License Agreement',
  $document$
DRAFT TEMPLATE — REPLACE WITH LAWYER-APPROVED TEXT BEFORE RELEASE

1. License
MotoMap grants you a limited, personal, non-exclusive, non-transferable, revocable license to install and use the MotoMap application for lawful personal motorcycle navigation, ride tracking, and diagnostic-information purposes.

2. Ownership
MotoMap and its licensors retain all rights in the application, software, designs, trademarks, and related materials. This agreement does not transfer ownership to you.

3. Acceptable use
You must not reverse engineer the application where prohibited by law, bypass security controls, interfere with the service, use the application unlawfully, or use diagnostic features while operating a vehicle in an unsafe manner.

4. Motorcycle diagnostics
Diagnostic readings may be incomplete, delayed, unsupported, or affected by the motorcycle, ECU, adapter, wiring, and environment. MotoMap does not replace a qualified technician, manufacturer service information, or safe inspection practices.

5. Updates and termination
MotoMap may provide updates or discontinue features. This license ends if you materially violate this agreement. Upon termination, you must stop using the application.

6. Disclaimer
The application is provided on an “as available” basis to the extent permitted by law. No diagnostic result guarantees that a motorcycle is safe or free of faults.

7. Contact
Replace this section with the operator’s legal name, postal address, and support email before release.
$document$,
  '2026-07-29 00:00:00+08'
),
(
  'terms',
  '1.0-draft',
  'Terms of Service',
  $document$
DRAFT TEMPLATE — REPLACE WITH LAWYER-APPROVED TEXT BEFORE RELEASE

1. Agreement
By creating a MotoMap account or using the service, you agree to these Terms, the EULA, and the Privacy Policy.

2. Account responsibilities
You must provide accurate registration information, protect your password and devices, and notify MotoMap of suspected unauthorized access. You are responsible for activity performed through your account unless applicable law provides otherwise.

3. Eligibility and lawful use
You may use MotoMap only when legally permitted to do so. Do not interact with the application while riding when doing so would be unsafe or illegal.

4. User content and ride information
You retain ownership of content you submit. You grant MotoMap the limited rights required to store, process, display, and transmit that content to provide features you request.

5. Maps, routes, and diagnostics
Routes, traffic, road conditions, location information, and motorcycle diagnostic readings can be inaccurate or unavailable. Always follow traffic laws, road signs, manufacturer instructions, and professional mechanical advice.

6. Suspension and termination
MotoMap may restrict or terminate accounts used for abuse, unlawful conduct, security attacks, or material violations of these Terms.

7. Liability
To the maximum extent permitted by applicable law, MotoMap is not responsible for indirect or consequential loss arising from reliance on routing or diagnostic information.

8. Changes
Material revisions will be published as a new version and, where required, presented for renewed acceptance.

9. Governing law and contact
Replace this section with the operator’s legal entity, governing law, dispute process, address, and support email before release.
$document$,
  '2026-07-29 00:00:00+08'
),
(
  'privacy',
  '1.0-draft',
  'Privacy Policy',
  $document$
DRAFT TEMPLATE — REPLACE WITH LAWYER-APPROVED TEXT BEFORE RELEASE

1. Information collected
MotoMap may collect account information such as your name, username, email address, phone number, and birth date. Features may later collect motorcycle, diagnostic, location, route, device, and support information when enabled.

2. Purposes
Information is used to create and secure accounts, provide requested features, maintain legal-consent records, prevent abuse, troubleshoot problems, and improve reliability.

3. Legal basis and consent
The applicable legal basis depends on your location and may include performance of a contract, legitimate interests, legal obligations, and consent. Accepting this policy does not replace separate consent where the law requires it.

4. Sharing
Information may be processed by hosting, authentication, email, mapping, analytics, and support providers acting for MotoMap. MotoMap does not sell personal information unless this statement is replaced with an accurate disclosure.

5. Retention and security
Information is retained only as long as reasonably required for the stated purposes, legal obligations, dispute resolution, and security. Reasonable safeguards are used, but no system is completely secure.

6. Your choices and rights
Depending on applicable law, you may request access, correction, deletion, restriction, portability, or objection. Some records may need to be retained to meet legal obligations.

7. Children
Replace this section with the product’s final minimum-age rule and jurisdiction-specific child privacy provisions.

8. International processing
Information may be processed in countries other than your own. Appropriate safeguards will be used where required.

9. Contact
Replace this section with the privacy contact, operator identity, address, and regulator complaint information before release.
$document$,
  '2026-07-29 00:00:00+08'
);

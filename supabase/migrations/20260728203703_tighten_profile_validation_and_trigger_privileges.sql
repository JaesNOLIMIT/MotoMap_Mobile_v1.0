create or replace function private.set_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.birth_date >= current_date then
    raise exception using
      errcode = '23514',
      message = 'Birth date must be in the past';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.set_profile_updated_at()
  from public, anon, authenticated;
revoke all on function private.handle_new_auth_user()
  from public, anon, authenticated;

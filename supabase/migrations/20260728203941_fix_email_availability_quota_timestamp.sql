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
  request_time timestamptz := clock_timestamp();
begin
  if p_client_key is null or char_length(p_client_key) <> 64 then
    return false;
  end if;

  insert into private.email_availability_rate_limits (
    client_key,
    window_started_at,
    request_count
  )
  values (p_client_key, request_time, 1)
  on conflict (client_key) do update
  set
    window_started_at = case
      when private.email_availability_rate_limits.window_started_at
        <= request_time - interval '10 minutes'
      then request_time
      else private.email_availability_rate_limits.window_started_at
    end,
    request_count = case
      when private.email_availability_rate_limits.window_started_at
        <= request_time - interval '10 minutes'
      then 1
      else private.email_availability_rate_limits.request_count + 1
    end
  returning request_count <= 20 into allowed;

  return allowed;
end;
$$;

revoke all on function public.consume_email_availability_quota(text)
  from public, anon, authenticated;
grant execute on function public.consume_email_availability_quota(text)
  to service_role;

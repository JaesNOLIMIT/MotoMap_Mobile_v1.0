-- INSERT ... ON CONFLICT DO UPDATE pre-checks SELECT visibility for the
-- prospective membership row. Split leader membership creation and update so
-- the first insert can establish the visibility that member SELECT requires.

create or replace function public.create_shared_ride(
  p_route_plan_id uuid,
  p_motorcycle_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  rider_id uuid := auth.uid();
  target_id uuid;
begin
  if rider_id is null then
    raise exception 'Sign in before creating a shared ride.' using errcode = '42501';
  end if;
  if not private.owns_route_plan(p_route_plan_id) then
    raise exception 'Choose one of your saved rides.' using errcode = '42501';
  end if;
  if p_motorcycle_id is not null and not exists (
    select 1 from public.motorcycles bike
    where bike.motorcycle_id = p_motorcycle_id and bike.user_id = rider_id
  ) then
    raise exception 'Choose one of your motorcycles.' using errcode = '42501';
  end if;

  insert into public.shared_rides (route_plan_id, leader_id, join_code)
  values (p_route_plan_id, rider_id, '')
  on conflict (route_plan_id) do update set updated_at = clock_timestamp()
  returning shared_ride_id into target_id;

  begin
    insert into public.shared_ride_members (
      shared_ride_id, user_id, motorcycle_id, role, status, rider_name
    ) values (
      target_id, rider_id, p_motorcycle_id, 'leader', 'joined', 'Rider'
    );
  exception when unique_violation then
    update public.shared_ride_members
    set motorcycle_id = p_motorcycle_id, status = 'joined'
    where shared_ride_id = target_id and user_id = rider_id;
  end;
  return target_id;
end;
$$;

revoke all on function public.create_shared_ride(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.create_shared_ride(uuid, uuid)
  to authenticated;

-- Avoid route_plans -> shared_rides -> route_plans policy recursion while
-- retaining an auth.uid()-scoped ownership check for group creation.

create or replace function private.owns_route_plan(p_route_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.route_plans route
    where route.route_plan_id = p_route_plan_id
      and route.user_id = (select auth.uid())
  );
$$;

revoke all on function private.owns_route_plan(uuid)
  from public, anon, authenticated;
grant execute on function private.owns_route_plan(uuid) to authenticated;

drop policy if exists "Leaders can create shared rides"
  on public.shared_rides;
create policy "Leaders can create shared rides"
on public.shared_rides for insert to authenticated
with check (
  leader_id = (select auth.uid())
  and private.owns_route_plan(route_plan_id)
);

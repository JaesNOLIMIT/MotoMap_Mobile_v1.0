-- Group creation needs no RLS bypass: the leader already owns the route and
-- both INSERT policies validate auth.uid(). Only code-based joining retains a
-- narrowly validated SECURITY DEFINER RPC so codes are never listable.

alter function public.create_shared_ride(uuid, uuid) security invoker;

drop policy if exists "Members can read their shared rides"
  on public.shared_rides;
create policy "Leaders and members can read their shared rides"
on public.shared_rides for select to authenticated
using (
  leader_id = (select auth.uid())
  or private.is_shared_ride_member(shared_ride_id)
);

drop policy if exists "Users can read their own route plans"
  on public.route_plans;
drop policy if exists "Group members can read the shared route plan"
  on public.route_plans;
create policy "Owners and group members can read route plans"
on public.route_plans for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1 from public.shared_rides shared
    where shared.route_plan_id = route_plans.route_plan_id
      and private.is_shared_ride_member(shared.shared_ride_id)
  )
);

-- Preserve useful ELM327 history recorded before compact session summaries
-- existed. Distance is integrated only across adjacent speed samples no more
-- than 30 seconds apart. Historical fuel consumption remains null because the
-- fuel-rate PID was not stored by older app versions.

with ordered_samples as (
  select
    sample.*,
    lag(sample.recorded_at) over session_samples as previous_recorded_at,
    lag(sample.vehicle_speed_kph) over session_samples as previous_speed_kph
  from public.diagnostic_samples as sample
  window session_samples as (
    partition by sample.diagnostic_session_id
    order by sample.recorded_at, sample.diagnostic_sample_id
  )
),
sample_summaries as (
  select
    sample.diagnostic_session_id,
    count(*)::integer as sample_count,
    avg(sample.vehicle_speed_kph) as average_speed_kph,
    max(sample.vehicle_speed_kph) as maximum_speed_kph,
    avg(sample.engine_rpm) as average_engine_rpm,
    max(sample.engine_rpm) as maximum_engine_rpm,
    max(sample.coolant_temperature_c) as maximum_coolant_temperature_c,
    min(sample.control_module_voltage) as minimum_control_module_voltage,
    (
      array_agg(
        sample.fuel_level_percent
        order by sample.recorded_at desc, sample.diagnostic_sample_id desc
      ) filter (where sample.fuel_level_percent is not null)
    )[1] as ending_fuel_level_percent,
    count(*) filter (
      where sample.vehicle_speed_kph is not null
        and sample.previous_speed_kph is not null
        and extract(
          epoch from sample.recorded_at - sample.previous_recorded_at
        ) > 0
        and extract(
          epoch from sample.recorded_at - sample.previous_recorded_at
        ) <= 30
    ) as distance_interval_count,
    sum(
      case
        when sample.vehicle_speed_kph is not null
          and sample.previous_speed_kph is not null
          and extract(
            epoch from sample.recorded_at - sample.previous_recorded_at
          ) > 0
          and extract(
            epoch from sample.recorded_at - sample.previous_recorded_at
          ) <= 30
        then (
          (sample.vehicle_speed_kph + sample.previous_speed_kph) / 2
          * extract(
            epoch from sample.recorded_at - sample.previous_recorded_at
          )
          / 3600
        )
        else 0
      end
    ) as distance_km
  from ordered_samples as sample
  group by sample.diagnostic_session_id
)
update public.diagnostic_sessions as session
set
  sample_count = greatest(session.sample_count, summary.sample_count),
  average_speed_kph = coalesce(
    session.average_speed_kph,
    summary.average_speed_kph
  ),
  maximum_speed_kph = coalesce(
    session.maximum_speed_kph,
    summary.maximum_speed_kph
  ),
  average_engine_rpm = coalesce(
    session.average_engine_rpm,
    summary.average_engine_rpm
  ),
  maximum_engine_rpm = coalesce(
    session.maximum_engine_rpm,
    summary.maximum_engine_rpm
  ),
  maximum_coolant_temperature_c = coalesce(
    session.maximum_coolant_temperature_c,
    summary.maximum_coolant_temperature_c
  ),
  minimum_control_module_voltage = coalesce(
    session.minimum_control_module_voltage,
    summary.minimum_control_module_voltage
  ),
  ending_fuel_level_percent = coalesce(
    session.ending_fuel_level_percent,
    summary.ending_fuel_level_percent
  ),
  distance_km = case
    when session.distance_km is not null then session.distance_km
    when session.session_type = 'ride'
      and summary.distance_interval_count > 0
    then summary.distance_km
    else null
  end
from sample_summaries as summary
where summary.diagnostic_session_id = session.diagnostic_session_id;

with trouble_code_summaries as (
  select
    code.diagnostic_session_id,
    count(distinct code.code) filter (
      where code.status <> 'cleared'
    )::smallint as trouble_code_count,
    coalesce(
      array_agg(distinct code.code order by code.code) filter (
        where code.status <> 'cleared'
      ),
      '{}'::text[]
    ) as trouble_codes
  from public.diagnostic_trouble_codes as code
  group by code.diagnostic_session_id
)
update public.diagnostic_sessions as session
set
  trouble_code_count = summary.trouble_code_count,
  trouble_codes = summary.trouble_codes
from trouble_code_summaries as summary
where summary.diagnostic_session_id = session.diagnostic_session_id
  and session.trouble_code_count = 0
  and cardinality(session.trouble_codes) = 0;

CREATE SCHEMA IF NOT EXISTS stg;

-- One row per race
CREATE OR REPLACE VIEW stg.race AS
SELECT
  session_key::int                         AS session_key,
  meeting_key::int                         AS meeting_key,
  year::int                                AS season,
  circuit_short_name,
  country_name,
  location,
  gmt_offset,
  date_start::timestamptz                  AS race_start_utc,
  (date_start::timestamptz)::date          AS race_date_utc,
  row_number() OVER (PARTITION BY year ORDER BY date_start::timestamptz) AS round_seq
FROM raw.sessions;

-- Who was in which car, per race
CREATE OR REPLACE VIEW stg.driver_entry AS
SELECT
  session_key::int                         AS session_key,
  driver_number::numeric::int              AS driver_number,
  name_acronym                             AS driver_code,
  full_name,
  team_name,
  team_colour,
  country_code
FROM raw.drivers;

CREATE OR REPLACE VIEW stg.lap AS
SELECT
  session_key::int                         AS session_key,
  driver_number::numeric::int              AS driver_number,
  lap_number::numeric::int                 AS lap_number,
  date_start::timestamptz                  AS lap_start_utc,
  lap_duration::numeric                    AS lap_time_s,
  duration_sector_1::numeric               AS sector1_s,
  duration_sector_2::numeric               AS sector2_s,
  duration_sector_3::numeric               AS sector3_s,
  i1_speed::numeric::int                   AS speed_i1_kmh,
  i2_speed::numeric::int                   AS speed_i2_kmh,
  st_speed::numeric::int                   AS speed_trap_kmh,
  is_pit_out_lap::boolean                  AS is_pit_out_lap
FROM raw.laps;

CREATE OR REPLACE VIEW stg.stint AS
SELECT
  session_key::int                         AS session_key,
  driver_number::numeric::int              AS driver_number,
  stint_number::numeric::int               AS stint_number,
  compound,
  lap_start::numeric::int                  AS lap_start,
  lap_end::numeric::int                    AS lap_end,
  tyre_age_at_start::numeric::int          AS tyre_age_at_start
FROM raw.stints;

CREATE OR REPLACE VIEW stg.pit_stop AS
SELECT
  session_key::int                         AS session_key,
  driver_number::numeric::int              AS driver_number,
  lap_number::numeric::int                 AS lap_number,
  date::timestamptz                        AS pit_time_utc,
  pit_duration::numeric                    AS pit_duration_s,
  lane_duration::numeric                   AS lane_duration_s,
  stop_duration::numeric                   AS stop_duration_s
FROM raw.pit;

CREATE OR REPLACE VIEW stg.race_control AS
SELECT
  session_key::int                         AS session_key,
  date::timestamptz                        AS event_time_utc,
  driver_number::numeric::int              AS driver_number,
  lap_number::numeric::int                 AS lap_number,
  category, flag, scope, sector, message
FROM raw.race_control;
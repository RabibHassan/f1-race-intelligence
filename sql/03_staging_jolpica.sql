-- Helper: '1:23.226' -> 83.226 seconds
CREATE OR REPLACE FUNCTION stg.laptime_to_s(t text)
RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN t IS NULL OR t = '' THEN NULL
    WHEN t LIKE '%:%' THEN split_part(t, ':', 1)::numeric * 60 + split_part(t, ':', 2)::numeric
    ELSE t::numeric
  END
$$;

CREATE OR REPLACE VIEW stg.jolpica_result AS
SELECT
  season::int                                   AS season,
  round::int                                    AS round,
  race_name,
  race_date::date                               AS race_date,
  circuit_id,
  "number"::numeric::int                        AS car_number,
  "position"::numeric::int                      AS finish_position,
  "positionText"                                AS position_text,
  points::numeric                               AS points,
  grid::numeric::int                            AS grid_position,
  laps::numeric::int                            AS laps_completed,
  status,
  "Driver_driverId"                             AS jolpica_driver_id,
  "Driver_code"                                 AS driver_code,
  "Driver_givenName"                            AS given_name,
  "Driver_familyName"                           AS family_name,
  "Driver_dateOfBirth"::date                    AS date_of_birth,
  "Driver_nationality"                          AS nationality,
  "Constructor_constructorId"                   AS constructor_id,
  "Constructor_name"                            AS constructor_name,
  "Time_millis"::numeric::bigint                AS race_time_ms,
  "FastestLap_rank"::numeric::int               AS fastest_lap_rank,
  "FastestLap_lap"::numeric::int                AS fastest_lap_number,
  stg.laptime_to_s("FastestLap_Time_time")      AS fastest_lap_s,
  "FastestLap_AverageSpeed_speed"::numeric      AS fastest_lap_avg_kph
FROM raw.jolpica_results;

CREATE OR REPLACE VIEW stg.jolpica_qualifying AS
SELECT
  season::int                                   AS season,
  round::int                                    AS round,
  race_date::date                               AS race_date,
  "number"::numeric::int                        AS car_number,
  "position"::numeric::int                      AS quali_position,
  "Driver_code"                                 AS driver_code,
  "Constructor_name"                            AS constructor_name,
  stg.laptime_to_s("Q1")                        AS q1_s,
  stg.laptime_to_s("Q2")                        AS q2_s,
  stg.laptime_to_s("Q3")                        AS q3_s
FROM raw.jolpica_qualifying;
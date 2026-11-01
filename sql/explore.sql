-- Laps per driver per race, with the retirements standing out
SELECT r.season, r.circuit_short_name, d.driver_code,
       count(*) AS laps, count(*) FILTER (WHERE l.lap_time_s IS NULL) AS null_laps
FROM stg.lap l
JOIN stg.race r          ON r.session_key = l.session_key
JOIN stg.driver_entry d  ON d.session_key = l.session_key AND d.driver_number = l.driver_number
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
LIMIT 50;

-- Median lap time by lap number (see the lap 1 and pit-lap effect yourself)
SELECT lap_number,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY lap_time_s) AS median_s
FROM stg.lap
GROUP BY lap_number
ORDER BY lap_number
LIMIT 20;

-- Which compounds exist, and how many stints of each?
SELECT compound, count(*) FROM stg.stint GROUP BY 1 ORDER BY 2 DESC;
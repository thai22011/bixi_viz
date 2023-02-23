-- Check each table to understand the data
SELECT * FROM stations;
SELECT * FROM trips;

########### Q1. Gain an overall view of the volume of usage of Bixi Bikes and what factors influence it
-- 1.1, 1.2 Total number of trips of the year of 2016 and 2017
SELECT YEAR(end_date), count(*)
FROM trips
GROUP BY YEAR(end_date);

-- 1.3, 1.4 Total number of trips of the year of 2016 and 2017 by month
SELECT YEAR(end_date), MONTH(end_date), count(*)
FROM trips
GROUP BY YEAR(end_date), MONTH(end_date);

-- 1.5, 1.6 Average number of trips a day for each year-month combination in the dataset
DROP TABLE IF exists working_table1;
CREATE TABLE working_table1 AS
SELECT YEAR(end_date), MONTH(end_date), count(*) as total_trip, count(DISTINCT DAY(end_date)) as total_rental_days, ROUND(count(*)/(count(DISTINCT DAY(end_date))),0) as avg_trips_daily
FROM trips
GROUP BY YEAR(end_date), month(end_date)
ORDER BY YEAR(end_date);

-- Check if working_table1 is correct
SELECT * FROM working_table1;

############# Q2. Investigate membership status: Differences in behaviors between member and non-member
-- 2.1 The total number of trips in the year 2017 broken down by membership status (member/non-member)
SELECT YEAR(end_date), is_member, count(*)
FROM trips
WHERE YEAR(end_date) = 2017
GROUP BY is_member ;

-- 2.2 The percentage of total trips by members for the year 2017 broken down by month
-- Reference to PARTITION BY method to calculate trips member percentage by month
-- https://stackoverflow.com/questions/6207224/calculating-percentages-with-group-by-query
SELECT 	YEAR(end_date), MONTH(end_date), is_member, count(*) as trips_member, 
		ROUND(100*count(*) / SUM(count(*)) OVER (PARTITION BY MONTH(end_date)),0) as trips_member_perc_bymonth
FROM trips
WHERE YEAR(end_date) = 2017 
GROUP BY MONTH(end_date), is_member
ORDER BY MONTH(end_date);

############# Q3. Understand the rental rate throughout the months and suggest strategies for non-member conversion
-- 3.1 At which time(s) of the year is the demand for Bixi bikes at its peak? ANSWER: JUNE, JULY, AUG, SEPT in both 2016 and 2017, PEAK in JULY.2016 and JULY.2017 or SUMMER Months
SELECT YEAR(end_date), MONTH(end_date), count(*)
FROM trips
GROUP BY YEAR(end_date), MONTH(end_date)
ORDER BY count(*) DESC;

-- 3.2 Investigate the Peak demand for Bixi bikes by non-members and Suggest a special promotion to convert non-members to members
--  ANSWER: Non-member rentals also peak in the summer months, between June-Sept, peaking in July. 
-- The membership fee and rate were based on the 2022 rate at https://bixi.com/en/pricing to suggest a special promotion for non-member
-- The special promotions for non-member is that between July 1-July 31, any new member sign-up will have a one-time 30% off on the monthly membership, and 50% off if signing up for the seasonal membership
-- Targetting July because it was the peak demand for non-member rental rate and will have the most conversion.
-- The 30% off on monthly membership is the decoy to lure consumers to choose the seasonal membership (seasonal membership covers from APR-NOV, but the special promotion is starting from JUL, explaning for the 50% discount)
SELECT YEAR(end_date), MONTH(end_date), is_member, count(*)
FROM trips
WHERE is_member = 0
GROUP BY YEAR(end_date), MONTH(end_date)
ORDER BY count(*) DESC;

############# Q4. Investigate station popularity using query and subquery
-- 4.1 The 5 most popular starting stations (no query)
-- Duration/fetch time = 4.406 sec/ 0.000 sec
SELECT s.name, count(*)
FROM stations as s
INNER JOIN trips as t
	ON  t.start_station_code = s.code
GROUP BY s.name
ORDER BY count(*) DESC
LIMIT 5;

-- 4.2 The 5 most popular starting stations (no query)
-- Duration/fetch time = 1.843 sec/ 0.000 sec
-- Shorter time because the subquery found the counts of the top 5 start_station using id in trips then inner join with stations, which took less time
-- In 4.1 the query would match the name from stations to all trips then do count which took more time
SELECT *
FROM stations
INNER JOIN (
	SELECT trips.start_station_code, count(*)  FROM trips GROUP BY start_station_code ORDER BY count(*) DESC LIMIT 5) as trips
	ON  start_station_code = stations.code
GROUP BY stations.name;

############# Q5. 
-- 5.1 How is the number of starts and ends distributed for the station Mackay / de Maisonneuve throughout the day?
SELECT stations.name, trips.start_station_code, trips.start_date, trips.end_date, trips.duration_sec, 
CASE WHEN HOUR(start_date) BETWEEN 7 AND 11 THEN "morning"
		WHEN HOUR(start_date) BETWEEN 12 AND 16 THEN "afternoon"
		WHEN HOUR(start_date) BETWEEN 17 AND 21 THEN "evening"
		ELSE "night"
END AS "Start_Station_time_of_day", 
count(*)
FROM trips
INNER JOIN stations ON stations.code = trips.start_station_code
WHERE stations.name LIKE '%Mackay%'
GROUP BY start_station_time_of_day;

-- 5.2 Explain and interpret your results from above. 
-- Why do you think these patterns in Bixi usage occur for this station? 
-- Put forth a hypothesis and justify your rationale.
-- The rental location is at the intersection of Mackay St. and de Maisonneuve st. This is a major intersection in the Ville-Marie neighborhood where Concordia University is located
-- University student usually finish school in the afternoon and evening, they will rent the bike to go around the campus or hangout

############# Q6. List all stations for which at least 10% of trips are round trips. 
## Round trips are those that start and end in the same station. 
## This time we will only consider stations with at least 500 starting trips. 
## (Please include answers for all steps outlined here)

-- 6.1 First, write a query that counts the number of starting trips per station.
SELECT start_station_code, count(*) as no_starting_trip_per_station
FROM trips
GROUP BY start_station_code
ORDER BY count(*) DESC;

-- 6.2 Second, write a query that counts, for each station, the number of round trips.
SELECT start_station_code, end_station_code, count(*) as no_round_trips
FROM trips
WHERE start_station_code = end_station_code
GROUP BY start_station_code, end_station_code
ORDER BY count(*) DESC;

-- 6.3 Combine the above queries and calculate the fraction of round trips to the total number of starting trips for each station.
SELECT start_trip1.start_station_code as station_code, round_trip1.no_round_trips, start_trip1.no_starting_trip_per_station, round_trip1.no_round_trips/start_trip1.no_starting_trip_per_station as fraction
FROM ( 
	SELECT start_station_code, count(*) as no_starting_trip_per_station
	FROM trips
	GROUP BY start_station_code) as start_trip1
INNER JOIN (
	SELECT start_station_code, end_station_code, count(*) as no_round_trips
	FROM trips
	WHERE start_station_code = end_station_code
	GROUP BY start_station_code, end_station_code
	ORDER BY count(*) DESC) AS round_trip1
ON start_trip1.start_station_code = round_trip1.start_station_code
ORDER BY fraction DESC
LIMIT 5;

-- 6.4 Filter down to stations with at least 500 trips originating from them and having at least 10% of their trips as round trips.
SELECT start_trip1.start_station_code as station_code, round_trip1.no_round_trips, start_trip1.no_starting_trip_per_station, round_trip1.no_round_trips/start_trip1.no_starting_trip_per_station as fraction
FROM ( 
	SELECT start_station_code, count(*) as no_starting_trip_per_station
	FROM trips
	GROUP BY start_station_code) as start_trip1
INNER JOIN (
	SELECT start_station_code, end_station_code, count(*) as no_round_trips
	FROM trips
	WHERE start_station_code = end_station_code
	GROUP BY start_station_code, end_station_code
	ORDER BY count(*) DESC) AS round_trip1
ON start_trip1.start_station_code = round_trip1.start_station_code
HAVING  no_starting_trip_per_station > 500 AND fraction >= 0.1
ORDER BY fraction DESC
LIMIT 5;

-- 6.5 Where would you expect to find stations with a high fraction of round trips? Describe why and justify your reasoning.
-- Metro Jean-Drapeau, fraction = 0.3020
-- Metro Angrignon, 0.2331
-- Berlioz/ de IIle des Soeurs, 0.2043
-- LaSalle/ 4E AVE, 0.2006
-- Basile-Routhier/ Gouin, 0.1932
SELECT stations.name, stations.latitude, stations.longitude, start_trip1.start_station_code as station_code, round_trip1.no_round_trips, start_trip1.no_starting_trip_per_station, round_trip1.no_round_trips/start_trip1.no_starting_trip_per_station as fraction
FROM ( 
	SELECT start_station_code, count(*) as no_starting_trip_per_station
	FROM trips
	GROUP BY start_station_code) as start_trip1
INNER JOIN (
	SELECT start_station_code, end_station_code, count(*) as no_round_trips
	FROM trips
	WHERE start_station_code = end_station_code
	GROUP BY start_station_code, end_station_code
	ORDER BY count(*) DESC) AS round_trip1
ON start_trip1.start_station_code = round_trip1.start_station_code
INNER JOIN stations ON stations.code = start_trip1.start_station_code
HAVING  no_starting_trip_per_station > 500 AND fraction >= 0.1
ORDER BY fraction DESC
LIMIT 5;
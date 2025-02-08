ALTER TABLE crime_data
ADD CONSTRAINT pk_incident_number PRIMARY KEY (incident_number);


CREATE TABLE crime_data (
    INCIDENT_NUMBER VARCHAR(20),
    OFFENSE_CODE INT,
    OFFENSE_CODE_GROUP VARCHAR(255),
    OFFENSE_DESCRIPTION VARCHAR(255),
    DISTRICT VARCHAR(10),
    REPORTING_AREA VARCHAR(10),
    SHOOTING VARCHAR(5),
    OCCURRED_ON_DATE TIMESTAMP,
    YEAR INT,
    MONTH INT,
    DAY_OF_WEEK VARCHAR(15),
    HOUR INT,
    UCR_PART VARCHAR(50),
    STREET VARCHAR(255),
    Lat DECIMAL(10, 8),
    Long DECIMAL(11, 8),
    Location VARCHAR(50)
);

-- #BASIC DATA CLEANING 
-- 1. Standardize the shooting column: Convert NULL values to 'No' and Y values to 'Yes'.
SELECT * FROM crime_data
-- i want to check how many of them involves shooting here 

SELECT COUNT(shooting) FROM crime_data;-- that's only 1019 
-- now let's check on which places the shooting occured 
SELECT * FROM crime_data 
WHERE shooting IS NOT NULL;
-- so now let's convert all the null values or blank spaces to no if that makes sense

-- NOW CHECK HOW MANY OF THEM HAVE SHOOTING NULL AND REPLACE THEM WITH NO.
UPDATE crime_data
SET shooting = 'NO'
WHERE shooting IS NULL;

-- let's delete the duplicate primary keys from here.
WITH cte AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY incident_number ORDER BY occurred_on_date) AS rn
    FROM crime_data
)
DELETE FROM crime_data
WHERE incident_number IN (
    SELECT incident_number FROM cte WHERE rn > 1
);


-- now let's check if that is reflecting or no 

SELECT * FROM crime_data;

-- now let's replace that shooting 'y' with 'yes' there so it will be perfect 
UPDATE crime_data 
SET shooting = 'yes'
WHERE shooting = 'Y';

-- NOW LET'S CHECK IF THAT IS WORKING OR NO 
SELECT * FROM crime_data;


-- 2.Format occurred_on_date to extract time details: 
--Create new columns for day, week, quarter, and time_of_day (Morning, Afternoon, Evening, Night).

SELECT 
	incident_number, 
	offense_code_group,
	district,
	reporting_area,
	shooting,
	occurred_on_date
FROM crime_data

-- extracted month and quarter from this here
SELECT
	incident_number,
	EXTRACT(QUARTER FROM occurred_on_date),
	EXTRACT(YEAR FROM occurred_on_date)
FROM 	
	crime_data
WHERE 
	YEAR = '2016';

-- let's do time of the day now.

SELECT 
	occurred_on_date,
	CASE 
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=6 AND EXTRACT(HOUR FROM occurred_on_date)<12 THEN 'Morning'
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=12 AND EXTRACT(HOUR FROM occurred_on_date)<18 THEN 'Afternoon'
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=18 AND EXTRACT(HOUR FROM occurred_on_date)<21 THEN 'Evening'
		ELSE 'Night'
	END AS time_of_day
FROM crime_data;

-- now i want to update this to the crime data 
-- so in order to do that 
ALTER TABLE crime_data 
ADD COLUMN time_of_day VARCHAR(50);

UPDATE crime_data
SET time_of_day =
	CASE 
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=6 AND EXTRACT(HOUR FROM occurred_on_date)<12 THEN 'Morning'
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=12 AND EXTRACT(HOUR FROM occurred_on_date)<18 THEN 'Afternoon'
		WHEN EXTRACT(HOUR FROM occurred_on_date) >=18 AND EXTRACT(HOUR FROM occurred_on_date)<21 THEN 'Evening'
		ELSE 'Night'
	END;

SELECT * FROM crime_data;
-- this looks great so instead of months in numbers let's just go with the names of the months here 
-- oh I didn't know that FMMonth is going to give you fullmonth name
SELECT 
	incident_number, 
	TO_CHAR(occurred_on_date, 'FMMonth') AS month
FROM 
	crime_data;
	
ALTER TABLE crime_data
ALTER COLUMN month TYPE text;

UPDATE crime_data 
SET month = TO_CHAR(occurred_on_date, 'FMMonth');

SELECT * FROM crime_data;

-- great now 
-- Fix missing district values: 
-- Replace NULL with 'UNKNOWN' or the most frequent district.

SELECT 
	*
FROM
	crime_data
WHERE district IS NULL; -- there are 1765 

-- so again repeat the same thing 
UPDATE crime_data 
SET district = NULL
WHERE district IS NULL;

-- you're doing great now let's just go to the next question 

--3 & 4: Convert ucr_part values to a more readable format: Replace 'Part One', 'Part Two', etc., with 1, 2, 3.
ALTER TABLE crime_data 
ALTER COLUMN ucr_part TYPE INT
USING ucr_part :: INT;

UPDATE crime_data 
SET ucr_part = CASE 
	WHEN ucr_part = 'Part One' THEN 1
	WHEN ucr_part = 'Part Two' THEN 2
	WHEN ucr_part = 'Part Three' THEN 3
END;
-- Select all the nulls and replace them with the text null here 
SELECT 
	street 
FROM 	
	crime_data
WHERE street IS NULL;-- 10,871

UPDATE crime_data 
SET street = NULL
WHERE street IS NULL;

SELECT * FROM crime_data;

-- replacing the lat empty spaces with null
SELECT lat FROM crime_data

UPDATE crime_data 
SET lat = NULL 
WHERE lat !~ '^[0-9]+(\.[0-9]*)?$' OR lat = '';


ALTER TABLE crime_data 
ALTER COLUMN lat TYPE FLOAT 
USING NULLIF(lat, '')::FLOAT;

SELECT lat, pg_typeof(lat) 
FROM crime_data 
LIMIT 5;

-- do the same thing for long here 
UPDATE crime_data 
SET long = NULL 
WHERE long IS NULL;

SELECT * FROM crime_data;
-- now let's clean the reporting area too 

SELECT * FROM crime_data
WHERE reporting_area = ' ';-- there are 20250 values that are missed her 

UPDATE crime_data 
SET reporting_area = NULL 
WHERE reporting_area IS NULL;

--let's now check if there are any null values anywhere
SELECT * FROM crime_data
WHERE location IS NULL; -- incident_number, offense_code, offense_code_group, offense_description has no null values 

-- BUT reporting_area, district, lat, long's got null values and they are all replaced with null instead of them being left empty 

-- we're done with basic data cleaning good job

-- # EXPLORATORY DATA ANALYSIS 
-- 5.WHAT ARE THE 5 MOST COMMON OFFENSES REPORTED?

SELECT 
	COUNT(DISTINCT incident_number) AS numberofincidents, 
	offense_code_group 
FROM crime_data 
GROUP BY offense_code_group
ORDER BY numberofincidents DESC

-- 6.WHICH DISTRICTS REPORT THE MOST CRIMES?
SELECT 
	COUNT(DISTINCT incident_number) AS numberofincidents,
	district
FROM crime_data
GROUP BY district
ORDER BY numberofincidents DESC;

-- 7.WHAT ARE THE PEAK CRIME HOURS IN EACH DISTRICT?
CREATE VIEW crimebydistrictatmaxhour AS(
SELECT 
	a.district,
	max(a.maxnumberoftimes) AS maxhour,
	a.hour
FROM 
(SELECT 
	t.district,
	t.hour, 
	MAX(t.numberoftimesatthishourbydistrict) AS maxnumberoftimes
	FROM
(SELECT 
	hour,
	COUNT(hour) AS numberoftimesatthishourbydistrict, 
	district
FROM 
	crime_data
GROUP BY hour, district) AS t
GROUP BY t.district, t.hour) AS a
GROUP BY a.hour, a.district, a.maxnumberoftimes
ORDER BY a.maxnumberoftimes DESC
);

SELECT 
	MAX(maxhour),
	hour, 
	district
FROM crimebydistrictatmaxhour
GROUP BY hour, district;
-- kinda undi solution 
WITH CrimeCounts AS (
    SELECT 
        district, 
        hour, 
        COUNT(*) AS crime_count
    FROM crime_data
    GROUP BY district, hour
), RankedCrimes AS (
    SELECT 
        district, 
        hour, 
        crime_count,
        RANK() OVER (PARTITION BY district ORDER BY crime_count DESC) AS rnk
    FROM CrimeCounts
)
SELECT district, hour AS peak_hour, crime_count
FROM RankedCrimes
WHERE rnk = 1; -- Select only the peak hour for each district

--8.which day of the week has the most reported crimes?
WITH CTE AS(
SELECT 
	day_of_week, 
	COUNT(*) AS numberofincidents
FROM crime_data
GROUP BY day_of_week
ORDER BY numberofincidents DESC
), 
rankeddays AS(
SELECT 
	day_of_week,
	numberofincidents, 
	RANK()OVER(ORDER BY numberofincidents DESC) AS rnk
	FROM CTE
)
SELECT 
	day_of_week, 
	numberofincidents 
FROM Rankeddays 
WHERE rnk = 1;


-- has crime increased or decreased over the months in a given year?
SELECT 
	month, 
	COUNT(incident_number) AS numofcrimes,
	year
FROM crime_data
WHERE year = '2016'
GROUP BY month, year
ORDER BY numofcrimes DESC;

-- let's take an average of the numberofcrimes in 2016 then decide 

CREATE VIEW numofcrimes AS(		
SELECT 
	month, 
	COUNT(incident_number) AS numofcrimes,
	year
FROM crime_data
WHERE year = '2016'
GROUP BY month, year
ORDER BY numofcrimes DESC
);


SELECT
SUM(numofcrimes) AS totatnumofcrimes,
ROUND(AVG(numofcrimes)) AS avgnumofcrimes,
year
FROM numofcrimes
GROUP BY year

-- okay let's figure this out tomorrow your brain is not working in this case here neither helping it let's come back to this later 

-- # GEOSPATIAL ANALYSIS 
--10.Find the district with the highest average number of crimes per month.

WITH crimecounts AS (
SELECT 
	district,
	month,
	COUNT(*) AS numofcrimes 
FROM crime_data 
WHERE district IS NOT NULL
GROUP BY month, district),

avgnumofcrimes AS (
SELECT 
	district, 
	ROUND(AVG(numofcrimes),2) AS avg_numofcrimes
FROM crimecounts 
GROUP BY district)

SELECT 
	district, 
	avg_numofcrimes 
FROM avgnumofcrimes
ORDER BY avg_numofcrimes DESC
LIMIT 1; -- just one district right


-- 11. which street has the highest crime frequency 

WITH crimecount AS (
SELECT 
	street, 
	COUNT(*) AS crime_count 
FROM crime_data 
WHERE street IS NOT NULL
GROUP BY street)

SELECT 
	street,
	crime_count 
FROM crimecount 
ORDER BY crime_count DESC
LIMIT 5;

--13. find the top 3 crime hotspots(latitude and longitude)

WITH crimehotspots AS (
SELECT 
	location, 
	COUNT(*) AS crime_counts
FROM crime_data 
WHERE location IS NOT NULL
GROUP BY location)

SELECT 	
	location, 
	crime_counts 
FROM 
	crimehotspots 
ORDER BY crime_counts DESC
LIMIT 3;

-- now that we're done with geospatial analysis 
-- #TIME BASED ANALYSIS 

--13. What percentage of crimes occur duing working hours(9AM-5PM) VS. outside working hours 

WITH crimehours AS (
SELECT 
	COUNT(*) AS crime_count,
	CASE WHEN EXTRACT(HOUR FROM occurred_on_date) BETWEEN 9 AND 17 THEN 'working_hours'
		 ELSE 'Non_working_hours'
	END AS crime_hours 
FROM crime_data
GROUP BY crime_hours
),
totalcrimes AS 
(SELECT SUM(crime_count) AS total_count
FROM crimehours)

SELECT 
	c.crime_hours,
	c.crime_count,
	ROUND((c.crime_count*100/t.total_count),2) AS percentage
FROM crimehours c
CROSS JOIN totalcrimes t;

-- 14. how does crime vary by season?
-- december, january, february- winter,
-- march, april, may - spring,
--june, july, august - summer
-- sept, october, november - fall

-- now take the code offense group 
WITH weathercrime AS ( 
SELECT 
	COUNT(incident_number) AS crime_count,
	 offense_code_group,
	CASE 
		WHEN (EXTRACT (MONTH FROM occurred_on_date) IN (12,1,2) )THEN 'WINTER'
		WHEN (EXTRACT (MONTH FROM occurred_on_date) IN (3,4,5) )THEN 'SPRING'
		WHEN (EXTRACT (MONTH FROM occurred_on_date) IN (6,7,8) )THEN 'SUMMER'
		ELSE 'FALL'
	END AS weather
		
FROM crime_data 
GROUP BY weather, incident_number, offense_code_group -- 67 types of offense_code_group 
),

categorizingoffense AS (
SELECT 
	SUM(crime_count) AS crime_count, 
	offense_code_group, 
	weather
FROM weathercrime 
GROUP BY weather, offense_code_group
)

SELECT 
	MAX(crime_count) AS max_crimes, 
	offense_code_group,
	weather
FROM 
	categorizingoffense
GROUP BY weather, offense_code_group

-- 15. which month has the highest increase in crime compared to the previous month?
WITH extractingmonth AS (
SELECT 
	COUNT(*) AS crime_counts,
	(EXTRACT(MONTH FROM occurred_on_date))AS month,
	year
FROM crime_data 
GROUP BY occurred_on_date, year
ORDER BY month
),

sumofcrimes AS (
SELECT 
	SUM(crime_counts) AS totalcrimes,
	month
FROM extractingmonth
GROUP BY month)

SELECT
	month,
	totalcrimes,
	LAG(totalcrimes) OVER(ORDER BY month) AS previous_count,
	totalcrimes - LAG(totalcrimes) OVER(ORDER BY month) AS difference
FROM sumofcrimes
GROUP BY month, totalcrimes
ORDER BY month;

-- 16. which offense type occurs most often at night 
WITH countcrimesbyhour AS 
(SELECT
 COUNT(*) AS numofcrimes,
 offense_code_group,
 EXTRACT(HOUR FROM occurred_on_date) AS hourofcrime
FROM crime_data 
GROUP BY offense_code_group,
	   	 EXTRACT(HOUR FROM occurred_on_date)
),
night_crimes AS (
	SELECT 
		offense_code_group,
		SUM(numofcrimes) AS total_crimes_at_night
	FROM countcrimesbyhour
	WHERE hourofcrime >=21 OR hourofcrime <6
	GROUP BY offense_code_group 
)
SELECT 
	offense_code_group,
	total_crimes_at_night
FROM night_crimes 
ORDER BY total_crimes_at_night DESC
LIMIT 1;

-- #ADVANCED TRANSFORMATIONS
-- 17. Find the percentage change in crime count month-over-mouth

WITH monthly_crime AS (
    SELECT 
        DATE_TRUNC('month', occurred_on_date) AS month,
        COUNT(*) AS crime_count
    FROM crime_data
    GROUP BY DATE_TRUNC('month', occurred_on_date)
)
SELECT 
    month,
    crime_count,
    LAG(crime_count) OVER (ORDER BY month) AS previous_month_crime,
    ROUND(
        ((crime_count - LAG(crime_count) OVER (ORDER BY month)) * 100.0) / 
        NULLIF(LAG(crime_count) OVER (ORDER BY month), 0), 
        2
    ) AS percent_change
FROM monthly_crime
ORDER BY month;
 
--18.Classify crimes into categories based on ucr_part.
--19. Group offenses into broader categories like Property Crime, Violent Crime, Traffic Violation, etc.
--20. Use window functions to rank offenses by frequency within each district.
WITH crime_classification AS (
    SELECT 
        incident_number,
        district,
        offense_code_group,
        ucr_part,
        CASE 
            WHEN ucr_part = '1' THEN 'Violent Crime'
            WHEN ucr_part = '2' THEN 'Property Crime'
            WHEN ucr_part = '3' THEN 'Traffic Violation'
            ELSE 'Other'
        END AS crime_category
    FROM crime_data
),
crime_counts AS (
    SELECT 
        district,
        crime_category,
        offense_code_group,
        COUNT(*) AS crime_count
    FROM crime_classification
    GROUP BY district, crime_category, offense_code_group
),
ranked_crimes AS (
    SELECT 
        district,
        crime_category,
        offense_code_group,
        crime_count,
        RANK() OVER (PARTITION BY district ORDER BY crime_count DESC) AS rank_within_district
    FROM crime_counts
)
SELECT * FROM ranked_crimes
ORDER BY district, rank_within_district;



	
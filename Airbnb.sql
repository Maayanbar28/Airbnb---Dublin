-- Loading the dataset:
USE airbnb
GO

-------------------------------------------------- Searches table --------------------------------------------------
-- Add new columns to the 'Searches' table: - (one time)
ALTER TABLE searches
ADD estimated_time         INT,
    checkout_minus_ds      INT,
    checkout_minus_checkin INT,
	months_to_rent         INT;

UPDATE searches
SET estimated_time = DATEDIFF(DAY, ds, ds_checkin),
    checkout_minus_ds = DATEDIFF(DAY, ds, ds_checkout),
    checkout_minus_checkin = DATEDIFF(DAY, ds_checkin, ds_checkout),
	months_to_rent = CASE WHEN n_nights IS NULL             THEN 0
	                      WHEN n_nights BETWEEN 1 AND 30    THEN 1
	                      WHEN n_nights BETWEEN 31 AND 60   THEN 2
		 	              WHEN n_nights BETWEEN 61 AND 90   THEN 3
			              WHEN n_nights BETWEEN 91 AND 120  THEN 4
		 	              WHEN n_nights BETWEEN 121 AND 150 THEN 5
			              WHEN n_nights BETWEEN 151 AND 180 THEN 6
			              WHEN n_nights BETWEEN 181 AND 210 THEN 7
			              WHEN n_nights BETWEEN 211 AND 240 THEN 8
			              WHEN n_nights BETWEEN 241 AND 270 THEN 9
			              WHEN n_nights BETWEEN 271 AND 300 THEN 10
			              WHEN n_nights BETWEEN 301 AND 330 THEN 11
			              WHEN n_nights BETWEEN 331 AND 360 THEN 12
			              ELSE 13 END

-- The table describes the information about user searches:
SELECT * FROM searches ORDER BY ds

-- Looking for duplicate rows:
SELECT *, COUNT(*) AS 'count'
FROM searches
GROUP BY ds, id_user, ds_checkin, ds_checkout, n_searches, n_nights, n_guests_min, n_guests_max, origin_country, filter_price_min, filter_price_max, filter_room_types_corrected, filter_neighborhoods, estimated_time, checkout_minus_ds, checkout_minus_checkin, months_to_rent
HAVING COUNT(*) > 1

-- How many searches were there?
SELECT COUNT(*) AS 'num_searches'
FROM searches
-- 35737 

-- How many good searches were there?
SELECT COUNT(*) AS 'num_searches'
FROM searches
WHERE estimated_time >= 0 
-- 23868 

------------------------------ JOIN between Filtered Searches table & Contries table: ------------------------------
-- Join between 'Searches' table and 'Countries' table:
SELECT s.id_user,
       s.ds,
       s.ds_checkin,
	   s.ds_checkout,
	   cou.name AS 'country',
	   s.estimated_time
FROM searches   AS s
JOIN countries  AS cou
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0
ORDER BY estimated_time DESC
-- 23865

-- Conclusion for Filtered 'Searches' table & 'Countries' table:
WITH total_cte AS
(SELECT cou.name                                                                       AS 'country',
        COUNT(*)                                                                       AS 'total_searches'
FROM searches                                                                          AS s 
JOIN countries                                                                         AS cou 
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0
GROUP BY cou.name)
SELECT SUM (total_searches)                                                            AS 'total_searches',
       AVG(total_searches)                                                             AS 'AVG_searches',
	   FORMAT(ROUND((AVG(total_searches) * 1.0/ SUM (total_searches)) * 100, 2), 'N2') AS 'avg pct'
FROM total_cte 
-- Total searches: 23865, AVG: 198, AVG PCT: 0.83%

-- Q1: Which countries have the highest number of searches?
;WITH avg_search AS
(SELECT cou.name                                                AS 'country',
       COUNT(*)                                                 AS 'num_searches',
	   AVG(COUNT(*)) OVER()                                     AS 'avg_num',
	   ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()) * 100, 0) AS 'pct'
FROM searches                                                   AS s 
JOIN countries                                                  AS cou 
ON s.origin_country = cou.code						           
WHERE s.estimated_time >= 0
GROUP BY cou.name)
SELECT country,
       num_searches,
	   avg_num,
	   pct,
	   ROUND(AVG(pct) OVER(), 2)                                AS 'total_avg'
FROM avg_search
ORDER BY num_searches DESC, country
-- USA: 17%, Ireland: 16%, UK: 14%, France: 11%, Total AVG: 0.78%

-- Q2: How soon do the guests want room availability?
WITH time_cte AS
(SELECT DISTINCT cou.name                                AS 'country',
	   AVG(s.estimated_time) OVER(PARTITION BY cou.name) AS 'estimated_time_before',
	   AVG(s.estimated_time) OVER()                      AS 'avg_estimated_time'
FROM searches                                            AS s
JOIN countries                                           AS cou
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0)
SELECT *
FROM time_cte
WHERE country IN ('United States', 'Ireland' ,'United Kingdom', 'France')
ORDER BY estimated_time_before DESC
-- USA: 63, France: 53, UK:52, Ireland: 25, Total AVG: 51 

-- Q3: Which type of room would people prefer to look for?
-- Step 1: Two best filters:
WITH best_filters_cte AS
(SELECT cou.name                                                                    AS 'country',
        s.filter_room_types_corrected                                               AS 'room_type',
        COUNT(*)                                                                    AS 'search_count',
		SUM(COUNT(*)) OVER(PARTITION BY cou.name)                                   AS 'total_count',
		ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(PARTITION BY cou.name)),2) * 100 AS 'pct',
	    DENSE_RANK() OVER (PARTITION BY cou.name ORDER BY COUNT(*) DESC)            AS 'drank'
FROM searches                                                                       AS s
JOIN countries                                                                      AS cou
ON s.origin_country = cou.code 
WHERE s.estimated_time >= 0 AND cou.name IN ('United States', 'Ireland', 'United Kingdom', 'France')
GROUP BY cou.name, s.filter_room_types_corrected)
SELECT country,
       room_type,
	   search_count,
	   total_count,
	   pct
FROM best_filters_cte
WHERE drank < 3
ORDER BY country, search_count DESC

 -- Step 2: Sum of the other filters:
SELECT country,
       'Others'                                                                          AS 'room_type',
       SUM(search_count)                                                                 AS 'search_count',
	   total_count,
	   ROUND((SUM(search_count) * 1.0 / total_count) * 100, 2)                           AS 'pct'
FROM (SELECT cou.name                                                                    AS 'country',
             s.filter_room_types_corrected                                               AS 'room_type',
             COUNT(*)                                                                    AS 'search_count',
			 SUM(COUNT(*)) OVER(PARTITION BY cou.name)                                   AS 'total_count',
			 ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(PARTITION BY cou.name)),2) * 100 AS 'pct',
             DENSE_RANK() OVER (PARTITION BY cou.name ORDER BY COUNT(*) DESC)            AS 'drank'
      FROM searches                                                                      AS s
      JOIN countries                                                                     AS cou 
      ON s.origin_country = cou.code
      WHERE s.estimated_time >= 0 AND cou.name IN ('United States', 'Ireland', 'United Kingdom', 'France')
      GROUP BY cou.name, s.filter_room_types_corrected) AS others_filters
WHERE drank >= 3
GROUP BY country, total_count
ORDER BY search_count DESC

-- Step 3: Combine results:
WITH best_filters_cte AS 
(SELECT cou.name                                                                    AS 'country',
        s.filter_room_types_corrected                                               AS 'room_type',
        COUNT(*)                                                                    AS 'search_count',
		SUM(COUNT(*)) OVER(PARTITION BY cou.name)                                   AS 'total_count',
		ROUND((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER(PARTITION BY cou.name)),2) * 100 AS 'pct',
        DENSE_RANK() OVER (PARTITION BY cou.name ORDER BY COUNT(*) DESC)            AS 'drank'
 FROM searches                                                                      AS s
 JOIN countries                                                                     AS cou 
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0 AND cou.name IN ('United States', 'Ireland', 'United Kingdom', 'France')
 GROUP BY cou.name, s.filter_room_types_corrected),
others_filters AS 
(SELECT country,
        'Others'                                                                    AS 'room_type',
        SUM(search_count)                                                           AS 'search_count',
		total_count,													            
		ROUND((SUM(search_count) * 1.0 / total_count) * 100, 2)                     AS 'pct'
 FROM best_filters_cte
 WHERE drank >= 3
 GROUP BY country, total_count)
SELECT country,
       room_type,
       search_count,
	   total_count,
	   pct
FROM best_filters_cte
WHERE drank < 3
UNION ALL
SELECT country,
       room_type,
       search_count,
	   total_count,
	   pct
FROM others_filters
ORDER BY country, search_count DESC
-- France: NULL: 41% , 'Entire home/apt':38%  , Others: 21%
-- Ireland: NULL: 42%, 'Entire home/apt': 31%, Others: 27% 
-- UK: NULL: 38%, 'Entire home/apt': 46%, Others: 15%
-- USA: NULL: 45%, 'Entire home/apt': 37%, Others: 18%

-- Conclusion for n_nights:
WITH calculate_cte AS
(SELECT cou.name                        AS 'country',
        MIN(s.n_nights)                 AS 'min_nights',
 	    MAX(s.n_nights)                 AS 'max_nights',
 	    AVG(s.n_nights)                 AS 'avg_nights',
 		ROUND(AVG(s.n_nights) OVER(),0) AS 'total_avg'
  FROM searches                         AS s
  JOIN countries                        AS cou
  ON s.origin_country = cou.code
  WHERE s.estimated_time >= 0 AND cou.name IN ('Ireland', 'United States', 'United Kingdom', 'France')
  GROUP BY name, n_nights)
SELECT country,
       MIN(min_nights)                  AS 'min',
	   MAX(min_nights)                  AS 'max',
       total_avg
FROM calculate_cte
GROUP BY country, total_avg
ORDER BY MAX(min_nights) DESC
-- MIN, MAX | Ireland: 1, 392 | USA: 0, 366 | UK: 1, 357 | France: 0, 265 | Total AVG: 71

-- How many times do 'months_to_rent' appear for each time period? IN the countries -- 23865 total searches
SELECT country,
       months_to_rent,
       COUNT(*)       AS 'how_many_times'
FROM (SELECT cou.name AS 'country',
             s.months_to_rent
      FROM searches   AS s
      JOIN countries  AS cou 
	  ON s.origin_country = cou.code
      WHERE s.estimated_time >= 0 AND cou.name IN ('Ireland', 'United States', 'United Kingdom', 'France')) AS month_count
GROUP BY country, months_to_rent
ORDER BY  how_many_times DESC

-- How many times do 'months_to_rent' appear for each time period? NOT IN the countries:
SELECT country,
       months_to_rent,
       COUNT(*)       AS 'how_many_times'
FROM (SELECT cou.name AS 'country',
             s.months_to_rent
      FROM searches   AS s
      JOIN countries  AS cou 
	  ON s.origin_country = cou.code
      WHERE s.estimated_time >= 0 AND cou.name NOT IN ('Ireland', 'United States', 'United Kingdom', 'France')) AS month_count
GROUP BY country, months_to_rent
ORDER BY  how_many_times DESC

-- Q4: How many nights are guests looking to stay? (with the 4 countries):
SELECT cou.name                             AS 'country',
       MIN(s.n_nights)                      AS 'min_nights',
	   MAX(s.n_nights)                      AS 'max_nights',
	   ROUND(AVG(s.n_nights),0)             AS 'avg_nights',
	   ROUND(AVG(AVG(s.n_nights)) OVER(),0) AS 'total_avg'
FROM searches                               AS s
JOIN countries                              AS cou
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0 AND cou.name IN ('Ireland', 'United States', 'United Kingdom', 'France')
GROUP BY cou.name
-- MIN, MAX, AVG | France: 0,  265, 6 | Ireland: 1, 392, 9 | UK: 1, 357, 4 | USA: 0, 366, 6 | Total AVG: 6 

-- How many nights are guests looking to stay? (without the 4 countries):
;WITH avg_cte AS
(SELECT cou.name                 AS 'country',
        AVG(s.n_nights)          AS 'avg_nights'
 FROM searches                   AS s
 JOIN countries                  AS cou
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0
 GROUP BY name)
SELECT ROUND(AVG(avg_nights), 0) AS 'total_avg'
FROM avg_cte
WHERE country NOT IN ('Ireland', 'United States', 'United Kingdom', 'France') 
-- Total AVG: 9 

-- How many nights are guests looking to stay? - (only for the 4 countries):
SELECT ROUND(AVG(AVG(s.n_nights)) OVER (), 0) AS 'avg_nights'
FROM searches                                 AS s
JOIN countries                                AS cou
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0 AND cou.name IN ('Ireland', 'United States', 'United Kingdom', 'France')
-- Total AVG: 6

-- Q4: How many nights are guests looking to stay? - until 1 month:
;WITH avg_cte AS
(SELECT cou.name                             AS 'country',
        ROUND(AVG(s.n_nights),0)             AS 'avg_nights',
		ROUND(AVG(AVG(s.n_nights)) OVER(),0) AS 'total_avg'
 FROM searches                               AS s
 JOIN countries                              AS cou
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0  AND s.months_to_rent = 1
 GROUP BY name)
SELECT country,
       avg_nights,
	   total_avg
FROM avg_cte
WHERE country IN ('Ireland', 'United States', 'United Kingdom', 'France')
ORDER BY country
-- AVG | France: 4 | Ireland: 5 | UK: 3 | USA: 4 | Total AVG: 6

-- Q4: How many nights are guests looking to stay? - between 1 month to 2:
;WITH avg_cte AS
(SELECT cou.name                             AS 'country',
        ROUND(AVG(s.n_nights),0)             AS 'avg_nights',
		ROUND(AVG(AVG(s.n_nights)) OVER(),0) AS 'total_avg'
 FROM searches                               AS s
 JOIN countries                              AS cou
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0  AND s.months_to_rent = 2
 GROUP BY name)
SELECT country,
       avg_nights,
	   total_avg
FROM avg_cte
WHERE country IN ('Ireland', 'United States', 'United Kingdom', 'France')
ORDER BY country
-- AVG | France: 43 | Ireland: 41 | UK: 40 | USA: 39 | Total AVG: 39

-- Q4 How many nights are guests looking to stay? - 3 months+:
;WITH avg_cte AS
(SELECT cou.name                                                  AS 'country',
        ROUND(AVG(s.n_nights),0)                                  AS 'avg_nights',
		ROUND(AVG(AVG(s.n_nights)) OVER(),0)                      AS 'total_avg'
 FROM searches                                                    AS s
 JOIN countries                                                   AS cou
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0  AND s.months_to_rent > 2
 GROUP BY name)
SELECT *
FROM avg_cte
WHERE country IN ('Ireland', 'United States', 'United Kingdom', 'France')
ORDER BY country
-- AVG | France: 109 | Ireland: 125 | UK: 109 | USA: 115 | Total AVG: 112

------------------------------------------------ 'Contacts' table --------------------------------------------------- 
-- Add new columns to the 'Contacts' table: - (one time)
ALTER TABLE contacts
ADD minutes_to_reply INT,
    days_to_checkin INT;

UPDATE contacts
SET minutes_to_reply = DATEDIFF(MINUTE, ts_contact_at, ts_reply_at),
    days_to_checkin = DATEDIFF(DAY, ts_contact_at, ds_checkin);

-- The table describes the order made by the guests: 
SELECT * FROM contacts

-- Looking for duplicate rows:
SELECT *, COUNT(*) AS CNT
FROM contacts
GROUP BY id_guest, id_host, id_listing, ts_contact_at, ts_reply_at, ts_accepted_at, ts_booking_at, ds_checkin, ds_checkout, n_guests, n_messages, minutes_to_reply, days_to_checkin
HAVING COUNT(*) > 1

-- Number of orders:
SELECT COUNT(*) AS 'num_of_orders'
FROM contacts 
-- 7823

---------------------- JOIN between Filtered 'Searches' table & 'Contries' table & 'Contacts' table: ----------------------
-- How many orders made?
SELECT COUNT(*)    AS 'total_orders'
FROM searches      AS s
JOIN countries     AS cou 
ON s.origin_country = cou.code
LEFT JOIN contacts AS c 
ON s.id_user = c.id_guest
WHERE s.estimated_time >= 0
-- 38314

-- How many real orders made?
SELECT COUNT(*)    AS 'total_orders'
FROM searches      AS s
JOIN countries     AS cou 
ON s.origin_country = cou.code
LEFT JOIN contacts AS c 
ON s.id_user = c.id_guest
WHERE s.estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
-- 16984

-- Q5: Which countries did an order?
-- Step 1: Result of num_searches:
SELECT cou.name             AS 'country',
       COUNT(*)             AS 'num_searches',
	   AVG(COUNT(*)) OVER() AS 'avg_total_searches'
FROM searches               AS s 
JOIN countries              AS cou 
ON s.origin_country = cou.code
WHERE s.estimated_time >= 0
GROUP BY cou.name
ORDER BY num_searches DESC 

-- Step 2: Result of num_orders:
SELECT cou.name             AS 'country',
       COUNT(*)             AS 'num_orders',
	   AVG(COUNT(*)) OVER() AS 'avg_total_orders'
FROM searches               AS s
JOIN countries              AS cou 
ON s.origin_country = cou.code
LEFT JOIN contacts          AS c 
ON s.id_user = c.id_guest
WHERE s.estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
GROUP BY cou.name
ORDER BY num_orders DESC

-- Step 3: Combine results:
WITH search_counts AS 
(SELECT cou.name             AS 'country',
        COUNT(*)             AS 'num_searches'
 FROM searches               AS s 
 JOIN countries              AS cou 
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0
 GROUP BY cou.name),
order_counts AS 
(SELECT cou.name             AS 'country',
        COUNT(*)             AS 'num_orders',
	    AVG(COUNT(*)) OVER() AS 'avg_total_orders'
 FROM searches               AS s
 JOIN  countries             AS cou 
 ON s.origin_country = cou.code
 LEFT JOIN contacts          AS c 
 ON s.id_user = c.id_guest
 WHERE s.estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
 GROUP BY cou.name)
SELECT sc.country,
       sc.num_searches,
       oc.num_orders,
	   oc.avg_total_orders,
	   ROUND((oc.num_orders * 1.0 / sc.num_searches) * 100,0)               AS 'order_pct',
	   oc.num_orders - sc.num_searches                                      AS 'diff',
	   ROUND(AVG((oc.num_orders * 1.0 / sc.num_searches) * 100) OVER (), 0) AS 'total_avg_pct'
FROM search_counts                                                          AS sc
JOIN order_counts                                                           AS oc 
ON sc.country = oc.country
ORDER BY sc.num_searches DESC
-- France: 74% | USA: 68% | UK: 65% | Ireland: 45% | Total AVG: 98%

-- Q5+: The top countries with the most orders but a few searches:
WITH search_counts AS 
(SELECT cou.name             AS 'country',
        COUNT(*)             AS 'num_searches'
 FROM searches               AS s 
 JOIN countries              AS cou 
 ON s.origin_country = cou.code
 WHERE s.estimated_time >= 0
 GROUP BY cou.name),
order_counts AS 
(SELECT cou.name             AS 'country',
        COUNT(*)             AS 'num_orders',
	    AVG(COUNT(*)) OVER() AS 'avg_total_orders'
 FROM searches               AS s
 JOIN  countries             AS cou 
 ON s.origin_country = cou.code
 LEFT JOIN contacts          AS c 
 ON s.id_user = c.id_guest
 WHERE s.estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
 GROUP BY cou.name)
SELECT sc.country,
       sc.num_searches,
       oc.num_orders,
	   oc.avg_total_orders,
	   ROUND((oc.num_orders * 1.0 / sc.num_searches) * 100,0)               AS 'order_pct',
	   oc.num_orders - sc.num_searches                                      AS 'diff',
	   ROUND(AVG((oc.num_orders * 1.0 / sc.num_searches) * 100) OVER (), 0) AS 'total_avg_pct'
FROM search_counts                                                          AS sc
JOIN order_counts                                                           AS oc 
ON sc.country = oc.country
ORDER BY order_pct DESC
-- Cayman Islands: 900% | India: 753% | Costa Rica: 300% | Iceland: 200% | Total AVG: 98%
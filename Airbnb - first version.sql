-- Loading the dataset:
USE airbnb
GO

----------------------------------- Searches table -----------------------------------
-- The table describes the information about user searches:
SELECT * FROM searches ORDER BY ds

-- Add new columns to the 'searches' table:
ALTER TABLE searches
ADD estimated_time INT,
    checkout_minus_ds INT,
    checkout_minus_checkin INT;

UPDATE searches
SET estimated_time = DATEDIFF(DAY, ds, ds_checkin),
    checkout_minus_ds = DATEDIFF(DAY, ds, ds_checkout),
    checkout_minus_checkin = DATEDIFF(DAY, ds_checkin, ds_checkout);

-- Looking for duplicate rows:
SELECT *, COUNT(*) AS CNT
FROM searches
GROUP BY ds, id_user, ds_checkin, ds_checkout, n_searches, n_nights, n_guests_min, n_guests_max, origin_country, filter_price_min, filter_price_max, filter_room_types_corrected, filter_neighborhoods, estimated_time, checkout_minus_ds, checkout_minus_checkin
HAVING COUNT(*) > 1

-- Searches with filter time:
SELECT id_user,
       ds,
       ds_checkin,
	   ds_checkout,
	   estimated_time
FROM searches
WHERE estimated_time >= 0
ORDER BY estimated_time DESC -- 23868

-- The number of searches by each month - no filter:
SELECT *
FROM   (SELECT id_user, DAY(ds) AS 'day' FROM searches) AS src_tbl
PIVOT  (COUNT(id_user) FOR day IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14])) AS PVT

-- The number of searches by each month - filtered:
SELECT *
FROM   (SELECT id_user, DAY(ds) AS 'day' FROM searches WHERE estimated_time >= 0) AS src_tbl
PIVOT  (COUNT(id_user) FOR day IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14])) AS PVT

-- shortcut for the pivot:
SELECT DISTINCT ', ' + QUOTENAME(DAY(ds)) AS 'day' FROM searches ORDER BY day 

-------------------------------------- Conclusion: --------------------------------------
-- How many searces?
SELECT COUNT(*) AS 'total_searches'
FROM searches -- 35737

-- How many estimated_time < 0 & = 0?
SELECT COUNT(*) AS 'under_equal_0'
FROM searches
WHERE estimated_time = 0 -- <0 + =0 | 20 + 538

-- How many checkout_minus_ds < 0 & = 0?
SELECT COUNT(*) AS 'under_equal_0'
FROM searches
WHERE checkout_minus_ds = 0 -- <0 + =0 | 0 + 6

-- How many checkout_minus_checkin < 0 & = 0?
SELECT COUNT(*) AS 'under_equal_0'
FROM searches
WHERE checkout_minus_checkin < 0 -- <0 + =0 | 0 + 5

-- How many searces after time filter?
SELECT COUNT(*) AS 'total_searches'
FROM searches
WHERE estimated_time >= 0 -- 23868

-- How many people were filtered?
SELECT 35737 - 23868 -- = 11869 -- 66% | 34%

-- Which month & year were searches conducted?
SELECT DISTINCT MONTH(ds) AS 'month', YEAR(ds) AS 'year' FROM searches -- October 2014

-- How many days were searches conducted?
SELECT COUNT(DISTINCT ds) FROM searches -- the first 14 days

-- For which years were looking for the invitation?
SELECT DISTINCT YEAR(ds_checkin) FROM searches -- 2014, 2015, 2016

------------------------------ JOIN between Filtered Searches table & Contries table: ------------------------------
-- Join between searches and countries:
SELECT id_user,
       ds,
       ds_checkin,
	   ds_checkout,
	   name    AS 'country',
	   estimated_time
FROM searches  AS s
JOIN countries AS cou
ON s.origin_country = cou.code
WHERE estimated_time >= 0
ORDER BY estimated_time DESC -- 23865

-- Conclusion for countries:
WITH total_cte AS
(SELECT cou.name                                                                       AS 'country',
       COUNT(s.id_user)                                                                AS 'total_searches'
FROM searches                                                                          AS s 
JOIN countries                                                                         AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY cou.name)
SELECT SUM (total_searches)                                                            AS 'total_searches',
       AVG(total_searches)                                                             AS 'AVG_searches',
	   FORMAT(ROUND((AVG(total_searches) * 1.0/ SUM (total_searches)) * 100, 2), 'N2') AS 'avg pct'
FROM total_cte -- total searches: 23865, AVG: 198, AVG PCT: 0.83%

-- The top countries with the highest number of searchers:
SELECT TOP 14 cou.name                                                              AS 'country',
       COUNT(s.id_user)                                                             AS 'num_searches',
	   FORMAT((COUNT(s.id_user) * 1.0 / SUM(COUNT(s.id_user)) OVER ()) * 100, 'N2') AS 'pct'
FROM searches                                                                       AS s 
JOIN countries                                                                      AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY cou.name
ORDER BY num_searches DESC, country

-- Years:
SELECT id_user,
       DAY(ds_checkin)     AS 'day',
	   MONTH(ds_checkin)   AS 'month',
	   YEAR(ds_checkin)    AS 'year',
	   COUNT(id_user)      AS 'num_searches',
	   estimated_time,
	   SUM(COUNT(id_user)) OVER () AS 'total_searches'
FROM searches              AS s 
JOIN countries             AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0 --AND YEAR(ds_checkin) = 2015
GROUP BY id_user, ds_checkin, estimated_time
ORDER BY year, month, day, num_searches DESC

-- Estimated time before the order:
SELECT DISTINCT name                               AS 'country',
	   AVG(estimated_time) OVER(PARTITION BY name) AS 'estimated_time_before'
FROM searches                                      AS s
JOIN countries                                     AS cou
ON s.origin_country = cou.code
WHERE estimated_time >= 0 AND name IN ('United States', 'Ireland' ,'United Kingdom')
ORDER BY estimated_time_before DESC

-- AVG estimated time before the order:
WITH avg_cte AS
(SELECT DISTINCT name                              AS 'country',
	   AVG(estimated_time) OVER(PARTITION BY name) AS 'estimated_time_before'
  FROM searches                                    AS s
  JOIN countries                                   AS cou
  ON s.origin_country = cou.code
  WHERE estimated_time >= 0)
SELECT AVG(estimated_time_before)                  AS 'avg_time_before'
FROM avg_cte; -- 51

-- room_types:
-- Which type of room would people prefer to look for?
WITH rank_cte AS
(SELECT DISTINCT name                         AS 'country',
	   filter_room_types_corrected,		      
       COUNT(*)                               AS 'num_searches',
	   SUM(COUNT(*)) OVER (PARTITiON BY name) AS 'total_searches'
  FROM searches                               AS s
  JOIN countries                              AS cou
  ON s.origin_country = cou.code
  WHERE estimated_time >= 0
  GROUP BY filter_room_types_corrected, name)
SELECT country,
       filter_room_types_corrected,
	   num_searches,
	   total_searches,
	   FORMAT(ROUND((num_searches *1.0 / total_searches) * 100,2), 'N2') AS 'pct'
FROM rank_cte
WHERE country IN ('United States', 'Ireland' ,'United Kingdom')
ORDER BY country DESC, num_searches DESC 
-- NULL,['Entire home/apt'], ['Private room', 'Entire home/apt'], ['Private room']

-- number_of_nights, min_nights, max_nights, num_searches?

-- AVG search each country:
WITH avg_cte AS
(SELECT cou.name                                  AS 'country',
        COUNT(*)                                  AS 'num_searches',
	    DENSE_RANK() OVER(ORDER BY COUNT(*) DESC) AS 'drank'
  FROM searches                                   AS s
  JOIN countries                                  AS cou
  ON s.origin_country = cou.code
  WHERE estimated_time >= 0
  GROUP BY name)
SELECT AVG(num_searches)                          AS 'avg_search'
FROM avg_cte

-- AVG number of nights:
;WITH cte AS
(SELECT cou.name                        AS 'country',
        COUNT(*)                        AS 'num_searches',
	    SUM(COUNT(*)) OVER()            AS 'total_searches',
		s.n_nights,
	    AVG(COUNT(*)) OVER()            AS 'avg_searches',
	    ROUND(AVG(s.n_nights) OVER(),0) AS 'total_avg',
		ROUND(AVG(s.n_nights) OVER(PARTITION BY cou.name),0) AS 'avg_nights'
	    --ROUND(AVG(s.n_nights),0) AS 'avg_nights'
  FROM searches                         AS s
  JOIN countries                        AS cou
  ON s.origin_country = cou.code
  WHERE estimated_time >= 0
  GROUP BY cou.name, s.n_nights)
SELECT country,
       SUM(num_searches)                 AS 'num_searches',
	   total_searches,
	   avg_searches,
	   n_nights,
	   total_avg,
	   avg_nights
FROM cte
WHERE country IN ('Ireland', 'United States', 'United Kingdom')
GROUP BY country, total_searches, avg_searches, total_avg, n_nights, avg_nights
ORDER BY country
-------------------------------------- Conclusion: --------------------------------------
-- How many countries?
SELECT cou.name              AS 'country',
       COUNT (DISTINCT name) AS 'num_searches'
FROM searches                AS s
JOIN countries               AS cou
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY cou.name -- 120

-- How many searches were in each year & each month?
SELECT name                AS 'country',
       YEAR(ds_checkin)    AS 'year',
       MONTH(ds_checkin)   AS 'month',
       COUNT(id_user)      AS 'num_searches',
	   SUM(COUNT(id_user)) OVER (PARTITION BY YEAR(ds_checkin)) AS 'total_num_per_year'
FROM searches              AS s 
JOIN countries             AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY name, ds_checkin
ORDER BY year, month -- 2014: 19946 | 2015: 3914 | 2016: 5

-- How many searches were in each country?
SELECT name                 AS ' country',
       COUNT(*)             AS 'num_searches',
	   SUM(COUNT(*)) OVER() AS 'total_searches',
	  FORMAT((COUNT(*) * 1.0 / SUM(COUNT(*)) OVER()) * 100, 'N2') AS 'pct'
FROM searches               AS s
JOIN countries              AS cou
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY name
ORDER BY num_searches DESC

-- How many room types?
SELECT COUNT(DISTINCT filter_room_types_corrected) AS 'room_types'
FROM searches                                      AS s
JOIN countries                                     AS cou
ON s.origin_country = cou.code
WHERE estimated_time >= 0 -- 7 + NULL

--------------------------------------------not good:------------------------------------
-- 2014
SELECT DISTINCT id_user,
       YEAR(ds_checkin)    AS 'year',
       MONTH(ds_checkin)   AS 'month',
       COUNT(id_user)      AS 'num_searches',
	   SUM(COUNT(id_user)) OVER (PARTITION BY YEAR(ds_checkin)) AS 'total_num_per_year'
FROM searches              AS s 
JOIN countries             AS cou 
ON s.origin_country = cou.code
WHERE estimated_time > 0 AND YEAR(ds_checkin) = 2014
GROUP BY id_user, ds_checkin
ORDER BY year, month -- 2014: 238 

-- 2015
SELECT DISTINCT name       AS 'country',
       YEAR(ds_checkin)    AS 'year',
       MONTH(ds_checkin)   AS 'month',
       COUNT(id_user)      AS 'num_searches',
	   SUM(COUNT(id_user)) OVER (PARTITION BY YEAR(ds_checkin), MONTH(ds_checkin)) AS 'total_num_per_year'
FROM searches              AS s 
JOIN countries             AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0 AND YEAR(ds_checkin) = 2015 AND name = 'Ireland'
GROUP BY name, ds_checkin
ORDER BY year, month, num_searches DESC -- 2015: 306
-- 1:829 | 2:520 | 3:984 | 4:380 | 5:367 | 6:340 | 7:215 | 8:164 | 9:78 | 10:24 | 11:6 | 12:7

-- 2014 vs 2015 - Q4:
SELECT YEAR(ds_checkin)    AS 'year',
       MONTH(ds_checkin)   AS 'month',
       COUNT(id_user)      AS 'num_searches',
	   SUM(COUNT(id_user)) OVER (PARTITION BY YEAR(ds_checkin)) AS 'total_num_per_year'
FROM searches              AS s 
JOIN countries             AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0 AND YEAR(ds_checkin) IN ('2014', '2015') AND MONTH(ds_checkin) IN (10,11,12)
GROUP BY ds_checkin
ORDER BY year, month, num_searches DESC

-- יש לנו שבועיים של חיפושים ב2014, רוב החיפושים נערכים בין חודש לחודשיים לפני בממוצע
------------------------------------------------------------------------------------------------------------

----------------------------------- Contacts table -----------------------------------
-- The table describes the order made by the guests: 
SELECT * FROM contacts

-- Add new columns to the 'searches' table:
ALTER TABLE contacts
ADD minutes_to_reply INT,
    days_to_checkin INT;

UPDATE contacts
SET minutes_to_reply = DATEDIFF(MINUTE, ts_contact_at, ts_reply_at),
    days_to_checkin = DATEDIFF(DAY, ts_contact_at, ds_checkin);

-- Looking for duplicate rows:
SELECT *, COUNT(*) AS CNT
FROM contacts
GROUP BY id_guest, id_host, id_listing, ts_contact_at, ts_reply_at, ts_accepted_at, ts_booking_at, ds_checkin, ds_checkout, n_guests, n_messages, minutes_to_reply, days_to_checkin
HAVING COUNT(*) > 1

-- Number of orders:
SELECT COUNT(*) AS 'num_of_orders'
FROM contacts -- 7823

-- Years of contact:
SELECT DISTINCT YEAR(ts_contact_at) AS 'year', -- 2014 & 2015
       MONTH(ts_contact_at)         AS 'month', -- 2014: 3-12, 2015: 1-2
	   DAY(ts_contact_at)           AS 'day'
FROM contacts
ORDER BY year, month, day

-- Years of checkin:
SELECT DISTINCT YEAR(ds_checkin) AS 'year', -- 2014 & 2015
       MONTH(ds_checkin)         AS 'month',-- 2014: 10-12, 2015: 1-10
	   DAY(ds_checkin)           AS 'day'
FROM contacts
ORDER BY year, month, day

-- ts_contact_at vs ts_reply_at vs ds_checkin:
SELECT ts_contact_at,
       ts_reply_at,
	   ds_checkin,
	   minutes_to_reply,
	   days_to_checkin
FROM contacts
-- WHERE minutes_to_reply = 0 --  >0 + NULL + =0 | 7010 + 604 + 209 = 7823
-- WHERE days_to_checkin = 0 --  >0 + =0 | 7551 + 272 = 7823
ORDER BY minutes_to_reply, days_to_checkin

-- AVG minutes to reply:
SELECT id_guest,
	   minutes_to_reply,
	   AVG(minutes_to_reply) OVER()                    AS 'avg_minutes',  -- AVG: 579
	   AVG(minutes_to_reply) OVER() - minutes_to_reply AS 'diff'
FROM contacts
ORDER BY diff DESC

-- AVG minutes to reply - filtered:
WITH avg_minutes_cte AS
(SELECT id_guest,
	   minutes_to_reply,
	   AVG(minutes_to_reply) OVER()                    AS 'avg_minutes', -- AVG: 579
	   AVG(minutes_to_reply) OVER() - minutes_to_reply AS 'diff'
 FROM contacts)
SELECT *
FROM avg_minutes_cte
WHERE diff > 0 -- >0 + NULL + =0 + <0 | 5496 + 604 + 6 + 6106 | under avg: 6106 + above avg: 1717 = 7823
ORDER BY diff 

-- AVG days to reply - filtered: 
WITH avg_days_cte AS
(SELECT id_guest,
        minutes_to_reply,
        ROUND((minutes_to_reply * 1.0) / 1440 * 100, 2)     AS 'days_to_reply',
        FORMAT(ROUND(AVG((minutes_to_reply * 1.0) / 1440) OVER(), 2), 'N1') AS 'avg_days_to_reply', -- 0.4
		FORMAT(ROUND(AVG((minutes_to_reply * 1.0) / 1440) OVER(), 2), 'N1') -
		ROUND((minutes_to_reply * 1.0) / 1440 * 100, 2)                     AS 'diff'
  FROM contacts)
SELECT *
FROM avg_days_cte
WHERE diff IS NULL -- >0 + NULL + <0 | 855 + 604 + 6364 = 7823
ORDER BY days_to_reply DESC, diff DESC

-- PCT AVG days to reply:
SELECT FORMAT((6364 * 1.0 / 7823) * 100, 'N0') AS 'pct_reply'-- >0 + NULL + <0 | under avg: 11% + NULL: 8% + above avg: 81%

-- AVG days to checkin:
SELECT id_guest,
       days_to_checkin,
	   AVG(days_to_checkin) OVER()                   AS 'avg_days', -- AVG: 37
	   AVG(days_to_checkin) OVER() - days_to_checkin AS 'diff'
FROM contacts
ORDER BY diff DESC

-- AVG days to checkin - filtered:
WITH avg_days_cte AS
(SELECT id_guest,
        days_to_checkin,
	    AVG(days_to_checkin) OVER()                   AS 'avg_minutes',
	    AVG(days_to_checkin) OVER() - days_to_checkin AS 'diff'
  FROM contacts)
SELECT *
FROM avg_days_cte
WHERE diff > 0 -- >0 + =0 + <0 | 5583 + 61 + 2179 = 7823
ORDER BY days_to_checkin DESC, diff DESC

-- PCT AVG days to checkin:
SELECT FORMAT((2179 * 1.0 / 7823) * 100, 'N0') AS 'pct_days_checkin'-- >0 + NULL + <0 | under avg: 71% + zero: 1% + above avg: 28%

-- AVG, MAX & MIN number of guests:
SELECT id_guest,
       n_guests,
       ROUND(AVG(n_guests) OVER(), 1)            AS 'avg_guests', -- 2.4
       MIN(n_guests) OVER()                      AS 'min_gusts', -- 1
	   MAX(n_guests) OVER()                      AS 'max_gusts' -- 16
FROM contacts
ORDER BY n_guests

-- AVG number of guests - filtered:
WITH nights_cte AS
(SELECT id_guest,
        n_guests,
        ROUND(AVG(n_guests) OVER(), 1)            AS 'avg_guests', -- 2.4
	    ROUND(AVG(n_guests) OVER(), 1) - n_guests AS 'diff'
  FROM contacts)
SELECT *
FROM nights_cte
WHERE diff < 0  -- >0 + <0 | 5576 + 2247 = 7823
ORDER BY diff DESC

-- PCT AVG number of guests:
SELECT FORMAT((2247 * 1.0 / 7823) * 100, 'N0') AS 'pct_guests' -- >0 + <0 | under avg: 71% + above avg: 29%

-- AVG, MIN & MAX number of messages:
SELECT id_guest,
       n_messages,
	   MIN(n_messages) OVER()          AS 'min_messages', -- 1
	   MAX(n_messages) OVER()          AS 'max_messages', -- 16
	   ROUND(AVG(n_messages) OVER(),1) AS 'avg_messages' -- 6.3
FROM contacts
ORDER BY n_messages DESC

-- AVG number of messages - filtered:
WITH massages_cte AS
(SELECT id_guest,
        n_messages,
        ROUND(AVG(n_messages) OVER(),1)              AS 'avg_messages', -- 6.3
		ROUND(AVG(n_messages) OVER(),1) - n_messages AS 'diff'
  FROM contacts)
SELECT *
FROM massages_cte
WHERE diff > 0 -- >0 + <0 | 5461 + 2362 = 7823
ORDER BY n_messages DESC

-- PCT AVG number of messages:
SELECT FORMAT((2362 * 1.0 / 7823) * 100, 'N0') AS 'pct_messages' -- >0 + <0 | under avg: 70% + above avg: 30%

-------------------- JOIN between Filtered Searches table & Contries table & Contacts table: --------------------
SELECT s.ds,
       s.id_user,
	   s.ds_checkin AS 'search_chechin',
	   s.estimated_time,
	   cou.name     AS 'country',
	   c.ts_contact_at,
	   c.ts_reply_at,
	   c.minutes_to_reply,
	   c.ds_checkin AS 'contact_checkin',
	   c.days_to_checkin
FROM searches       AS s
JOIN countries      AS cou
ON s.origin_country = cou.code
JOIN contacts       AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 -- 22507

-- How many orders made?
SELECT COUNT(*) AS 'total_orders'
FROM searches   AS s
JOIN countries  AS cou
ON s.origin_country = cou.code
JOIN contacts   AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 -- 22507

-- Search years:
SELECT DISTINCT YEAR(s.ds)  AS 'year',
                MONTH(s.ds) AS 'month',
				DAY(s.ds)   AS 'day'
FROM searches       AS s
JOIN countries      AS cou
ON s.origin_country = cou.code
JOIN contacts       AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0
ORDER BY year, month, day -- 1/10/14 - 14/10/14

-- Search checkin years:
SELECT DISTINCT YEAR(s.ds_checkin)                                               AS 'year',
                MONTH(s.ds_checkin)                                              AS 'month',
				COUNT(DAY(s.ds_checkin)) OVER (PARTITION BY YEAR(s.ds_checkin), 
				                                            MONTH(s.ds_checkin)) AS 'total_days'
FROM searches                                                                    AS s
JOIN countries                                                                   AS cou
ON s.origin_country = cou.code
JOIN contacts                                                                    AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0
GROUP BY s.ds_checkin
ORDER BY year, month -- 2014: Q4, 2015: 1-10

-- Contact years:
SELECT DISTINCT YEAR(c.ts_contact_at)                                                  AS 'year',
                MONTH(c.ts_contact_at)                                                 AS 'month',
				COUNT(DAY(c.ts_contact_at)) OVER (PARTITION BY YEAR(c.ts_contact_at), 
				                                               MONTH(c.ts_contact_at)) AS 'total_days'
FROM searches                                                                          AS s
JOIN countries                                                                         AS cou
ON s.origin_country = cou.code
JOIN contacts                                                                          AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0
GROUP BY c.ts_contact_at
ORDER BY year, month -- 2014: 3-12, 2015: 1-2

-- Search checkin years + total orders:
SELECT YEAR(s.ds_checkin)                                               AS 'year',
       MONTH(s.ds_checkin)                                              AS 'month',
	   COUNT(DAY(s.ds_checkin)) OVER (PARTITION BY YEAR(s.ds_checkin), 
				                                   MONTH(s.ds_checkin)) AS 'total_days',
	   COUNT(*) AS 'total_orders'
FROM searches                                                           AS s
JOIN countries                                                          AS cou
ON s.origin_country = cou.code
JOIN contacts                                                           AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0
GROUP BY s.ds_checkin
ORDER BY year, month,'total_orders' -- 2014: Q4, 2015: 1 - 10 | 22507

-- How many orders after filter:
SELECT s.ds,
       c.ts_contact_at,
	   DATEDIFF(DAY, s.ds, c.ts_contact_at)                     AS 'ds_contact', -- 16984
	   AVG(DATEDIFF(DAY, s.ds, c.ts_contact_at))  OVER()        AS 'avg_ds_contact',
	   c.ds_checkin,									        
	   DATEDIFF(DAY, c.ts_contact_at, c.ds_checkin)             AS 'contact_checkin', -- 22507
	   AVG(DATEDIFF(DAY, c.ts_contact_at, c.ds_checkin)) OVER() AS 'avg_contact_checkin',
	   DATEDIFF(DAY, s.ds, c.ds_checkin)                        AS 'ds_checkin', -- 22181
	   AVG(DATEDIFF(DAY, s.ds, c.ds_checkin)) OVER()            AS 'avg_ds_checkin'
FROM searches                                                   AS s
JOIN countries                                                  AS cou
ON s.origin_country = cou.code						            
JOIN contacts                                                   AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0 -- >0 + =0 + <0 | 9499 + 7485 + 5523 = 22507
ORDER BY ds_contact

-- How many days from ds to contact and from contact to checkin:
-- ds_contact - MIN: 0, MAX: 122, AVG: 5| contact_checkin - MIN: 0, MAX: 383, AVG: 35 |
-- ds_checkin - MIN: 0, MAX: 385, AVG: 41

-- PCT AVG ds vs contact_checkin:
SELECT FORMAT((5523 * 1.0 / 22507) * 100, 'N0') AS 'pct_days' -- >0 + =0 + <0 | 42% + 33% + 25%

-- Validation:
SELECT s.ds,
       c.ts_contact_at,
	   DATEDIFF(DAY, s.ds, c.ts_contact_at)         AS 'ds_contact', -- 16984
	   c.ds_checkin,
	   DATEDIFF(DAY, c.ts_contact_at, c.ds_checkin) AS 'contact_checkin', -- 22507
	   DATEDIFF(DAY, s.ds, c.ds_checkin)            AS 'ds_checkin' -- 22181
FROM searches                                       AS s
JOIN countries                                      AS cou
ON s.origin_country = cou.code
JOIN contacts                                       AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0 
                          AND DATEDIFF(DAY, c.ts_contact_at, c.ds_checkin) >= 0
                          AND DATEDIFF(DAY, s.ds, c.ds_checkin) >= 0 

-- Conclusion for countries:
WITH total_cte AS
(SELECT cou.name                                                                        AS 'country',
        COUNT(s.id_user)                                                                AS 'total_searches'
 FROM searches                                                                          AS s
 JOIN countries                                                                         AS cou
 ON s.origin_country = cou.code						                                    
 JOIN contacts                                                                          AS c
 ON s.id_user = c.id_guest
 WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0															    
 GROUP BY cou.name)																	    
 SELECT SUM (total_searches)                                                            AS 'total_orders',
        AVG(total_searches)                                                             AS 'AVG_orders',
	    FORMAT(ROUND((AVG(total_searches) * 1.0/ SUM (total_searches)) * 100, 2), 'N2') AS 'avg pct'
FROM total_cte

-- The TOP 5 countries with the highest number of orders: 
SELECT TOP 5 cou.name                                                               AS 'country',
	   COUNT(s.ds_checkin)                                                          AS 'num_orders',
	   FORMAT((COUNT(s.id_user) * 1.0 / SUM(COUNT(s.id_user)) OVER ()) * 100, 'N2') AS 'pct'
FROM searches                                                                       AS s
JOIN countries                                                                      AS cou
ON s.origin_country = cou.code					                                    
JOIN contacts                                                                       AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
GROUP BY cou.name
ORDER BY num_orders DESC, country

-- The top countries with the highest number of searchers:
SELECT TOP 5 cou.name                                                               AS 'country',
       COUNT(s.id_user)                                                             AS 'num_searches',
	   FORMAT((COUNT(s.id_user) * 1.0 / SUM(COUNT(s.id_user)) OVER ()) * 100, 'N2') AS 'pct'
FROM searches                                                                       AS s 
JOIN countries                                                                      AS cou 
ON s.origin_country = cou.code
WHERE estimated_time >= 0
GROUP BY cou.name
ORDER BY num_searches DESC, country

-- Conclusion:
-- total searches: 23865, AVG: 198, AVG PCT: 0.83%
-- total orders: 16984, AVG: 249, AVG PCT: 1.47%

-- Which countries did an order?
SELECT c2.country,
       c2.num_searches,
	   c1.num_orders,
	   FORMAT(ROUND((c1.num_orders * 1.0 / c2.num_searches) * 100,0),'N0')                       AS'orders_pct',
	   c1.num_orders - c2.num_searches                                                           AS 'diff',
	   FORMAT(ROUND(((c1.num_orders - c2.num_searches) * 1.0 / c2.num_searches) * 100, 0), 'N0') AS 'diif_pct'
FROM (SELECT TOP 5 cou.name                                                                      AS 'country',
             COUNT(s.id_user)                                                                    AS 'num_searches'
      FROM searches                                                                              AS s 
      JOIN countries                                                                             AS cou 
      ON s.origin_country = cou.code
      WHERE estimated_time >= 0
      GROUP BY cou.name
      ORDER BY num_searches DESC, country) AS c2
JOIN (SELECT TOP 5 cou.name                AS 'country',
             COUNT(s.ds_checkin)           AS 'num_orders'
       FROM searches                       AS s
       JOIN countries                      AS cou
       ON s.origin_country = cou.code		                                    
       JOIN contacts                       AS c
       ON s.id_user = c.id_guest
       WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
       GROUP BY cou.name
       ORDER BY num_orders DESC, country) AS c1
ON c1.country = c2.country
ORDER BY num_orders DESC -- USA, UK, Italy, France, Ireland

-- The top countries with the most orders but few searches:
SELECT c2.country,
       c2.num_searches,
       c1.num_orders,
       FORMAT(ROUND((c1.num_orders * 1.0 / c2.num_searches) * 100,0),'N0')                       AS 'orders_pct',
       c1.num_orders - c2.num_searches                                                           AS 'diff',
       ROUND(((c1.num_orders - c2.num_searches) * 1.0 / c2.num_searches) * 100, 0)               AS 'diff_pct'
FROM (SELECT cou.name                                                                            AS 'country',
             COUNT(s.id_user)                                                                    AS 'num_searches'
      FROM searches                                                                              AS s 
      JOIN countries                                                                             AS cou 
	  ON s.origin_country = cou.code
      WHERE estimated_time >= 0
      GROUP BY cou.name) AS c2
JOIN (SELECT cou.name                                                                            AS 'country',
             COUNT(s.ds_checkin)                                                                 AS 'num_orders'
      FROM searches                                                                              AS s
      JOIN countries                                                                             AS cou 
	  ON s.origin_country = cou.code		                                    
      JOIN contacts                                                                              AS c 
	  ON s.id_user = c.id_guest
      WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0
      GROUP BY cou.name) AS c1
ON c1.country = c2.country
ORDER BY diff_pct DESC

---------------------------------------------------------------------------------------------------------------------
SELECT s.ds,
       s.id_user,
	   s.ds_checkin AS 'search_chechin',
	   cou.name     AS 'country',
	   c.ds_checkin AS 'contact_checkin'
FROM searches       AS s
JOIN countries      AS cou
ON s.origin_country = cou.code
JOIN contacts       AS c
ON s.id_user = c.id_guest
WHERE estimated_time >= 0 AND s.id_user = '14078334-98a6-461a-9214-513ef8e6ff4e' -- חיפש 6 פעמים אבל היו לו רק 2 צק אין

-- DISTINCT 
 -- כמות החיפושים הממוצעת לכל אדפ + כמו ההזמנות הממוצעת

SELECT s.ds,
       s.ds_checkin AS 's_checkin',
       c.ts_contact_at,
	   c.ds_checkin,
       s.estimated_time
FROM searches       AS s
JOIN countries      AS cou
ON s.origin_country = cou.code
JOIN contacts       AS c
ON s.id_user = c.id_guest
-- WHERE estimated_time >= 0 AND DATEDIFF(DAY, s.ds, c.ts_contact_at) >= 0 -- 16984

-- Orders:
SELECT AVG(s.estimated_time) AS 'avg_days'
FROM searches                AS s
JOIN countries               AS cou
ON s.origin_country          = cou.code
JOIN contacts                AS c
ON s.id_user = c.id_guest

-- Searches:
SELECT AVG(estimated_time) AS 'avg_days'
FROM searches

-- s.ds - c.checkin

SELECT *
FROM contacts

SELECT c.id_guest,
       s.ds,
       c.ds_checkin,
	   c.ts_booking_at
FROM searches AS S
JOIN countries               AS cou
ON s.origin_country = cou.code
JOIN contacts                AS c
ON s.id_user = c.id_guest

SELECT CAST(ts_booking_at AS datetime)
FROM contacts
'Primary and secondery questions'

1. 'Identify the top 3 and bottom 3 citites by total trips over
 the entire analysis period'
 
(
select c.city_name ,
      count(t.trip_id) as totaltrips          
from fact_trips t
join dim_city c on c.city_id = t.city_id
join dim_date d on d.date=t.date
group by 1
order by count(t.trip_id) desc
limit 3)
union
(select c.city_name ,
      count(t.trip_id) as totaltrips 
from fact_trips t
join dim_city c on c.city_id = t.city_id
join dim_date d on d.date=t.date
group by 1
order by count(t.trip_id) asc
limit 3)

2.' Average Fare Per Trip by city
 Calculate the avg fare per trip for each city and compare it with the city’s avg trip distance. identify the cities
 with the highest and lowest avg fare per trip to assess pricing efficiency across location'
 
 select c.city_name,count(t.trip_id) as total_trips, avg(t.fare_amount) as avg_amount,
       round(avg(t.fare_amount)/round(avg(t.distance_travelled_km),2),2) as 
        avg_fare_per_dis
       from fact_trips t
join dim_city c 
       on c.city_id=t.city_id
group by 1
order by avg(t.distance_travelled_km) desc

3.'Average Rating by city and passenger type
a. Calculate the avg passenger and driver ratings for each city, segmented by passenger type
 b. identify cities with highest and lowest avg ratings'
 
 with cte as
(
select c.city_name,
 t.passenger_type,
 round(avg(t.driver_rating)/2,2)as d_r,
 round(avg(t.passenger_rating)/2,2) as p_r, 
DENSE_RANK() over(
partition by t.passenger_type order by 
round(avg(t.driver_rating)/2,2) desc) 
as prank,
DENSE_RANK() over(
partition by t.passenger_type order by 
round(avg(t.driver_rating)/2,2) asc) 
as brank
from fact_trips t
join dim_city c
    on c.city_id=t.city_id
group by 1 ,2)
select city_name,passenger_type,d_r,p_r,prank from cte
where prank=1 or brank=1
order by passenger_type,prank

4.'Peak and Low Demand Months by city
 Highest demand month and city 
Identify the city and month with highest and lowest demand by total trips'

with totaltrips as (
select c.city_name ,d.month_name ,count(*) as total_trips
       from fact_trips t
join dim_city c on c.city_id = t.city_id
join dim_date d on d.date = t.date
group by 1,2
 ),
 ranked as(
 select city_name, month_name,total_trips,
 rank() 
 over (partition by city_name order by total_trips desc)as 
 rankmax,
rank() 
 over (partition by city_name order by total_trips asc)as 
 rankmin 
 from totaltrips
 )
 select city_name,
 sum(total_trips) as trips,
 max(case when rankmax =1 then month_name end) as highest,
 max(case when rankmax =1 then total_trips end) as highest_value,
 min(case when rankmin=1 then month_name end) as lowest,
 min(case when rankmin=1 then total_trips end) as lowest_value
from ranked
group by 1

5.'Weekend Vs Weekday trip demand by city
 a. Compare the total trips taken on weekdays vs weekends for each city over the 6 month period.
 b. identify cities with strong preference for either weekend or weekday trips to understand demand variations
 '
 with trips as(
select c.city_name ,
d.day_type,
d.month_name,
count(*) as total_trips
from fact_trips t
join dim_city c on c.city_id = t.city_id
join dim_date d on d.date = t.date
group by 1,2,3
)
select city_name,
sum(case when day_type = "weekday" then total_trips else 0 end) as weekday,
sum(case when day_type = "weekend" then total_trips else 0 end) as weekend,
case 
  when sum(case when day_type = "weekday" then total_trips else 0 end) > 
  sum(case when day_type = "weekend" then total_trips else 0 end) then 'weekday preferred' 
else 'weekend preferred'
end as 'preference'
from trips
group by city_name

6.'Repeat passenger frequescy and city contribution analysis
 Identify which cities contribute most to higher frequenceies among repeat passengers
'
with total_repeat_passenger as (
select city_id,
sum(repeat_passenger_count) as repeatcount
from dim_repeat_trip_distribution
group by 1
),
trip_freq_dis as (
select d.city_id,c.city_name,
d.trip_count,
sum(repeat_passenger_count)as passenger_count
from dim_repeat_trip_distribution d
join dim_city c on c.city_id=d.city_id
group by 1,2,3
)
select
 tdf.city_name,
  tdf.trip_count ,
  tdf.passenger_count,
  (tdf.passenger_count/tr.repeatcount)*100 as percentage
  from trip_freq_dis tdf
  join total_repeat_passenger tr on tdf.city_id=tr.city_id
  order by tdf.city_name,tdf.trip_count
  
  7.'a. Monthly target achievement analysis for key metrics
 Evaluate monthly performance against target for total trips'
 
 select f.month_name,f.total_trips,t.targets,
(total_trips-targets)/targets *100 as percentage_diff,
case 
when total_trips > targets then 'exceeds target'
 else 'missed the target'
end as performance
from
(select count(*) as total_trips,
        monthname(date) as month_name 
from  fact_trips
group by monthname(date)) f
join
(select monthname(month) as month_name ,
        sum(total_target_trips) as targets
from targets_db.monthly_target_trips
group by monthname(month))t
on f.month_name=t.month_name
group by f.month_name

' 7b. Monthly target achievement analysis for key metrics
 Evaluate monthly performance against target for new passengers'
 
 select 
monthname(m.month) as monthname,
sum(p.new_passengers) as new_passengers,
sum(m.target_new_passengers) as target_new_passengers,
((sum(p.new_passengers)-sum(m.target_new_passengers) )
/sum(m.target_new_passengers))*100 as per,
case 
   when ((sum(p.new_passengers)-sum(m.target_new_passengers) )
   /sum(m.target_new_passengers))*100 < 0 
 then 'Missed the target'
 else 'exceeded the target'
end as sstatus
from 
trips_db.fact_passenger_summary p
join targets_db.monthly_target_new_passengers m on
m.month = p.month
group by 1

' 7c. Monthly target achievement analysis for key metrics
 Evaluate monthly performance against target for average passenger ratings'
 
 select 
d.city_name,
round(avg(p.passenger_rating)/2,2) as passengers_rating,
round(avg(m.target_avg_passenger_rating)/2,2) as target_rating_passengers,
((sum(p.passenger_rating)-sum(m.target_avg_passenger_rating) )
/sum(m.target_avg_passenger_rating))*100 as per,
case 
   when 
   round(((sum(p.passenger_rating)-sum(m.target_avg_passenger_rating) )
   /sum(m.target_avg_passenger_rating)),2)*100 < 0 then 'Missed the target'
   else 'exceeded the target'
end as Performance
from 
trips_db.fact_trips p
join
 targets_db.city_target_passenger_rating m on m.city_id = p.city_id
join 
trips_db.dim_city d on d.city_id=p.city_id
group by 1

'8a. Highest and Lowest Repeat Passenger Rate(RPR%) by city
 Identify top 2 and bottom 2 cities based on their RPR% for each cities'
 
 select monthname(p.month) as month_name,
       sum(p.total_passengers)as total_passengers ,
	   sum(p.repeat_passengers)as repeat_passengers,
        (sum(p.repeat_passengers)/sum(p.total_passengers))*100 as
        RPR_per
from fact_passenger_summary p
join dim_city c on c.city_id = p.city_id
group by 1
order by RPR_per desc

' 8b. Highest and Lowest Repeat Passenger Rate(RPR%) by Month
 Identify top 2 and bottom 2 cities based on their RPR% for each cities'
 
 with cte as(
select sum(p.total_passengers)as total_passengers ,
	   sum(p.repeat_passengers)as repeat_passengers,
       c.city_name
from fact_passenger_summary p
join dim_city c on c.city_id = p.city_id

group by  c.city_name)
select city_name,total_passengers,repeat_passengers,(repeat_passengers/ total_passengers)*100 as freq
from cte
group by city_name
order by freq desc
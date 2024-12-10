
'business request 1'
'Generate a report that displays the total trips, average fare per km, avg fare per trip and percentage contributipn
 of each city’s trip to the overall trips. this report will help in assessing trip volume, pricing effeciency and each
 city’s contribution to the overall trip count'
 
select c.city_name,
count(t.trip_id) as total_trips, 
avg(t.fare_amount) as avg_amount,
round(avg(t.fare_amount)/round(avg(t.distance_travelled_km),2),2) as 
avg_fare_per_dis ,
(count(t.trip_id)*100/(select count(*) from fact_trips t)) as cont
       from fact_trips t
join dim_city c 
       on c.city_id=t.city_id
group by 1
order by avg(t.distance_travelled_km) desc


'bussiness request 2'
'Generate a report that evaluate the target performance for trips at the monthly and city level. Compare the actual
 total trip with target trips and categories the performance as if actual trip are greater than the target trip the
 “Above target ” else “Below target'
 
'city wise target trips analysis'
(select d.city_name,
f.total_trips,
t.targets,
(total_trips-targets)/targets *100 as percentage_diff,
case 
when total_trips > targets then 'exceeds target' 
else 'missed the target'
end as perfprmance
from
(select  city_id,
        count(*) as total_trips        
from  fact_trips
group by  city_id
) f
join
(select city_id,
        sum(total_target_trips) as targets
from targets_db.monthly_target_trips
group by city_id
)t
on f.city_id= t.city_id
join dim_city d on d.city_id=f.city_id
group by 1,2,3
order by 2,3 desc)

 
'a. month wise trip and targets'

select f.month_name,
f.total_trips,
t.targets,
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



'b. comparing both city and month trip and target trips'
(select d.city_name,
f.month_name,
f.total_trips,
t.targets,
(total_trips-targets)/targets *100 as percentage_diff,
case 
when total_trips > targets then 'exceeds target' else 
'missed the target'
end as performance
from
(select  city_id,
        count(*) as total_trips,
        monthname(date) as month_name 
from  fact_trips
group by  city_id,monthname(date)) f
join
(select city_id,
        monthname(month) as month_name ,
        sum(total_target_trips) as targets
from targets_db.monthly_target_trips
group by city_id, monthname(month))t
on f.month_name=t.month_name and f.city_id= t.city_id
join dim_city d on d.city_id=f.city_id
group by 2,1,3,4)


'business request 3'
"Calculate the percentage of repeat passengers 
who took 2 trip, 3 trip and so on ,upto 10trip"

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



'business request 4'
'Generate a report that calculate the total new passengers for each city and rank them based on theis
 value.identify the top 3 citites with the highest number of new passengers as well as the bottom 3 cities  with
 lowest number of new passenger , categorising them as top 3 and bottom e accordingly'

select c.city_name,
sum( p.new_passengers) as total_new_passengers ,
rank() over (order by sum( p.new_passengers) desc) as
 ranks,
 case when rank() over (order by sum( p.new_passengers) desc) <=3 then 'top 3'
      when rank() over (order by sum( p.new_passengers) desc) >= 8 then 'bottom 3'
      else 'other'
end as rank_category
from fact_passenger_summary p
join dim_city c on c.city_id= p.city_id
group by c.city_name
order by 2 desc

"business request 5"
' Generate a reprot that identifies that month with the highest revenye for each city . for each city , display
 month_name , the revenue amount for that month and the percentage contribution of that months revenue to
 cityes total revenue'

with cityrev as (
select c.city_name ,
monthname(t.date) as months,
sum(t.fare_amount) as totalrev
 from fact_trips t
 join dim_city c on c.city_id = t.city_id
 group by 1,2
 ),
 maxrev as (
 select city_name,max(totalrev) as max_rev 
 from cityrev
 group by city_name
 ),
 totalrevbycity as(
 select c.city_name,
 sum(t.fare_amount)as city_toatlrev
 from fact_trips t
 join dim_city c on c.city_id=t.city_id
 group by c.city_name
 )
 select cr.city_name,
 cr.months,
 cr.totalrev as max_rev_month,
 round((cr.totalrev/tr.city_toatlrev)*100,2)
 as percontibution
 from cityrev cr
 join maxrev mr on cr.city_name = mr.city_name
 and cr.totalrev=mr.max_rev
 join
 totalrevbycity tr on cr.city_name=tr.city_name
 order by percontibution desc ;
 
 "business query 6"
 ' Generate a reprot that identifies Repeat passenger rate by Month level and city level'
 with cte as(
select sum(p.total_passengers)as total_passengers ,
	   sum(p.repeat_passengers)as repeat_passengers,
       c.city_name,monthname(p.month) as monthname
from fact_passenger_summary p
join dim_city c on c.city_id = p.city_id


group by  c.city_name,monthname(p.month))
select city_name,monthname,total_passengers,repeat_passengers,(repeat_passengers/ total_passengers)*100 as freq
from cte
group by city_name,monthname
order by freq desc

 



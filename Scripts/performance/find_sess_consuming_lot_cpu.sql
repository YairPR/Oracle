-- encuentra las sessiones que consumen mas cpu

col program form a30 heading "Program" 
col CPUMins form 99990 heading "CPU in Mins" 
select rownum as rank, a.* 
from ( 
SELECT v.sid, program, v.value / (100 * 60) CPUMins 
FROM v$statname s , v$sesstat v, v$session sess 
WHERE s.name = 'CPU used by this session' 
and sess.sid = v.sid 
and v.statistic#=s.statistic# 
and v.value>0 
ORDER BY v.value DESC) a 
where rownum < 11;

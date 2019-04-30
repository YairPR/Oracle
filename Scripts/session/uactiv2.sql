/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2017
*@Descripcion:             Genera lista de usuarios activos por consumo de cpu load
*@Versión                  2.0
*******************************************************************************************************************/
set linesize 2000
COLUMN username FORMAT A22
col osuser for a18
col event for a35
col username for a17
COLUMN "cpu usage (seconds)"  FORMAT 999,999,999.0000
col program for a20
alter session set nls_Date_format='dd/mm/yyyy hh24:mi:ss';
 
BREAK     ON REPORT
COMPUTE     SUM      LABEL "Grand Total:"     OF cpu_usage_sec     ON REPORT

select s.username,
       t.sid,
       s.serial#,
       s.logon_time,
       s.sql_exec_start, 
--       s.program,
       s.osuser,
       s.sql_id,
       s.event, 
       sum(t.value/100)  cpu_usage_sec,
       round(100*ratio_to_report(sum(t.value/100)) over (), 2) perc
from gv$session s,
     gv$sesstat t,
     gv$statname n
where 
--	s.inst_id = 1 and
      s.status='ACTIVE' and
      n.inst_id = s.inst_id and
      n.name like '%CPU used by this session%' and
      t.inst_id = n.inst_id and
      t.statistic# = n.statistic# and
      t.sid = s.sid and  
      t.inst_id = s.inst_id and
      s.username is not null and
--s.username <> 'FOGLIGHT_MONITOR'
group by s.username,
         s.inst_id,
         t.sid,
         s.serial#,
         s.logon_time,
       s.sql_exec_start, 
--         s.program,
         s.osuser,
         s.sql_id,
        s.event
order by 10 desc;

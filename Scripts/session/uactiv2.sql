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
where s.status='ACTIVE' and
      n.inst_id = s.inst_id and
      n.name like '%CPU used by this session%' and
      t.inst_id = n.inst_id and
      t.statistic# = n.statistic# and
      t.sid = s.sid and  
      t.inst_id = s.inst_id and
      s.username is not null 
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

RESULT:
---------
USERNAME		 SID	SERIAL# LOGON_TIME	    SQL_EXEC_START	OSUSER		   SQL_ID	 EVENT				     CPU_USAGE_SEC	 PERC
----------------- ---------- ---------- ------------------- ------------------- ------------------ ------------- ----------------------------------- ------------- ----------
DT_CTE_SAS		 313	  18831 20/11/2019 19:53:03 22/11/2019 21:10:35 oracle		   8f8cuqdsgyvrr flashback buf free by RVWR		  54698.78	22.54
DS_SASTRA_WEB		2248	   5735 21/11/2019 19:51:05 22/11/2019 19:39:04 oracle		   46wut6dwvckc4 cell single block physical read	  44087.88	18.17
DS_SASTRA_WEB		 262	  15855 21/11/2019 19:51:04 22/11/2019 21:14:49 oracle		   284xca0xdypyg flashback buf free by RVWR		  37407.41	15.42
DS_AWSBDSAS		2188	  52695 20/11/2019 22:17:55 21/11/2019 21:55:46 rdsdb		   7gms8987utt88 log file sequential read		  33725.02	 13.9


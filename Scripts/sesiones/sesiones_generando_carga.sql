/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2017
*@Descripcion:             Genera lista de usuarios activos por consumo de cpu load
*@Versión                  2.0
@version:                  10g,11g +
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
                                 
/*

RESULT:
---------
USERNAME		 SID	SERIAL# LOGON_TIME	    SQL_EXEC_START	OSUSER		   SQL_ID	 EVENT				     CPU_USAGE_SEC	 PERC
----------------- ---------- ---------- ------------------- ------------------- ------------------ ------------- ----------------------------------- ------------- ----------
DT_CTE_SAS		1802	  40910 03/11/2020 12:06:16 06/11/2020 20:52:55 oracle		   2th4bg07qr0cf row cache lock 			 221193.35	87.28
DS_SASCOM_WEB		 490	  56039 06/11/2020 17:07:27 06/11/2020 23:00:43 root		   132cttn0sn1nk latch free				  19286.51	 7.61
DS_SASACU_WEB		1283	  43283 04/11/2020 12:04:17 06/11/2020 23:00:43 root		   8vm8v9cdkfzat cell single block physical read	   4475.94	 1.77
DS_SASACU_WEB		 836	  47280 05/11/2020 13:22:59 06/11/2020 23:00:00 root		   0m5v41tbw6y31 cell single block physical read	   1921.97	  .76
DT_CTE_SAS		1283	  40785 06/11/2020 22:30:29 06/11/2020 22:30:29 dsadm		   20svuaknnnsn2 cell single block physical read	   1731.64	  .68
SYS			1891	  52469 06/11/2020 21:59:37 06/11/2020 22:56:32 oracle		   dnbj35xvvbg1y cell single block physical read	   1128.35	  .45
DS_SASACU_WEB		 425	  64066 06/11/2020 11:59:37 06/11/2020 23:00:33 root		   0r6942mgh62u3 read by other session			    821.98	  .32
DT_CTE_SAS		1736	  25830 06/11/2020 22:18:36 06/11/2020 22:18:36 dsadm		   6v1m7y8p8zy14 cell single block physical read	    675.67	  .27
DS_SASACU_WEB		 814	  41659 06/11/2020 11:58:18 06/11/2020 23:00:04 root		   0r6942mgh62u3 cell single block physical read	    637.58	  .25
DS_SASACU_WEB		1890	  63685 06/11/2020 16:42:18 06/11/2020 23:00:43 root		   av1fj0x53tswp gc current request			    352.13	  .14
DT_CTE_SAS		1315	  15880 06/11/2020 22:43:35 06/11/2020 22:47:39 oracle		   42dhkv4fd7r6c SQL*Net more data from dblink		    211.38	  .08
*/

set role all;
set linesize 2000 pagesize 200 feedback on
col spid format a10
col osuser format a15
col username format a14
col sid format 99999
col serial# format 999999
col module format a20
col kill format a18
col query format a35
col last_call format 9999.99
col status format a10
SELECT /*+ rule */ to_char(sysdate,'hh24:mi:ss') fecha, to_char(s.Logon_Time,'dd/mm/yyyy hh24:mi:ss') Logon_Time,p.spid, s.OsUser, s.UserName, /* (select NOMUSR from usuario where codusr = s.username) uname,*/ s.sid, s.serial#, s.module, decode(sql_hash_value, 0, prev_hash_value, sql_hash_value) hash ,s.status, 'kill -9 '||p.spid kill, LAST_CALL_ET/60 last_call, '@s '||s.sql_address||' '||s.sql_hash_value QUERY, RESOURCE_CONSUMER_GROUP rgr, s.machine, s.Program,  s.action, audsid
  FROM V$Session s , v$process p
 WHERE s.UserName Is Not Null
  AND  s.Status='ACTIVE'
--  AND  s.Status='KILLED'
   AND  p.addr=s.paddr
--   AND s.action like '%PVILLACAMPA%'
--AND  s.username = 'DS_CRMACSELX'
-- AND s.osuser <> 'djara'
--  and module = 'ServicioPLW.exe'
-- AND s.machine like 'j2ee04'
ORDER BY last_call --16 -- -- 9 
--order by logon_time
-- ORDER BY s.sql_address||' '||s.sql_hash_value, machine
/


--What’s in Undo?
SELECT substr(s.sid||','||s.serial#,1,15) SID_SERIAL,
substr(NVL(s.username, 'None'),1,20) orauser,
s.sql_id,
substr(s.program,1,20) program,
substr(r.name,1,20) undoseg,
substr(t.used_ublk * TO_NUMBER(x.value)/1024||'K',1,20) "Undo",
s.status
FROM sys.v_$rollname r,
sys.v_$session s,
sys.v_$transaction t,
sys.v_$parameter x
WHERE s.taddr = t.addr
AND r.usn = t.xidusn(+)
AND x.name = 'db_block_size'
order by s.sql_id
/

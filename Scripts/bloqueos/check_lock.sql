select (select INST_ID || '-' || username || '--' || machine
          from (select xx.INST_ID, sid, username, machine from gv$session xx)
         where a.inst_id = inst_id
           and sid = a.sid) sess,
       a.sid,
       ' is blocking ' ib,
       (select INST_ID || '-' || username || '-' || machine
          from (select xx.INST_ID, sid, username, machine from gv$session xx)
         where b.inst_id = inst_id
           and sid = b.sid) sess,
       b.sid,
       'exec sp_sy_kill(' || a.sid || ',' ||
       (select serial#
          from gv$session x
         where x.inst_id = a.inst_id
           and x.SID = a.SID) || ');' "ParaMatar",
       ' alter system kill session '' ' || to_char(a.sid) || ',' ||
       (select serial#
          from gv$session x
         where x.inst_id = a.inst_id
           and x.SID = a.SID) || ''';' xx
  from (select * from gv$lock) a, (select * from gv$lock) b
 where a.block = 1
   and b.request > 0
   and a.id1 = b.id1
   and a.id2 = b.id2;

   select s.sid, s.serial#, s.username, s.module, s.status, 'alter system kill session ''' || s.sid || ',' || s.serial# || ''' immediate;'
from v$session s, v$process p
where s.paddr = p.addr
and s.sid in (select sid
from gv$access
where owner = 'APP_EPS'
and object = '&Obj_Name')
order by 5,4
;
   
   SELECT O.OBJECT_NAME, S.SID, S.SERIAL#, P.SPID, S.PROGRAM,S.USERNAME,
S.MACHINE,S.PORT , S.LOGON_TIME,SQ.SQL_FULLTEXT 
FROM V$LOCKED_OBJECT L, DBA_OBJECTS O, V$SESSION S, 
V$PROCESS P, V$SQL SQ 
WHERE L.OBJECT_ID = O.OBJECT_ID 
AND L.SESSION_ID = S.SID AND S.PADDR = P.ADDR 
AND S.SQL_ADDRESS = SQ.ADDRESS;


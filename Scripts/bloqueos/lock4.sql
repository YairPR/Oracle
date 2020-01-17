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

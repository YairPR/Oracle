set lines 300 pages 20000
col "Kill_Command" for a60
select gvh.inst_id Inst_id, gvh.sid Locking_SID, gvs.serial# Locking_Serial,
       gvs.status Status, gvs.module Module, gvw.inst_id Inst_w, gvw.sid Waiter_SID,
       decode(gvh.type, 'MR', 'Media recovery',
                        'RT', 'Redo_thread',
                        'UN', 'User_name',
                        'TX', 'Transaction',
                        'TM', 'DML',
                        'UL', 'PLSQL User_Lock',
                        'DX', 'Distrib_tx',
                        'CF', 'Control_File',
                        'IS', 'Instante_state',
                        'FS', 'File_set',
                        'IR', 'Instance_recovery',
                        'ST', 'Diskspace Transaction',
                        'IV', 'Libcache_invalidation',
                        'LS', 'LogStarORswitch',
                        'RW', 'Row_wait',
                        'SQ', 'Sequence_no',
                        'TE', 'Extend_table',
                        'TT', 'Temp_table',
                              'Nothing-') Waiter_lock_type,
       decode(gvh.request, 0, 'None',
                           1, 'NoLock',
                           2, 'Row-Share',
                           3, 'Row-Exclusive',
                           4, 'Share-Table',
                           5, 'Share-Row-Exclusive',
                           6, 'Exclusive',
                              'Nothing-') Waiter_Mode_req,
       'alter system kill session ' || '''' || gvh.sid || ',' || gvs.serial# || ''' immediate;' "Kill_Command"
 from gv$lock gvh, gv$lock gvw, gv$session gvs
where (gvh.id1, gvh.id2) 
           in (select id1, id2 from gv$lock where request = 0
               intersect
               select id1, id2 from gv$lock where lmode = 0)
  and gvh.id1 = gvw.id1
  and gvh.id2 = gvw.id2
  and gvh.request = 0
  and gvw.lmode   = 0
  and gvh.sid     = gvs.sid
  and gvh.inst_id = gvs.inst_id
;

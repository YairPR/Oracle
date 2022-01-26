col Machine for a30
col "SID,SESSION#" for a35
col "USERNAME" for a35
col "OBJECT" for a35
col "OBJECT_TYPE" for a20
col MODE_HELD for a20

select s.sid || ',' || s.serial# "SID,SESSION#"
  ,  oracle_username || ' (' || s.osuser || ')' username
  ,  s.MACHINE "Machine"
  ,  owner || '.' || object_name object
  ,  object_type
  ,  decode( l.block
     ,       0, 'Not Blocking'
     ,       1, 'Blocking'
     ,       2, 'Global') status
  ,  decode(v.locked_mode
    ,       0, 'None'
    ,       1, 'Null'
    ,       2, 'Row-S (SS)'
    ,       3, 'Row-X (SX)'
    ,       4, 'Share'
    ,       5, 'S/Row-X (SSX)'
    ,       6, 'Exclusive', TO_CHAR(lmode)) mode_held
 from       v$locked_object v
 ,  dba_objects d
 ,  v$lock l
 ,  v$session s
 where      v.object_id = d.object_id
 and        v.object_id = l.id1
 and        v.session_id = s.sid
 order by oracle_username,session_id;


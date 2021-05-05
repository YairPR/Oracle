select
    -- Session causing the block
    blockers.blocker_instance_id as blocker_instance_id,
    blocker.sid                  as blocker_sid,
    blocker.serial#              as blocker_serial#,
    blocker.username             as blocker_username,
    blocker.status               as blocker_status,
    blocker.machine              as blocker_machine,
    blocker.program              as blocker_program,
    blocker.sql_id               as blocker_sql_id,
    blocker.sql_child_number     as blocker_sql_child_number,
    blocker.prev_sql_id          as blocker_prev_sql_id,
    blocker.prev_child_number    as blocker_prev_child_number,
    ' -> '                       as is_blocking,
    -- Sesssion being blocked
    blocked.sid                  as blocked_sid,
    blocked.serial#              as blocked_serial#,
    blocked.username             as blocked_username,
    blocked.status               as blocked_status,
    blocked.machine              as blocked_machine,
    blocked.program              as blocked_program,
    blocked.blocking_session     as blocked_blocking_session,
    blocked.sql_id               as blocked_sql_id,
    blocked.sql_child_number     as blocked_sql_child_number,
    sys_obj.name                 as blocked_table_name,
    dbms_rowid.rowid_create(
        rowid_type    => 1,
        object_number => blocked.row_wait_obj#,
        relative_fno  => blocked.row_wait_file#,
        block_number  => blocked.row_wait_block#,
        row_number    => blocked.row_wait_row#
    )                            as blocked_rowid,
    blockers.wait_id             as blocked_wait_id,
    blockers.wait_event          as blocked_wait_event,
    blockers.wait_event_text     as blocked_wait_event_text,
    ----- blockers.con_id              as data_container_id,
    -- Blocker * Blocked SQL Text
    blocker_sql.sql_text         as blocker_sql_text,
    blocker_prev_sql.sql_text    as blocker_prev_sql_text,
    blocked_sql.sql_text         as blocked_sql_text
from v$session_blockers blockers
    inner join v$session blocker
    on blocker.sid = blockers.blocker_sid
    and blocker.serial# = blockers.blocker_sess_serial#
    inner join v$session blocked
    on blocked.sid = blockers.sid
    and blocked.serial# = blockers.sess_serial#
    inner join sys.obj$ sys_obj
    on sys_obj.obj# = blocked.row_wait_obj#
    left outer join v$sql blocked_sql
    on blocked_sql.sql_id = blocked.sql_id
    and blocked_sql.child_number = blocked.sql_child_number
    left outer join v$sql blocker_sql
    on blocker_sql.sql_id = blocker.sql_id
    and blocker_sql.child_number = blocker.sql_child_number
    left outer join v$sql blocker_prev_sql
    on blocker_prev_sql.sql_id = blocker.prev_sql_id
    and blocker_prev_sql.child_number = blocker.prev_child_number
where blocked.status = 'ACTIVE';

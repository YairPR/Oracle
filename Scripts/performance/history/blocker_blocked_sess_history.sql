select distinct
    -- Snapshot ID
    min(blocked.snap_id)      as first_snap_id,
    max(blocked.snap_id)      as last_snap_id,

    -- Sample ID and Time
    min(blocked.sample_id)    as first_sample_id,
    min(blocked.sample_id)    as last_sample_id,
    to_char(
        min(blocked.sample_time),
        'YYYY-MM-DD HH24:MI:SS'
    )                         as first_sample_time,
    to_char(
        max(blocked.sample_time),
        'YYYY-MM-DD HH24:MI:SS'
    )                         as last_sample_time,

    -- Session causing the block
    blocker.instance_number   as blocker_instance_number,
    blocker.machine           as blocker_machine,
    blocker.program           as blocker_program,
    blocker.session_id        as blocker_sid,
    blocker_user.username     as blocker_username,

    ' -> '                    as is_blocking,

    -- Sesssion being blocked
    blocked.instance_number   as blocked_instance_number,
    blocked.machine           as blocked_machine,
    blocked.program           as blocked_program,
    blocked.session_id        as blocked_sid,
    blocked_user.username     as blocked_username,
    blocked.session_state     as blocked_session_state,
    blocked.event             as blocked_event,
    blocked.blocking_session  as blocked_blocking_session,
    blocked.sql_id            as blocked_sql_id,
    blocked.sql_child_number  as blocked_sql_child_number,
    sys_obj.name              as blocked_table_name,
    dbms_rowid.rowid_create(
        rowid_type    => 1,
        object_number => blocked.current_obj#,
        relative_fno  => blocked.current_file#,
        block_number  => blocked.current_block#,
        row_number    => blocked.current_row#
    )                         as blocked_rowid,
    blocked_sql.sql_text      as blocked_sql_text
from
    dba_hist_active_sess_history blocker
    inner join
    dba_hist_active_sess_history blocked
        on blocker.session_id = blocked.blocking_session
        and blocker.session_serial# = blocked.blocking_session_serial# 
    inner join
    sys.obj$ sys_obj
        on sys_obj.obj# = blocked.current_obj#
    inner join
    dba_users blocker_user
        on blocker.user_id = blocker_user.user_id
    inner join
    dba_users blocked_user
        on blocked.user_id = blocked_user.user_id
    left outer join
    v$sql blocked_sql
        on blocked_sql.sql_id = blocked.sql_id
        and blocked_sql.child_number = blocked.sql_child_number
    left outer join
    v$sql blocker_sql
        on blocker_sql.sql_id = blocker.sql_id
        and blocker_sql.child_number = blocker.sql_child_number
where
    blocked.snap_id between BEGIN_SNAP_ID and END_SNAP_ID
and
    blocked.event = 'enq: TX - row lock contention'
group by
    blocker.instance_number,
    blocker.machine,
    blocker.program,
    blocker.session_id,
    blocker_user.username,
    ' -> ',
    blocked.instance_number,
    blocked.machine,
    blocked.program,
    blocked.session_id,
    blocked_user.username,
    blocked.session_state,
    blocked.event,
    blocked.blocking_session,
    blocked.sql_id,
    blocked.sql_child_number,
    sys_obj.name,
    dbms_rowid.rowid_create(
        rowid_type    => 1,
        object_number => blocked.current_obj#,
        relative_fno  => blocked.current_file#,
        block_number  => blocked.current_block#,
        row_number    => blocked.current_row#
    ),
    blocker_sql.sql_text,
    blocked_sql.sql_text
order by
    first_sample_id;

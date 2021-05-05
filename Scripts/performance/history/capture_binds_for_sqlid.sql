select
    snap_id,
    sql_id,
    name,
    position,
    datatype_string,
    to_char(last_captured,'YYYY-MM-DD HH24:MI:SS') last_captured,
    value_string
from
    dba_hist_sqlbind
where
    sql_id = '&sql_id'
and
    value_string is not null
order by
    snap_id,
    last_captured,
    position;

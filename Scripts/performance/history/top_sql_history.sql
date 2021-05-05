select
    *
from
(
    select
        ss.module,
        ss.snap_id,
        ss.sql_id,
        ss.plan_hash_value,
        ss.executions_total,
        case
        when ss.elapsed_time_total > 0 then
            ss.elapsed_time_total/1000
        else
            0
        end elapsed_time_ms,
        case
        when ss.executions_total > 0 then
            round(ss.elapsed_time_total/nvl(ss.executions_total, 1)/1000, 2)
        else
            0
        end elapsed_time_per_exec_ms,
        ss.rows_processed_total,
        ss.px_servers_execs_total,
        ss.sorts_total,
        ss.invalidations_total,
        ss.parse_calls_total,
        ss.buffer_gets_total,
        ss.disk_reads_total,
        ss.optimizer_mode,
        ss.sql_profile,
        to_char(substr(st.sql_text,1,4000)) sql_text
    from
        dba_hist_sqlstat ss
        inner join
        dba_hist_sqltext st
            on ss.sql_id = st.sql_id
    order by
        elapsed_time_per_exec_ms desc
)
where
    rownum <= 50

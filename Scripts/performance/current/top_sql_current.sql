select
    *
from
(
    select
        module,
        sql_id,
        child_number,
        plan_hash_value,
        executions,
        case
        when elapsed_time > 0 then
            elapsed_time/1000
        else
            0
        end elapsed_time_ms,
        case
        when executions > 0 then
            round(elapsed_time/nvl(executions, 1)/1000, 2)
        else
            0
        end elapsed_time_per_exec_ms,
        rows_processed,
        px_servers_executions,
        sorts,
        invalidations,
        parse_calls,
        buffer_gets,
        disk_reads,
        optimizer_mode,
        is_bind_sensitive,
        is_bind_aware,
        is_shareable,
        sql_profile,
        sql_plan_baseline,
        sql_text
    from
        v$sql
    order by
        elapsed_time_per_exec_ms desc
)
where
    rownum <= 50

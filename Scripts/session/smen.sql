PROMPT Display session &1 memory usage from v$process_memory....
SELECT
    s.sid,pm.*
FROM 
    v$session s
  , v$process p
  , v$process_memory pm
WHERE
    s.paddr = p.addr
AND p.pid = pm.pid
AND s.sid IN (&1)
ORDER BY
    sid
  , category
/


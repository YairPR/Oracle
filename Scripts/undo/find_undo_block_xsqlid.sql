--Find undo blocks and connect by SQL_ID
select dhs.sql_id, round(sum((vu.activeblks*8)/1024)) ActiveUNDOMB, round(max((vu.unexpiredblks*8)/1024)) UnexpiredUNDOMB ,max(vu.tuned_undoretention)TunedUndo, max(vu.begin_time)newest_time
from v$undostat vu , dba_hist_sqltext dhs
where vu.maxqueryid=dhs.sql_id
group by sql_id

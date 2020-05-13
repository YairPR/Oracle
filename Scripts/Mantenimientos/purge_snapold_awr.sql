How to purge old AWR snapshots
Show AWR snapshot list

set line 1000
SELECT snap_id, begin_interval_time, end_interval_time
FROM sys.wrm$_snapshot
ORDER BY snap_id
Purge snapshot between snapid 54832 to 54892

EXECUTE dbms_workload_repository.drop_snapshot_range(low_snap_id =>54832 , high_snap_id =>54892);

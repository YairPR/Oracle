variable snapshots_purged number;
declare
        v_lo_snap stats$snapshot.snap_id%type;
        v_hi_snap stats$snapshot.snap_id%type;
	v_snapshots_purged number;
	v_dbid v$database.dbid%type;
	v_instance_number v$instance.instance_number%type;
begin
	select d.dbid, i.instance_number into v_dbid, v_instance_number 
	from v$database d,
       		v$instance i;

        select min(s.snap_id) min_snap_id, max(s.snap_id) max_snap_id into v_lo_snap, v_hi_snap
          from stats$snapshot s
             , stats$database_instance di
         where di.startup_time     = s.startup_time and s.snap_time < sysdate-30;

        :snapshots_purged := statspack.purge( i_begin_snap      => v_lo_snap
                                      , i_end_snap        => v_hi_snap
                                      , i_snap_range      => true
                                      , i_extended_purge  => false
                                      , i_dbid            => v_dbid
                                      , i_instance_number => v_instance_number);
end;
/

@last

 select 'Last applied  : ' Logs, to_char(next_time,'DD-MON-YY:HH24:MI:SS') Time
    from v$archived_log
    where sequence# = (select max(sequence#) from v$archived_log where applied='YES')
    union
    select 'Last received : ' Logs, to_char(next_time,'DD-MON-YY:HH24:MI:SS') Time
    from v$archived_log
   where sequence# = (select max(sequence#) from v$archived_log);
   
   
 @dg_stats
 set line 300
 column value format a50
 select
    NAME Name,
    VALUE Value,
    UNIT Unit
    from v$dataguard_stats
    union
    select null,null,' ' from dual
    union
    select null,null,'Time Computed: '||MIN(TIME_COMPUTED)
   from v$dataguard_stats;
   
   @last_redo
   select to_char(max(last_time),'DD-MON-YYYY HH24:MI:SS') "Redo onsite"
     from v$standby_log

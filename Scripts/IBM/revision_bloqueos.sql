#### A parte de los scripts en /Oracle/Scripts/bloqueos
/* NOta:
This script presented few performance challenges because a self-join query against gv$lock joined with sys.obj$ to 
get a list of blocked objects is very expensive in a cluster environment, in fact it’s expensive even in a single 
instance environment. We also have to join gv$session with a result of self-join query against gv$lock in order to 
get the SQL_TEXT of the sessions doing blocking and being blocked – that’s extremely slow as well.

To solve the above performance challenges I created two tables and indexed them appropriately:

GV$ Table	COPY Table	Indexed Columns
gv$lock	gv_lock_mon	type,block
gv$session	gv_session_mon	inst_id,sid
 
Once that was done it was a simple matter of replacing GV$ Table name with COPY Table name on the key joins and performance shot up through 
the roof. In fact, it was so lightweight that I created a custom event in my monitoring system and started to trap occurrences of these DB 
blocks for historical purposes so that when a developer came to our team and asked us if there were any DB locks/blocks 3 hours ago we could 
simply review our alerts and answer that question with authority providing exact details on the race condition that caused these blocks. 
This was much more helpful then the generic alert email we’d get from OEM stating that session XYZ is blocking this many sessions on instances 
1,4 and 5 for example.
*/
--- Header: $Id: locks.sql 31 2015-12-09 21:50:22Z mve $
--- Copyright 2015 HASHJOIN (http://www.hashjoin.com/). All Rights Reserved.
---
--- HISTORY:
--   2013-Nov-19	VMOGILEVSKIY	Added CLIENT_INFO
--   2013-Nov-22	VMOGILEVSKIY	Switched to separate batch_id for LOCKS and SESS (see mon_refresh_proc)


/*
called by drilllock.sh

$EVNT_TOP/seed/sql/s_locked_obj.sql :l_lock_batch_id :l_sess_batch_id

NOTE: this versions is pulled from EVNT and refactored to use it's own gv_ tables instead of repository's

*/


set term off
create table gv_lock_mon as select * from gv$lock where 1=2;
create index gv_lock_mon_indx on gv_lock_mon(type,block);
truncate table gv_lock_mon;

insert into gv_lock_mon
select * from  gv$lock;

create table gv_session_mon as select x.*, x.sql_address sql_address_mon, x.sql_hash_value sql_hash_value_mon from gv$session x where 1=2;
create index gv_session_mon_indx on gv_session_mon(inst_id,sid);
truncate table gv_session_mon;

insert into gv_session_mon
select l.*,
      decode(rawtohex(sql_address),'00',prev_sql_addr,sql_address),
      decode(sql_hash_value,0,prev_hash_value,sql_hash_value)
from gv$session l;

commit;

set term on


ttitle off
clear col
set verify off
set serveroutput on size 1000000
set echo off
set lines 132
set trims on


set feed on
set term on

prompt blocked objects from GV$LOCK and SYS.OBJ$
set lines 132
col BLOCKED_OBJ format a35 trunc

select /*+ ORDERED */
    l.inst_id
,   l.sid
,   l.lmode
,   TRUNC(l.ctime/60) min_blocked
,   u.name||'.'||o.NAME blocked_obj
from (select *
      from gv_lock_mon
      where type='TM'
        and block!=0) l
,     sys.obj$ o
,     sys.user$ u
where o.obj# = l.ID1
and   o.OWNER# = u.user#
and   l.ctime > 10
and   l.sid >= 1
order by 1,2;


prompt blocked sessions from GV$LOCK

select /*+ ORDERED */
   blocker.inst_id
,  blocker.sid blocker_sid
,  blocked.inst_id
,  blocked.sid blocked_sid
,  TRUNC(blocked.ctime/60) min_blocked
,  blocked.request
from (select *
      from gv_lock_mon
      where block != 0
      and type = 'TX')  blocker
,    gv_lock_mon        blocked
where blocked.type='TX'
and blocked.block = 0
and blocked.id1 = blocker.id1;

prompt blocked session details from GV$SESSION and GV$SQLTEXT

clear col
clear breaks
set lines 80
set trims on
set pages 9000
col sql_text format a70 word_wrapped
col inst_id format a10 noprint new_value n_inst_id
col sid format a10 noprint new_value n_sid
col serial format a10 noprint new_value n_serial
col username format a20 noprint new_value n_username
col machine format a20 noprint new_value n_machine
col osuser format a20 noprint new_value n_osuser
col process format a20 noprint new_value n_process
col action format a45 noprint new_value n_action
col SQL_ID format a13 noprint new_value n_SQL_ID
col PREV_SQL_ID format a13 noprint new_value n_PREV_SQL_ID
col display_sql_id format a13 noprint new_value n_display_sql_id
col CLIENT_INFO format a64 noprint new_value n_CLIENT_INFO


break on sid on serial on username on process on machine on action skip page

ttitle -
       "Instance........ : "  n_inst_id -
      skip 1 -
       "Sid ............ : "  n_sid -
      skip 1 -
       "Serial ......... : "  n_serial -
      skip 1 -
       "Username ....... : "  n_username -
      skip 1 -
       "SQL Id ......... : "  n_SQL_ID -
      skip 1 -
       "Prev SQL Id .... : "  n_PREV_SQL_ID -
      skip 1 -
       "Displayed SQL Id : "  n_display_sql_id -
      skip 1 -
       "Client Info .... : "  n_CLIENT_INFO -
      skip 1 -
       "Machine ........ : "  n_machine -
      skip 1 -
       "OSuser ......... : "  n_osuser -
      skip 1 -
       "Process ........ : "  n_process -
      skip 1 -
       "Action ......... : "  n_action -

select /*+ ORDERED */
   ses.inst_id,sid,serial# serial,username,machine,osuser,process,module||' '||action action,sql_text,
   nvl(ses.SQL_ID,'null') SQL_ID,
   nvl(ses.PREV_SQL_ID,'null') PREV_SQL_ID,
   nvl(txt.SQL_ID,'null') display_sql_id,
   nvl(ses.CLIENT_INFO,'null') CLIENT_INFO
--from gv$session ses, gv$sqltext txt
from gv_session_mon ses, gv$sqltext_with_newlines txt
where txt.address(+) = ses.sql_address_mon
and   txt.hash_value(+) = ses.sql_hash_value_mon
and   txt.inst_id(+) = ses.inst_id
and   (ses.inst_id,ses.sid)
            IN (select /*+ ORDERED */
                --   blocker.inst_id
                --,  blocker.sid blocker_sid
                   blocked.inst_id
                ,  blocked.sid blocked_sid
                from (select *
                      from gv_lock_mon
                      where block != 0
                      and type = 'TX')  blocker
                ,    gv_lock_mon        blocked
                where blocked.type='TX'
                and blocked.block = 0
                and blocked.id1 = blocker.id1)
order by inst_id,sid,piece;


prompt blocker session details from GV$SESSION and GV$SQLTEXT (current or previous SQL)

select /*+ ORDERED */
   ses.inst_id,sid,serial# serial,username,machine,osuser,process,module||' '||action action,sql_text,
   nvl(ses.SQL_ID,'null') SQL_ID,
   nvl(ses.PREV_SQL_ID,'null') PREV_SQL_ID,
   nvl(txt.SQL_ID,'null') display_sql_id,
   nvl(ses.CLIENT_INFO,'null') CLIENT_INFO
--from gv$session ses, gv$sqltext txt
from gv_session_mon ses, gv$sqltext_with_newlines txt
where txt.address(+) = ses.sql_address_mon
and   txt.hash_value(+) = ses.sql_hash_value_mon
and   txt.inst_id(+) = ses.inst_id
and   (ses.inst_id,ses.sid)
            IN (select /*+ ORDERED */
                   blocker.inst_id
                ,  blocker.sid blocker_sid
                --   blocked.inst_id
                --,  blocked.sid blocked_sid
                from (select *
                      from gv_lock_mon
                      where block != 0
                      and type = 'TX')  blocker
                ,    gv_lock_mon        blocked
                where blocked.type='TX'
                and blocked.block = 0
                and blocked.id1 = blocker.id1)
order by inst_id,sid,piece;

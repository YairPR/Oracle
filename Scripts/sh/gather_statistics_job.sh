#!/bin/bash

########################################################################################
# SCRIPT NAME: gather_statistics.sh
# Created By   Diana Robete
# Copyright:   @2017 dbaparadise.com
#
# Script to gather statistics for a specific database
#
# ./gather_statistics.sh ORACLE_SID
#############################################################
export ORATAB=/etc/oratab
export PATH=/usr/local/bin:$PATH

##you can capture other information you might need here, such as hostname, logfile
#export LOGFILE=path_to_logfile

# Check parameters 

if [ $# -eq 0 ]; then
    echo $#
    echo "usage: $0 [SID] "
    exit 1
fi

export SID=${1}

#Verify that ORACLE_SID is valid, if not in oratab, exit

if [ "`cat ${ORATAB} |grep -v '^#'|cut -f '1' -d:|grep "\<${SID}\>"`" ]; then
    ## set the environment here, with whatever method you use (oraenv, or your own script)
else
   echo "Wrong ORACLE SID specified "
   exit 99
fi

# Disable default stats job

disable_default_job () {
${ORACLE_HOME}/bin/sqlplus -s /nolog << -ENDOFMARK00 > /dev/null
connect / as sysdba
whenever sqlerror exit -1
set feedback off echo off heading off trimspool off termout off pagesize 0

select to_number('Error') from dba_autotask_client
where client_name='auto optimizer stats collection'
and status='DISABLED';

BEGIN
  DBMS_AUTO_TASK_ADMIN.disable(
    client_name => 'auto optimizer stats collection',
    operation   => NULL,
    window_name => NULL);
end;
/
-ENDOFMARK00

#Verify if any errors

if [ $? != 0 ]; then
 echo_msg "Auto Task:auto optimizer stats collection, already disabled. Continuing stats collection."
else
 echo_msg "Auto Task:auto optimizer stats collection, has been disabled. Continuing stats collection."
fi

}

gather_stats () {
${ORACLE_HOME}/bin/sqlplus -s /nolog << -ENDOFMARK01 >> ${LOGFILE}
connect / as sysdba
set linesize 180
set serveroutput on size unlimited format word_wrapped

DECLARE
  l_objlist dbms_stats.objecttab;
  l_granularity varchar2(20);
  l_num_rows number;
  l_dbname varchar2(8) := sys_context('USERENV','DB_NAME');
  l_estimate_percent varchar2(28);
  l_method_opt varchar2(40);
  l_end_time number;
  l_start_time number;
BEGIN
  BEGIN
     l_start_time :=dbms_utility.get_time;
     dbms_output.put_line('-------------------------------');
     dbms_output.put_line('GATHER STATS ON DATA DICTIONARY');
     dbms_output.put_line('-------------------------------');
     execute immediate 'begin dbms_stats.gather_dictionary_stats; end;';
     l_end_time:=dbms_utility.get_time;
     dbms_output.put_line('dbms_stats.gather_dictionary_stats;' || '      ' || (l_end_time-l_start_time)/100 || 'sec' );
     l_start_time :=0;
     l_end_time   :=0;
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;
  dbms_stats.gather_database_stats(OPTIONS=>'LIST STALE',OBJLIST=>l_objlist);
  dbms_output.put_line('----------------------------------------');
  dbms_output.put_line('GATHER STATS ON OBJECTS WITH STALE STATS');
  dbms_output.put_line('----------------------------------------');
  FOR i in 1 .. l_objlist.count LOOP
    IF l_objlist(i).ownname not in ('SYS','SYSTEM') THEN
      IF l_objlist(i).objType = 'TABLE' THEN
        l_granularity := 'GLOBAL';
        l_estimate_percent := dbms_stats.auto_sample_size;
        l_method_opt  := 'FOR ALL COLUMNS SIZE AUTO';
        IF l_objlist(i).PartName is not NULL THEN l_granularity := 'PARTITION'; END IF;
        IF l_objlist(i).subpartname is not NULL THEN CONTINUE; END IF;
        # If you need any customizations for specific tables, you can include here
       BEGIN
          l_start_time :=dbms_utility.get_time;
          dbms_stats.gather_table_stats(l_objlist(i).ownname,tabname=>'"' || l_objlist(i).objName || '"',partname=> '"' || l_objlist(i).PartName || '"',estimate_percent=>l_estimate_percent, granularity=> l_granularity, method_opt=>l_method_opt);
          l_end_time:=dbms_utility.get_time;
          dbms_output.put_line('exec dbms_stats.gather_table_stats('''||l_objlist(i).ownname|| ''',tabname=>''"' ||l_objlist(i).objName|| '"'',partname=>''"'|| l_objlist(i).PartName||'"'', estimate_percent=>'|| l_estimate_percent||',granularity=>'''||l_granularity||''', method_opt=>'''||l_method_opt||''');'|| '     ' || (l_end_time-l_start_time)/100 || 'sec' );
          l_estimate_percent := dbms_stats.auto_sample_size;
          l_granularity := 'GLOBAL';
          l_method_opt := 'FOR ALL COLUMNS SIZE AUTO';
          l_start_time :=0;
          l_end_time :=0;
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line(rpad(l_objlist(i).ownname,20)||rpad(l_objlist(i).objName,24)||rpad(l_objlist(i).PartName,24));
            dbms_output.put_line(substr(sqlerrm,1,180));
        END;
      END IF;
      IF l_objlist(i).objType = 'INDEX' THEN
        l_granularity := 'GLOBAL';
        IF l_objlist(i).PartName is not NULL THEN l_granularity := 'PARTITION'; END IF;
        BEGIN
          l_start_time :=dbms_utility.get_time;
          dbms_stats.gather_index_stats(l_objlist(i).ownname,l_objlist(i).objName,l_objlist(i).PartName,granularity=>l_granularity);
          l_end_time:=dbms_utility.get_time;
          dbms_output.put_line('exec dbms_stats.gather_index_stats('''||l_objlist(i).ownname||''','''||l_objlist(i).objName||''','''||l_objlist(i).PartName||''',granularity=>'''||l_granularity||''');'|| ' ,time > ' || '     ' || (l_end_time-l_start_time)/100 || 'sec');
          l_start_time :=0;
          l_end_time :=0;
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line(rpad(l_objlist(i).ownname,20)||rpad(l_objlist(i).objName,24)||rpad(l_objlist(i).PartName,24));
            dbms_output.put_line(substr(sqlerrm,1,250));
        END;
      END IF;
    END IF;
  END LOOP;
dbms_stats.gather_database_stats(OPTIONS=>'LIST EMPTY',OBJLIST=>l_objlist);
dbms_output.put_line('-------------------------------------');
dbms_output.put_line('GATHER STATS ON OBJECTS WITH NO STATS');
dbms_output.put_line('-------------------------------------');
  FOR i in 1 .. l_objlist.count LOOP
    IF l_objlist(i).ownname not in ('SYS','SYSTEM') THEN
      IF l_objlist(i).objType = 'TABLE' THEN
        l_granularity := 'GLOBAL';
        l_estimate_percent := dbms_stats.auto_sample_size;
        l_method_opt  := 'FOR ALL COLUMNS SIZE AUTO';
        IF l_objlist(i).PartName is not NULL THEN l_granularity := 'PARTITION'; END IF;
        IF l_objlist(i).subpartname is not NULL THEN CONTINUE; END IF;
        # If you need any customizations for specific tables, you can include here
       BEGIN
          l_start_time :=dbms_utility.get_time;
          dbms_stats.gather_table_stats(l_objlist(i).ownname,tabname=>'"' || l_objlist(i).objName || '"',partname=> '"' || l_objlist(i).PartName || '"',estimate_percent=>l_estimate_percent, granularity=> l_granularity, method_opt=>l_method_opt);
          l_end_time:=dbms_utility.get_time;
          dbms_output.put_line('exec dbms_stats.gather_table_stats('''||l_objlist(i).ownname|| ''',tabname=>''"' ||l_objlist(i).objName|| '"'',partname=>''"'|| l_objlist(i).PartName||'"'', estimate_percent=>'|| l_estimate_percent||',granularity=>'''||l_granularity||''', method_opt=>'''||l_method_opt||''');'|| '     ' || (l_end_time-l_start_time)/100 || 'sec' );
          l_estimate_percent := dbms_stats.auto_sample_size;
          l_granularity := 'GLOBAL';
          l_method_opt := 'FOR ALL COLUMNS SIZE AUTO';
          l_start_time :=0;
          l_end_time :=0;
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line(rpad(l_objlist(i).ownname,20)||rpad(l_objlist(i).objName,24)||rpad(l_objlist(i).PartName,24));
            dbms_output.put_line(substr(sqlerrm,1,180));
        END;
      END IF;
      IF l_objlist(i).objType = 'INDEX' THEN
        l_granularity := 'GLOBAL';
        IF l_objlist(i).PartName is not NULL THEN l_granularity := 'PARTITION'; END IF;
        BEGIN
          l_start_time :=dbms_utility.get_time;
          dbms_stats.gather_index_stats(l_objlist(i).ownname,l_objlist(i).objName,l_objlist(i).PartName,granularity=>l_granularity);
          l_end_time:=dbms_utility.get_time;
          dbms_output.put_line('exec dbms_stats.gather_index_stats('''||l_objlist(i).ownname||''','''||l_objlist(i).objName||''','''||l_objlist(i).PartName||''',granularity=>'''||l_granularity||''');'|| ' ,time > ' || '     ' || (l_end_time-l_start_time)/100 || 'sec');
          l_start_time :=0;
          l_end_time :=0;
        EXCEPTION
          WHEN OTHERS THEN
            dbms_output.put_line(rpad(l_objlist(i).ownname,20)||rpad(l_objlist(i).objName,24)||rpad(l_objlist(i).PartName,24));
            dbms_output.put_line(substr(sqlerrm,1,250));
        END;
      END IF;
    END IF;
  END LOOP;
END;
.
/
exit
-ENDOFMARK01

let ERR_CNT=`grep -c "ORA-" ${LOGFILE}`
if [ ${ERR_CNT} -gt 0 ]; then
 echo_msg "ORA- errors in the gather stats log ${LOGFILE}"
 exit -1
fi
}

#Main

echo "${SCRIPTNAME} - started at ${START_DATE}" > ${LOGFILE}

# Disable default Auto Task if needed.
disable_default_job

# Gather statistics
gather_stats

#Cleanup - based on your retention for log files.


#############################################################################
# This is not part of the script
# Sample logfile output:
#############################################################################
#
#
#gather_statistics - started at 12-11-2017 03:00:00
#
#Auto Task:auto optimizer stats collection, already disabled. Continuing stats collection.
#-------------------------------
#GATHER STATS ON DATA DICTIONARY
#-------------------------------
#dbms_stats.gather_dictionary_stats;      133.48sec
#----------------------------------------
#GATHER STATS ON OBJECTS WITH STALE STATS
#----------------------------------------
#exec dbms_stats.gather_table_stats('HR',tabname=>'"TAB1"',partname=>'""', estimate_percent=>0,granularity=>'GLOBAL', method_opt=>'FOR ALL COLUMNS SIZE AUTO');   .04sec
#exec dbms_stats.gather_table_stats('HR',tabname=>'"TAB2"',partname=>'""', estimate_percent=>0,granularity=>'GLOBAL', method_opt=>'FOR ALL COLUMNS SIZE AUTO'); 16.32sec
#exec dbms_stats.gather_table_stats('HR',tabname=>'"TAB3"',partname=>'""', estimate_percent=>0,granularity=>'GLOBAL', method_opt=>'FOR ALL COLUMNS SIZE AUTO');  1.31sec
#exec dbms_stats.gather_table_stats('HR',tabname=>'"TAB4"',partname=>'""', estimate_percent=>0,granularity=>'GLOBAL', method_opt=>'FOR ALL COLUMNS SIZE AUTO');  1.22sec
#
#-------------------------------------
#GATHER STATS ON OBJECTS WITH NO STATS
#-------------------------------------
#
#PL/SQL procedure successfully completed.
###############################################################################

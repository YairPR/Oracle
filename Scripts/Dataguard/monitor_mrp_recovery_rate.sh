--https://blog.pythian.com/oracle-standby-recovery-rate-monitoring/
/*
Management’s second question was, how fast is the current archived redo log being applied? The shell 
script mrp-recovery-rate.sh answers that question.

Basically it gets the log_block_size and polls v$managed_standby twice with a 30-second delay. It then returns 
the redo apply rate in KB/second, MB/second, and the raw bytes/second.

Note: This is a beta version — it does not handle an application rate faster than 30-seconds per log.

This script was developed on the back of the best practices document: MAA – Data Guard Redo Apply and 
Media Recovery Best Practices 10gR1 (PDF). Oracle provided the formula, we are providing the script.
*/

#!/bin/bash
# mrp-recovery-rate.sh
# Created: 2007-10-10
#
LOG_BLOCK_SIZE=`$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" <<END
set pages 0 trimsp on feed off timing off time off
SELECT LEBSZ FROM X\\$KCCLE WHERE ROWNUM=1;
exit;
END`
BLOCK_BEG=`$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" <<END
set pages 0 trimsp on feed off timing off time off
select BLOCK# from V\\$MANAGED_STANDBY where PROCESS='MRP0';
exit;
END`
TIME_BEG=`date +%s`
echo $BLOCK_BEG
sleep 30
BLOCK_END=`$ORACLE_HOME/bin/sqlplus -S "/ as sysdba" <<END
set pages 0 trimsp on feed off timing off time off
select BLOCK# from V\\$MANAGED_STANDBY where PROCESS='MRP0';
exit;
END`
TIME_END=`date +%s`
echo $BLOCK_END
DIFF_TIME=`expr $TIME_END - $TIME_BEG`
DIFF_BLOCKS=`expr $BLOCK_END - $BLOCK_BEG`
DIFF_SIZE=`expr $DIFF_BLOCKS \* $LOG_BLOCK_SIZE`
DIFF_SIZE_TIME=`expr $DIFF_SIZE / $DIFF_TIME`
MB=`expr 1024 \* 1024`
RECOVERY_RATE=`expr $DIFF_SIZE_TIME / 1024`
RECOVERY_RATE_MB=`expr $DIFF_SIZE_TIME / $MB`
echo $LOG_BLOCK_SIZE
echo $DIFF_TIME
echo $RECOVERY_RATE
echo $RECOVERY_RATE_MB

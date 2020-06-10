#!/bin/ksh

# First, we must set the environment . . . .
ORACLE_SID=$1
export ORACLE_SID
ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
export ORACLE_HOME
PATH=$ORACLE_HOME/bin:$PATH
export PATH

$ORACLE_HOME/bin/sqlplus system/manager<<! 

select * from v\$database;
connect perfstat/perfstat
define losnapid=$2
define hisnapid=$3
@sppurge
exit
!

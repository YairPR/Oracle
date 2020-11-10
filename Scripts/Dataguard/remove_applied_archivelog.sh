#!/bin/ksh
#
#
# Remove applied archivelog all;
#
# 
ORACLE_SID=ORCL; export ORACLE_SID
ORACLE_BASE=/u01/app/oracle; export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/12.2.0/db_1; export ORACLE_HOME
 
tmpfile=/tmp/arch_id.tmp
 
$ORACLE_HOME/bin/sqlplus -S /nolog <<EOF > $tmpfile
connect / as sysdba
set head off
set pages 0
select max(sequence#) from v\$archived_log where applied = 'YES';
exit
EOF
 
echo DELETE NOPROMPT ARCHIVELOG UNTIL SEQUENCE = `head -n 1  $tmpfile | awk '{print $1}'` ';' > $tmpfile
 
$ORACLE_HOME/bin/rman target / <<EOF
 @$tmpfile
exit
EOF

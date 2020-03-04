export ORACLE_SID=$1
export ORAENV_ASK=NO;
. /usr/bin/oraenv > /dev/null

sqlplus -s -l / as sysdba << EOF

select NAME,OPEN_MODE,DATABASE_ROLE,to_char(STARTUP_TIME,'DD-MON-YY HH12:MI:SS') STARTUP_TIME,STATUS from v\$database,v\$instance where NAME=INSTANCE_NAME;

prompt ****Checking  INVALID objects *****
select owner,count(*) from dba_objects where status='INVALID' group by owner;

@$ORACLE_HOME/rdbms/admin/utlrp.sql

select owner,count(*) from dba_objects where status='INVALID' group by owner;

exit
EOF


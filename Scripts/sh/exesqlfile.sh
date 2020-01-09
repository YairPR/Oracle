-- AIX

${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
spool guarda_REP_RRC_MES_SBS_manual.log
@guarda_REP_RRC_MES_SBS_manual.sql
/
spool off;
exit
EOF

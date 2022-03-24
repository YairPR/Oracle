HA=`date +%y%m%d%H%M%S`
ARCHIVO=SR10520571
ARCHIVOSPOOL=./${ARCHIVO}.csv
CIERRELOG=./${ARCHIVO}.log

${ORACLE_HOME}/bin/sqlplus /nolog  << FIN 
connect / as sysdba
set linesize 2000
set termout off
set verify off
set colsep ","
set headsep off
set pagesize 0
set trimspool on
spool '${ARCHIVOSPOOL}'
select  * from  emir_morosos_titulares_dh where PERIODO='201906';
spool off;
set termout on
FIN

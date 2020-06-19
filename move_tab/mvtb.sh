cd /home/oracle/scripts
LOGDIR=/home/oracle/scripts/logs
FECHA=`date +'%Y%m%d-%H%M'`
FECHA2=`date +'%Y%m%d'`
LOGFILE=$LOGDIR/mov_datafile.log

echo "LOG=$LOGFILE"
echo "Lista de archivos *.dbf top " >> $LOGFILE
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
spool lstdbf.sql
@lista_dbf.sql
/
spool off;
exit
EOF
echo "  " >> $LOGFILE
chmod 777 $LOGFILE

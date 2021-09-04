#!/bin/ksh
set -x
##########################################################################
#@Author: UTEC - Infraestructura DBA
#@Email: infra_dba@utec.edu.pe
#@Version: 1.0
#@Modi: 23 -07 -2019 Creacion de la shell
#Descripcion: Proceso Backup Export
##########################################################################

## SETEAMOS VARIABLES DE ENTORNO
. /home/oracle/bdupg1.env

##Capturamos la fecha

FECHA=`date +%Y%m%d`
export FECHA
#current_day=`TZ=aaa24 date +%d%m%Y` ##Fecha Dia Anterior

logbatchbkp=/home/oracle/dbscripts/logs/BkpExpd/log_expdp_$FECHA.txt
tmp=/home/oracle/dbscripts/logs/BkpExpd/export.tmp
logexpfail=/home/oracle/dbscripts/logs/BkpExpd/log_expdp_fail_$FECHA.txt
logscp=/home/oracle/dbscripts/logs/BkpExpd/log_expdp_scp_$FECHA.txt

cd /u01/app/oracle/backup_expdp
##rm -f *.gz
rm -f *.dmp
rm -f $tmp
find /u01/app/oracle/backup_expdp/ -name '*.gz' -mtime +7 |  xargs -tI {} rm {};
find /u01/app/oracle/backup_expdp/  -name '*.log' -mtime +7 | xargs -tI {} rm {};
find /home/oracle/dbscripts/logs/BkpExpd/  -name '*.txt' -mtime +7 | xargs -tI {} rm {};

truncate $logbatchbkp --size 0

echo "########################################" >> $logbatchbkp
echo "Iniciando Backup Export $ORACLE_SID ... " >> $logbatchbkp
echo "########################################" >> $logbatchbkp

#Enviando Correo de Notificacion
#echo "Subject: PRODUCCIÃ - Backup Full expdp  INICIA" | /usr/sbin/sendmail -t infra_dba@utec.edu.pe
cat $logbatchbkp | mail -s "PRODUCCION - Backup Full expdp  INICIA" $DBALIST

truncate $logbatchbkp --size 0
truncate $logscp --size 0
truncate $logexpfail --size 0

#expdp system/X4unzAheDLOsC0n directory=EXPBCK dumpfile=bdUTEC_Core_"$FECHA".dmp logfile=expbdCore_"$FECHA".log full=yes
expdp system/PAssw0rd#123#@PDBUPG1 directory=DATA_PUMP_DIR_PDB dumpfile=bdUTEC_Core_"$FECHA".dmp logfile=expbdCore_"$FECHA".log full=yes EXCLUDE=SCHEMA:"in\('PERFSTAT'\)" EXCLUDE=PROCOBJ

#Enviando correo de Fin de Backup

cat expbdCore_"$FECHA".log >> $tmp

egrep -q "ORA-|Linux-x86_64 Error|stopped|Failed|Killed" $tmp
if (( $? != 0 )); then
echo "#############################################" >> $logbatchbkp
echo "Proceso backup EXPORT finalizado correctamente." >> $logbatchbkp
echo "###############################################\n" >>$logbatchbkp
cat $tmp|grep "Export: Release" >> $logbatchbkp
cat $tmp|grep "successfully completed" >> $logbatchbkp
echo "#############################################" >> $logbatchbkp
echo "Iniciando compresion de archivos dmp y log para copiado por SCP..." >>$logbatchbkp
cat $logbatchbkp | mail -s "PRODUCCION - Backup Full expdp  TERMINADO CORRECTAMENTE" $DBALIST

gzip -c bdUTEC_Core_$FECHA.dmp > bdUTEC_Core_"$FECHA".gz
gzip -c expbdCore_"$FECHA".log > expbdCore_"$FECHA".gz

scp -v -i /home/oracle/dbscripts/utec/evotech /u01/app/oracle/backup_expdp/bdUTEC_Core_"$FECHA".gz ec2-user@ec2-54-184-59-120.us-west-2.compute.amazonaws.com:~/oracle_dump/bdUTEC_Core_"$FECHA".gz 2> $logscp
#cp /u02/app/oracle/oradata/bdutec01/control01.ctl /u05/app/oracle/recovery_area/control01.ctl
#cp /u01/app/oracle/product/11.2.0/dbhome_1/dbs/spfilebdutec01.ora /u05/app/oracle/recovery_area/spfilebdutec01.ora

else

truncate $logbatchbkp --size 0
echo "###############################################" >>$logbatchbkp
echo "ERRORES en el backup export" >>$logbatchbkp
echo "###############################################\n" >>$logbatchbkp
cat $tmp|grep "ORA-" >> $logbatchbkp
cat $tmp|grep "completed with" >> $logbatchbkp
cat $logbatchbkp | mail -s "PRODUCCION - Backup Full expdp  ERROR" $DBALIST

fi

egrep -q "debug1: Exit status 0" $logscp
if (( $? == 0 )); then
echo "#################################################" >> $logbatchbkp
echo "Copiado de SCP de EXPDP finalizado correctamente." >> $logbatchbkp
echo "#################################################\n" >>$logbatchbkp
#cat $logscp | grep -i Transferred -A 3 >>$logbatchbkp
cat $logbatchbkp | mail -s "PRODUCCION - Copiado de SCP de expdp terminado CORRECTAMENTE" $DBALIST

else

echo "###############################################################################" >> $logexpfail
echo "Proceso interrumpido, no se logro completar el copiado de backup mediante SCP." >> $logexpfail
echo "###############################################################################\n" >> $logexpfail
echo "$FECHA" >> $logexpfail
cat $logexpfail | mail -s "PRODUCCION - Copiado de SCP de expdp FALLADO" $DBALIST

fi

rm -f $tmp

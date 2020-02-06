. /home/oracle/.bash_profile

# Obtiene el alias de la BD desde la variable DBALIAS_{$ORACLE_SID}
DBALIAS=`eval echo \$\{DBALIAS_${ORACLE_SID}\}`
[ ! -n "${DBALIAS}" ] && DBALIAS=${ORACLE_SID}
export DBALIAS

export CRON_DATE=`date +%Y.%m.%d`
export CRON_SHOUR=`date +%H.%M`
export CRON_HOUR=`date +%H:%M`
export DIRDUMP=${ORACLE_BASE}/
export DIRWORK=/home/oracle/scripts
export DIRLOG=${DIRWORK}/logs/cron_$1_${CRON_DATE}_${CRON_SHOUR}.log

# #########################
# Getting ALERTLOG path:
# #########################

# First Attempt:
DIRDUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
export DIRDUMP

# #######################
# GET SIZE FILESYSTEM
# #######################

df -Ph | grep -vE '^Filesystem|tmpfs|cdrom|proc|boot' | grep /u01 | awk '{ print $6 " " $5 " " $4}' | while read output;
do
  usep=$(echo $output | awk '{ print $2}' | cut -d '%' -f 1  )
## partition=$(echo $output | awk '{ print $1 }' ) 
## freespace=$(echo $output | awk '{ print $3 }' )

  if [ $usep -ge 90 ]; then
	echo $output >>  ${SQLLOG}
        echo "------------------------------------------------------" > ${SQLLOG}
	echo >> ${SQLLOG}
	echo "Fecha-Hora de Inicio" >> ${SQLLOG}
	echo "--------------------" >> ${SQLLOG}
	echo $CRON_DATE $CRON_HOUR >> ${SQLLOG}
	echo >> ${SQLLOG}
	echo "Antes:" >> ${SQLLOG}
	dirtracesize=`du -sh $DIRDUMP`
	echo "Tamaño Direcotrio Trace File:" $dirtracesize >> ${SQLLOG}
	cantfile=`ls -l *.trc *.trm | wc -l`
	echo "Cantidad de archivos trc trm: " $cantfile >> ${SQLLOG}
	echo >> ${SQLLOG}
	echo "Eliminando archivor trc - trm" >> ${SQLLOG}
	find $DIRDUMP/*.trm -mtime -1 | awk '{print "rm "$1}' | sh
	find $DIRDUMP/*.trc -mtime -1 | awk '{print "rm "$1}' | sh
	cd $DIRDUMP
	echo "Despues:" >> ${SQLLOG}
	echo "Cantidad de archivos trc trm: " $cantfile >> ${SQLLOG}
	ls -ltr *.trc *.trm >> ${SQLLOG}
	echo >> ${SQLLOG}
	echo "Fecha-Hora de Fin"  >> ${SQLLOG}
	echo "--------------------" >> ${SQLLOG}
	echo $CRON_DATE $CRON_HOUR >> ${SQLLOG}
	echo "------------------------------------------------------" >> ${SQLLOG}
  fi
done

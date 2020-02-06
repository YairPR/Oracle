. /home/oracle/.bash_profile
set -x
me=`basename "$0" .sh`
# Obtiene el alias de la BD desde la variable DBALIAS_{$ORACLE_SID}
DBALIAS=`eval echo \$\{DBALIAS_${ORACLE_SID}\}`
[ ! -n "${DBALIAS}" ] && DBALIAS=${ORACLE_SID}
export DBALIAS

export CRON_DATE=`date +%Y.%m.%d`
export CRON_SHOUR=`date +%H.%M`
export CRON_HOUR=`date +%H:%M`
export DIRDUMP=${ORACLE_BASE}/
export DIRWORK=/home/oracle/scripts/crons
export DIRLOG=${DIRWORK}/logs/cron.$me.${CRON_DATE}.${CRON_SHOUR}.log

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
dirtracesize=`du -sh $DIRDUMP`
cd $DIRDUMP
df -Ph | grep -vE '^Filesystem|tmpfs|cdrom|proc|boot' | grep /u01 | awk '{ print $6 " " $5 " " $4}' | while read output;
do
  usep=$(echo $output | awk '{ print $2}' | cut -d '%' -f 1  )
## partition=$(echo $output | awk '{ print $1 }' )
## freespace=$(echo $output | awk '{ print $3 }' )

  if [ $usep -ge 90 ]; then
        echo $output >>  ${DIRLOG}
        echo "------------------------------------------------------" > ${DIRLOG}
        echo >> ${DIRLOG}
        echo "Fecha-Hora de Inicio" >> ${DIRLOG}
        echo "--------------------" >> ${DIRLOG}
        echo $CRON_DATE $CRON_HOUR >> ${DIRLOG}
        echo >> ${DIRLOG}
        echo "Antes:" >> ${DIRLOG}
        echo "Tamaño Direcotrio Trace File:" $dirtracesize >> ${DIRLOG}
        cantfile=`ls -l *.trc *.trm | wc -l`
        echo "Cantidad de archivos trc trm: " $cantfile >> ${DIRLOG}
        echo "# ####################################">> ${DIRLOG}
        echo "# Eliminando archivos trc - trm..." >> ${DIRLOG}
        echo "# ####################################">> ${DIRLOG}
        find $DIRDUMP/*.trm -mtime -1 | awk '{print "rm "$1}' | sh
        find $DIRDUMP/*.trc -mtime -1 | awk '{print "rm "$1}' | sh
        echo "Despues:" >> ${DIRLOG}
        echo "Cantidad de archivos trc trm: " $cantfile >> ${DIRLOG}
        ls -ltr *.trc *.trm >> ${DIRLOG}
        echo >> ${DIRLOG}
        echo "Fecha-Hora de Fin"  >> ${DIRLOG}
        echo "--------------------" >> ${DIRLOG}
        echo $CRON_DATE $CRON_HOUR >> ${DIRLOG}
        echo "------------------------------------------------------" >> ${DIRLOG}
  fi
done

cd /oracle/backup/dmp
LOGDIR=/oracle/scripts/crons/logs
#---FECHA_MES_ANT=`TZ=CST+2160 date +%m%y`
FECHA_MES_ANT=`TZ=CST+1200 date +%m%y`
FECHA=`date +'%Y%m%d-%H%M'`
FECHA2=`date +'%Y%m%d'`
LOGFILE=$LOGDIR/replica_RESERVA_RIESGO_CURSO_ERP_C05090_$FECHA.log
ARCH_DMP=/oracle/backup/dmp/exp_RESERVA_RIESGO_CURSO_ERP_DIC2019.dmp
LOG_DMP=app_res_reserva_riesgo_${FECHA_MES_ANT}_imp.log

echo "LOG=$LOGFILE"
echo "Mes importar $FECHA_MES_ANT  " >> $LOGFILE
echo "`ls -l $ARCH_DMP" >> $LOGFILE
echo "=== Importando Tabla RESERVA_RIESGO_CURSO_ERP en BDDYNA : `date` ===" >> $LOGFILE

imp \'/ as sysdba\' file=$ARCH_DMP fromuser=ACSELX touser=APP_RESTORE tables=RESERVA_RIESGO_CURSO_ERP  log=app_res_reserva_riesgo_${FECHA_MES_ANT}_imp.log ignore=y INDEXES=n CONStraints=n  grants=n

cat $LOG_DMP    >> $LOGFILE
echo "=== Renombrando y Modificando la Tabla RESERVA_RIESGO_CURSO_ERP en BDDYNA : `date` ===" >> $LOGFILE
/oracle/scripts/crons/shs/DDLs_RESERVA_RIESGO_CURSO_ERP.sh $FECHA_MES_ANT
sleep 60

cat /oracle/backup/dmp/DDL_RESERVA_RIESGO_CURSO_ERP_$FECHA2.log >> $LOGFILE
echo "  " >> $LOGFILE
echo "=== Tabla RESERVA_RIESGO_CURSO_ERP replicada en BDDYNA: `date` ===" >> $LOGFILE
echo "  " >> $LOGFILE
chmod 777 $LOGFILE

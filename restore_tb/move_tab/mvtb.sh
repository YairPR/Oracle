cd /home/oracle/scripts
LOGDIR=/home/oracle/scripts/logs
FECHA=`date +'%Y%m%d-%H%M'`
FECHA2=`date +'%Y%m%d'`
LOGFILE=$LOGDIR/mov_datafile.log

echo "LOG=$LOGFILE"
echo "Lista de archivos *.dbf top " >> $LOGFILE
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

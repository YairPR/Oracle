programa2.sh

SCRIPT=BDCONTA_MANTRA_ERP
FECHA=`date +%y%m%d%H%M%S`
ARCHIVO=log_${SCRIPT}_${FECHA}
##CIERRELOG=./logs/${ARCHIVO}.log
CIERRELOG=/oracle/scripts/crons/sqls/${ARCHIVO}.log


echo " " > $CIERRELOG
echo " " >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG
echo "Inicio: `date +%Y-%m-%d@%H:%M:%S`" >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG

sqlplus -S  mantenimiento/mn2013mn << FIN >> $CIERRELOG

DECLARE
  CURSOR c_cias IS 
    SELECT CodCia
    FROM MAESTRO_CIA
    ORDER BY CodCia DESC;
  --
  dFecha_Ini DATE := TO_DATE(TO_CHAR(TRUNC(SYSDATE) - 1,'YYYYMM')||'01','YYYYMMDD');
  dFecha_Fin DATE := TRUNC(SYSDATE - 1); 
  cModulo VARCHAR2(100) := 'CRON158 - Actualizar Asientos MANTRA - IDECNT';
BEGIN
  BEGIN
    FOR p IN c_cias LOOP
      BEGIN
        APP_CONTABILIZADOR.PR_VALIDACION_EBS_ERP.PROCESA_ACT_ASIENTO(dFecha_Ini, dFecha_Fin, p.CodCia);
      EXCEPTION 
        WHEN OTHERS THEN
          NULL;
      END;
    END LOOP;
  EXCEPTION 
    WHEN OTHERS THEN
      NULL;
  END;
  --
  dbms_application_info.set_module(cModulo, 'FINALIZO');
END;
/

FIN


echo " " >> $CIERRELOG
echo " " >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG
echo "Fin: `date +%Y-%m-%d@%H:%M:%S`" >> $CIERRELOG
echo "****************************************************************************" >> $CIERRELOG

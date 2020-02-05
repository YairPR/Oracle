[oracle@rssbrt01] /home/oracle > cat /oracle/scripts/crons/ejecutacron.sh
########################################################################################################
# Parametros o Argumentos de este programa:
#     -u : Indica el Usuario con que se correra el script
#     -c : Indica el Codigo asignado al Cron a ejecutar
#     -d : Indica la breve descripcion del Cron a ejecutar
#     -h : Indica la hora de envio del email con el log acumulado de todo el dia (formato H24:MI)
#     -p : Indica que en lugar de ejecutar un .sql, se ejecutara un .sh
#     -m : Indica a que correos adicionales se enviara el informe del proceso
#     -s : Indica la cadena de conexi�n donde se ejecutar� el proceso
#     -f : Indica el formato del imforme del proceso (text / html)
########################################################################################################

# Carga las variables de entorno pre-definidas
. /oracle/scripts/oracleconfig.sh

# Obtiene variables globales definidas por el usuario
i=1
top=`expr $# + 1`
while [ $i -lt $top ]
do
  eval var=$"{${i}}"
  echo $var
  case "$var" in
    -u)
    # Obtiene el usuario
        i=`expr $i + 1`
        eval UNAME=$"{${i}}"
        export UNAME
        # echo "UNAME: $UNAME"
        ;;
    -c)
    # Obtiene el codigo del cron
        i=`expr $i + 1`
        eval CRON_CODE=$"{${i}}"
        export CRON_CODE
        # echo "CRON_CODE: $CRON_CODE"
        ;;
    -d)
    # Obtiene la descripcion del cron
        i=`expr $i + 1`
        eval CRON_DESC=$"{${i}}"
        export CRON_DESC
        # echo "CRON_DESC: $CRON_DESC"
        ;;
    -h)
    # Obtiene la hora de envio del acumulado
        i=`expr $i + 1`
        eval CRON_HACUM=$"{${i}}"
        export CRON_HACUM
        # echo "CRON_HACUM: $CRON_HACUM"
    ;;
    -p)
    # Obtiene el programa .sh a ejecutar
        i=`expr $i + 1`
        eval CRON_PROG=$"{${i}}"
        export CRON_PROG
        # echo "CRON_PROG: $CRON_PROG"
        ;;
    -m)
    # Obtiene otros destinatarios de correo para el envio del informe
        i=`expr $i + 1`
        eval MAIL_OTHER=$"{${i}}"
        export MAIL_OTHER
        # echo "MAIL_OTHER: $MAIL_OTHER"
        ;;
    -s)
    # Obtiene el host del string de conexion donde se ejecutara el script sql
        i=`expr $i + 1`
        eval ORACLE_CSTRING=$"{${i}}"
        export ORACLE_CSTRING
        # echo "ORACLE_CSTRING: $ORACLE_CSTRING"
        ;;
    -f)
    # Obtiene el formato del log a enviarse
        i=`expr $i + 1`
        eval MAIL_FORMAT=$"{${i}}"
        export MAIL_FORMAT
        # echo "ORACLE_CSTRING: $ORACLE_CSTRING"
        ;;
    -e)
    # Verifica si va a revisar mensajes de error y alert
        i=`expr $i + 1`
        eval WARERR=$"{${i}}"
        export WARERR
        ;;
    *)
        echo "Parametro ($var) errado, tus opciones son: -u, -c, -d, -h, -p, -m, -s, -f, -e"
        exit 0
    ;;
  esac
  i=`expr $i + 1`
done

# Obtiene el password desde la variable UPASS_{$UNAME}
# seteada en el archivo oracleconfig.sh
export UPASS=`eval echo \$\{UPASS_${UNAME}\}`

# Obtiene el alias de la BD desde la variable DBALIAS_{$ORACLE_SID}
# seteada en el archivo oracleconfig.sh
DBALIAS=`eval echo \$\{DBALIAS_${ORACLE_SID}\}`
[ ! -n "${DBALIAS}" ] && DBALIAS=${ORACLE_SID}
export DBALIAS

export CRON_DATE=`date +%Y.%m.%d`
export CRON_SHOUR=`date +%H.%M`
export CRON_HOUR=`date +%H:%M`
export CRON_STATUS=ACTIVO


export DIRWORK=${DIRSCRIPTS}/crons
export SQLLOG=${DIRWORK}/logs/cron_${CRON_CODE}_${CRON_DATE}_${CRON_SHOUR}.log
export SQLREQ=${DIRWORK}/sqls/cron_${CRON_CODE}.sql

cd $DIRWORK
CRON_STATUS=`$ORACLE_HOME/bin/sqlplus -S $UNAME/$UPASS@$ORACLE_SID << EOF
set echo off
set heading on
set termout off
set serveroutput on size 1000000
set linesize 1000 pagesize 500
set verify off
set feedback off

DECLARE
  n_noejecuta   number(2);
  c_idcron      ora_audit.tdesactiva_cron.cod_cron%TYPE := '${CRON_CODE}';
BEGIN
  SELECT COUNT(1)
  INTO   n_noejecuta
  FROM   ora_audit.tdesactiva_cron
  WHERE  TRUNC(fec_desactiva) = TRUNC(SYSDATE)
    AND  cod_cron = c_idcron
    AND  ind_activo = 1;
  IF nvl(n_noejecuta,0) = 0 THEN
    dbms_output.put_line('ACTIVO');
  ELSE
    dbms_output.put_line('INACTIVO');
  END IF;
END;
/

quit
EOF`

echo $CRON_STATUS

if [ "${CRON_STATUS}" = "INACTIVO" ]; then

  echo "ALERT: Se ha programado la desactivaci�n de este cron por temas de Pre-Cierre o Cierre Contable. NO se procede con su ej
ecuci�n" > ${SQLLOG}

else

if [ -n "${CRON_PROG}" ]; then

  sh shs/cron_${CRON_CODE}.sh

else

$ORACLE_HOME/bin/sqlplus -S $UNAME/$UPASS@$ORACLE_SID << EOF
set echo off
set heading on
set termout off
set serveroutput off
set trimspool on
set linesize 1000 pagesize 500
alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
-- Setea el nombre del Modulo para fines de seguimiento
begin
    DBMS_APPLICATION_INFO.set_module('Cron: ${CRON_CODE} Fec.Ini: ${CRON_DATE}_${CRON_SHOUR}','');
end;
/

spool ${SQLLOG}
`[ "${MAIL_FORMAT}" = "html" ] && echo "prompt <pre>"`
prompt -------------------------------------------------------

select to_char(sysdate,'dd/mm/yyyy hh24:mi:ss') "Fecha-Hora de Inicio" from dual;
prompt

`[ "${MAIL_FORMAT}" = "html" ] && echo "prompt </pre>"`

start ${SQLREQ} ${CRON_CODE} ${SQLLOG}

`[ "${MAIL_FORMAT}" = "html" ] && echo "prompt <pre>"`
prompt

select to_char(sysdate,'dd/mm/yyyy hh24:mi:ss') "Fecha-Hora de Fin" from dual;
prompt -------------------------------------------------------

`[ "${MAIL_FORMAT}" = "html" ] && echo "prompt </pre>"`
spool off
quit
EOF

fi

fi

cd $DIRWORK

if [ -n "${CRON_HACUM}" ]; then
    echo "Entra acumulado"
    if [ -n "${WARERR}" ]; then

            N_WARERR=`grep -e WARNING -e ALERT -e ORA- -e EXP- ${SQLLOG} | wc -l`

            if [ $N_WARERR -eq 0 ]; then
                echo "Sin Problemas "
            else
                N_WARERR=`grep -e ALERT -e ORA- -e EXP- ${SQLLOG} | wc -l`
                if [ $N_WARERR -eq 0 ]; then
                   CRON_DESC="[WARNING] "${CRON_DESC}
                else
                   CRON_DESC="[ALERT] "${CRON_DESC}
                fi
                echo "Con Problema"
                enviaEmail
            fi

    fi

    if [ -f logs/cron_${CRON_CODE}_${CRON_DATE}_*.log ]; then
        for HACUM in ${CRON_HACUM};
        do
            if [ "${CRON_HOUR}" = "${HACUM}" ]; then
                SQLLOG=logs/cron_${CRON_CODE}_${CRON_DATE}.log
                cat logs/cron_${CRON_CODE}_${CRON_DATE}_*.log > ${SQLLOG}
                rm -f logs/cron_${CRON_CODE}_${CRON_DATE}_*.log
                if [ ! -n "${WARERR}" ]; then
                    enviaEmail
                fi
            fi
        done
    fi

else
    if [ -f ${SQLLOG} ]; then

        if [ -n "${WARERR}" ]; then

                N_WARERR=`grep -e WARNING -e ALERT -e ORA- -e EXP- ${SQLLOG} | wc -l`

                if [ $N_WARERR -eq 0 ]; then
                   echo "Sin Problemas "
                else
                   echo "Con Problema"
                   N_WARERR=`grep -e ALERT -e ORA- -e EXP- ${SQLLOG} | wc -l`
                   if [ $N_WARERR -eq 0 ]; then
                      CRON_DESC="[WARNING] "${CRON_DESC}
                   else
                      CRON_DESC="[ALERT] "${CRON_DESC}
                   fi
                   enviaEmail
                fi
        else
                enviaEmail
        fi

    fi
fi

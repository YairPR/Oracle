#!/bin/ksh
# Eddie Purisaca Rivera
# Script para revisar bases de datos Oracle 10g/11g/12c en AIX
# Verifica: Data Guard, Tablespaces, Usuarios, Auditoría, Alertlog, RMAN, GoldenGate
# Versión 1.3 - MAYO 2025

FECHA=$(date +%Y%m%d_%H%M)
ORACLE_BASE_DIR="$HOME"

# Detectar instancias activas por PMON
for ORACLE_SID in $(ps -ef | grep pmon | grep -v grep | awk -F_ '{print $NF}')
do
  export ORACLE_SID
  REPORT="$ORACLE_BASE_DIR/${ORACLE_SID}_report_${FECHA}.txt"

  echo "============================================================" > $REPORT
  echo "REPORTE DE REVISION - INSTANCIA: $ORACLE_SID" >> $REPORT
  echo "Fecha: $(date)" >> $REPORT
  echo "============================================================" >> $REPORT

  sqlplus -s / as sysdba <<EOF >> $REPORT
set pagesize 500 linesize 200 heading on feedback off

prompt
prompt ============================================================
prompt ===============         VERSION ORACLE         ===============
prompt ============================================================
select * from v\$version where rownum = 1;

prompt
prompt ============================================================
prompt ===============     ESTADO DE DATA GUARD     ===============
prompt ============================================================
column database_role format a15
column protection_mode format a20
column protection_level format a20
select database_role, protection_mode, protection_level from v\$database;

prompt
prompt ============================================================
prompt ============     SINCRONIZACION DATA GUARD     ============
prompt ============================================================
col name format a30
col value format a30
select name, value, unit from v\$dataguard_stats where name in ('apply lag','transport lag');

prompt
prompt ============================================================
prompt ===============       ESTADO DEL FRA          ===============
prompt ============================================================
SELECT LOG_MODE FROM V\$DATABASE;
SELECT
    CASE
        WHEN VALUE IS NULL OR VALUE = '' THEN
            'ALERTA: FRA no esta configurado!'
        ELSE
            'FRA configurado en: ' || VALUE
    END AS FRA_STATUS
FROM v\$parameter
WHERE name = 'db_recovery_file_dest';

SELECT
  ROUND((A.SPACE_LIMIT / 1024 / 1024 / 1024), 2) AS FLASH_IN_GB,
  ROUND((A.SPACE_USED / 1024 / 1024 / 1024), 2) AS FLASH_USED_IN_GB,
  ROUND((A.SPACE_RECLAIMABLE / 1024 / 1024 / 1024), 2) AS FLASH_RECLAIMABLE_GB,
  SUM(B.PERCENT_SPACE_USED)  AS PERCENT_OF_SPACE_USED
FROM
  V\$RECOVERY_FILE_DEST A,
  V\$FLASH_RECOVERY_AREA_USAGE B
GROUP BY
  SPACE_LIMIT,
  SPACE_USED,
  SPACE_RECLAIMABLE;

prompt
prompt ============================================================
prompt ===============   USO DE TABLESPACES         ===============
prompt ============================================================
column USO format a50
select tablespace_name,
       round(used_space*100/total_space,2) as pct_used,
       case when round(used_space*100/total_space,2) >= 85
            then 'ALERTA: SOLO '||round(100 - used_space*100/total_space,2)||'% DISPONIBLE'
            else 'OK'
       end as USO
from (
  select df.tablespace_name,
         sum(df.bytes)/1024/1024 as total_space,
         sum(df.bytes - fs.bytes)/1024/1024 as used_space
    from dba_data_files df,
         (select file_id, sum(bytes) bytes from dba_free_space group by file_id) fs
   where df.file_id = fs.file_id(+)
   group by df.tablespace_name
);
EOF

  CRITICAL_ORAS="ORA-00600|ORA-07445|ORA-04031|ORA-01555|ORA-19809|ORA-19815|ORA-03113|ORA-03114|ORA-03135|ORA-00060|ORA-01089|ORA-12541|ORA-00257|ORA-27072"
  FECHA_LIMITE=$(perl -e 'print time - (30 * 24 * 60 * 60);')

  echo "\n============================================================" >> "$REPORT"
  echo "=============== ALERT LOG - Últimos 30 días ===============" >> "$REPORT"
  echo "============================================================\n" >> "$REPORT"

  if [ -z "$ORACLE_HOME" ]; then
    ORACLE_HOME=$(awk -F: -v sid="$ORACLE_SID" '$1 == sid {print $2}' /etc/oratab | head -1)
    export ORACLE_HOME
  fi

  if [ -z "$ORACLE_BASE" ]; then
    ORACLE_BASE=$($ORACLE_HOME/bin/orabase)
    export ORACLE_BASE
  fi

  ALERT_LOG=""
  ADR_LOG="$ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace/alert_${ORACLE_SID}.log"
  [ -f "$ADR_LOG" ] && ALERT_LOG="$ADR_LOG"
  if [ -z "$ALERT_LOG" ]; then
    OLD_LOG="$ORACLE_HOME/rdbms/log/alert_${ORACLE_SID}.log"
    [ -f "$OLD_LOG" ] && ALERT_LOG="$OLD_LOG"
  fi
  if [ -z "$ALERT_LOG" ]; then
    FOUND_LOG=$(find "$ORACLE_BASE" -name "alert_${ORACLE_SID}.log" 2>/dev/null | head -1)
    [ -f "$FOUND_LOG" ] && ALERT_LOG="$FOUND_LOG"
  fi
  if [ -z "$ALERT_LOG" ]; then
    echo "ALERTA: No se encontró el alert log para $ORACLE_SID" >> "$REPORT"
  else
    awk -v regex="$CRITICAL_ORAS" -v fecha_limite="$FECHA_LIMITE" '
      function fecha_a_epoch(fecha, epoch, mes, dia, hora, min, seg, anio, cmd) {
        if (match(fecha, /^[A-Za-z]{3} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}:[0-9]{2} +[0-9]{4}/)) {
          split(fecha, f, " ")
          mes = f[1]; dia = f[2]
          split(f[3], t, ":"); hora = t[1]; min = t[2]; seg = t[3]
          anio = f[4]
        } else if (match(fecha, /^[A-Za-z]{3} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}:[0-9]{2}/)) {
          split(fecha, f, " ")
          mes = f[1]; dia = f[2]
          split(f[3], t, ":"); hora = t[1]; min = t[2]; seg = t[3]
          cmd = "date +%Y"; cmd | getline anio; close(cmd)
        } else {
          return -1
        }

        cmd = "perl -e '\''use Time::Local; $m = {Jan=>0,Feb=>1,Mar=>2,Apr=>3,May=>4,Jun=>5,Jul=>6,Aug=>7,Sep=>8,Oct=>9,Nov=>10,Dec=>11}; print timelocal(" seg "," min "," hora "," dia ",$m->{\"" mes "\"}," anio ");'\''"
        cmd | getline epoch
        close(cmd)
        return epoch
      }
      BEGIN { errores=0 }
      /^[A-Za-z]{3} +[0-9]{1,2} +[0-9]{2}:[0-9]{2}:[0-9]{2}/ { fecha_actual = $0 }
      $0 ~ /ORA-/ && $0 ~ regex {
        if (fecha_actual != "") {
          ts = fecha_a_epoch(fecha_actual)
          if (ts == -1) next
          if (ts >= fecha_limite) {
            print fecha_actual ": " $0
            errores++
          }
        }
      }
      END {
        if (errores == 0) {
          print "No se encontraron errores ORA- críticos en los últimos 30 días."
        }
      }
    ' "$ALERT_LOG" >> "$REPORT"
  fi

  sqlplus -s / as sysdba <<EOF >> $REPORT
prompt
prompt ============================================================
prompt ===============       AUDITORIA DB            ===============
prompt ============================================================
select value from v\$parameter where name = 'audit_trail';

prompt
prompt ============================================================
prompt ===============  USUARIOS EXPIRADOS/BLOQUEADOS =============
prompt ============================================================
select username, account_status, expiry_date from dba_users where account_status like ('EXPIRED%');

prompt
prompt ============================================================
prompt ========== RESPALDOS RMAN >50GB (POSIBLE LEVEL 0) ==========
prompt ============================================================
set pagesize 2000 linesize 200
column input_type format a12
column status format a25
column start_time format a20
column end_time format a20
column hrs format 999.99
column sum_bytes_backed_in_gb format 9999.99
column sum_backup_pieces_in_gb format 9999.99
column output_device_type format a15

select
  'POSIBLE LEVEL 0 (' || rb.input_type || ')' as backup_type,
  rb.status,
  to_char(rb.start_time, 'MM/DD/YY HH24:MI') as start_time,
  to_char(rb.end_time, 'MM/DD/YY HH24:MI') as end_time,
  round(rb.elapsed_seconds / 3600, 2) as hrs,
  round(rb.input_bytes / 1024 / 1024 / 1024, 2) as sum_bytes_backed_in_gb,
  round(rb.output_bytes / 1024 / 1024 / 1024, 2) as sum_backup_pieces_in_gb,
  rb.output_device_type
from v\$rman_backup_job_details rb
where (rb.input_bytes / 1024 / 1024 / 1024) > 50
  and rb.status like 'COMPLETED%'
  and rb.input_type like 'DB%'
  and rb.end_time > sysdate - 15
order by rb.end_time desc;
EOF

  GG_HOME=$(ps -ef | grep extract | grep -v grep | awk '{print $NF}' | sed 's/\/dircrt.*//')
  if [ -n "$GG_HOME" ] && [ -d "$GG_HOME" ]; then
    echo "\n============================================================" >> $REPORT
    echo "===============     ESTADO GOLDENGATE     ==================" >> $REPORT
    echo "============================================================\n" >> $REPORT
    GGSCI="$GG_HOME/ggsci"
    if [ -x "$GGSCI" ]; then
      echo "GoldenGate - info all:" >> $REPORT
      $GGSCI <<EOF >> $REPORT
info all
exit
EOF
    else
      echo "ggsci no ejecutable en $GG_HOME" >> $REPORT
    fi
  else
    echo "\n============================================================" >> $REPORT
    echo "===============  GOLDENGATE NO DETECTADO ===================" >> $REPORT
    echo "============================================================\n" >> $REPORT
  fi

done

echo "\nReportes generados en: $ORACLE_BASE_DIR"

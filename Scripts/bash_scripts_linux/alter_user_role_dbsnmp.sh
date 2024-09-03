#!/bin/bash

# Archivo de log
LOGFILE="/tmp/dbsnmp_unlock.log"

# Comandos SQL para desbloquear y cambiar la contraseña del usuario dbsnmp
unlock_sql="alter user DBSNMP profile SISTEMA;"

# Función para registrar en el log y en pantalla
log() {
  echo "$1"
  echo "$1" >> $LOGFILE
}

# Función para registrar en el log y en pantalla en caso de error
log_error() {
  echo "Error: $1"
  echo "Error: $1" >> $LOGFILE
}

# Definición de funciones para configurar el entorno según cada base de datos

set_oracle_env() {
  local sid=$1

  # Llamar a la función específica según la instancia
  case $sid in
    prescore1)
      unset ORACLE_HOME
      ORACLE_SID=prescore1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/1900/prescore; export ORACLE_HOME
      ;;
    omip1001)
      unset ORACLE_HOME
      ORACLE_SID=omip1001; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/omip100; export ORACLE_HOME
      ;;
    preraims1)
      unset ORACLE_HOME
      ORACLE_SID=preraims1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/preraims; export ORACLE_HOME
      ;;
    dept1001)
      unset ORACLE_HOME
      ORACLE_SID=dept1001; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/dept100; export ORACLE_HOME
      ;;
    precore1)
      unset ORACLE_HOME
      ORACLE_SID=precore1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/precore; export ORACLE_HOME
      ;;
    prerhap1)
      unset ORACLE_HOME
      ORACLE_SID=prerhap1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/prerhap; export ORACLE_HOME
      ;;
    preecon1)
      unset ORACLE_HOME
      ORACLE_SID=preecon1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/preecon; export ORACLE_HOME
      ;;
    gace1001)
      unset ORACLE_HOME
      ORACLE_SID=gace1001; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/gace100; export ORACLE_HOME
      ;;
    prerec1)
      unset ORACLE_HOME
      ORACLE_SID=prerec1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/prerec; export ORACLE_HOME
      ;;
    preemer1)
      unset ORACLE_HOME
      ORACLE_SID=preemer1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/1900/preemer; export ORACLE_HOME
      ;;
    presil1)
      unset ORACLE_HOME
      ORACLE_SID=presil1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/1900/presil; export ORACLE_HOME
      ;;
    prebdu1)
      unset ORACLE_HOME
      ORACLE_SID=prebdu1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/11204/prebdu; export ORACLE_HOME
      ;;
    preplaza1)
      unset ORACLE_HOME
      ORACLE_SID=preplaza1; export ORACLE_SID
      ORACLE_HOME=/u01/app/oracle/product/1900/preplaza; export ORACLE_HOME
      ;;
    *)
      log_error "No hay configuración definida para la instancia '$sid'. Omitiendo..."
      return 1
      ;;
  esac

  # Establecer las demás variables de entorno comunes
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

# Limpiar archivo de log anterior
> $LOGFILE

# Obtener las bases de datos RDBMS activas del usuario oracle excluyendo ASM y MGMTDB
pmon_processes=$(ps -ef | awk '/ora_pmon_/ && !/ASM/ && !/-MGMTDB/ {print $8}' | sed 's/.*ora_pmon_//' | grep -v sed)

# Verificar si hay bases de datos activas
if [ -z "$pmon_processes" ]; then
  log_error "No se encontraron instancias de base de datos activas bajo el usuario oracle."
  exit 1
fi

# Mostrar las instancias activas
log "Instancias encontradas:"
log "$pmon_processes"

# Iterar sobre cada instancia encontrada
for instance in $pmon_processes; do
  log "Configurando entorno para la instancia '$instance'..."

  # Configurar el entorno para la instancia
  set_oracle_env $instance

  # Verificar si se configuró correctamente el entorno
  if [ $? -ne 0 ]; then
    log_error "No se pudo configurar el entorno para la instancia '$instance'. Omitiendo..."
    continue
  fi

  # Ejecutar el comando SQL para desbloquear al usuario DBSNMP
  log "Ejecutando el desbloqueo del usuario DBSNMP en la instancia '$instance'..."
  sqlplus -s / as sysdba <<EOF
  SET ECHO OFF
  WHENEVER SQLERROR EXIT SQL.SQLCODE;
  $unlock_sql
  EXIT;
EOF

  # Verificar el resultado de la operación
  if [ $? -eq 0 ]; then
    log "Usuario DBSNMP desbloqueado exitosamente en la instancia '$instance'."
  else
    log_error "Error al desbloquear el usuario DBSNMP en la instancia '$instance'."
  fi

done

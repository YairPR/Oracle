#!/bin/bash

# Archivo de log
LOGFILE="/tmp/dbsnmp_unlock.log"

# Comandos SQL para desbloquear y cambiar la contraseña del usuario dbsnmp
unlock_sql="ALTER USER dbsnmp ACCOUNT UNLOCK;"
change_password_sql="ALTER USER dbsnmp IDENTIFIED BY astsys09;"

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

# Definición de funciones para configurar el entorno
proscore() {
  unset ORACLE_HOME
  ORACLE_SID=proscosb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/1900/proscore; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

proemex() {
  unset ORACLE_HOME
  ORACLE_SID=proemxsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/proemer; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

proemer() {
  unset ORACLE_HOME
  ORACLE_SID=proemrsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/proemer; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

procore() {
  unset ORACLE_HOME
  ORACLE_SID=procoresb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/procore; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

probdu() {
  unset ORACLE_HOME
  ORACLE_SID=probdusb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/probdu; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

prorhap() {
  unset ORACLE_HOME
  ORACLE_SID=prorhapsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/prorhap; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

prorec() {
  unset ORACLE_HOME
  ORACLE_SID=prorecsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/prorec; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

prosil() {
  unset ORACLE_HOME
  ORACLE_SID=prosilsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/prosil; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

proser() {
  unset ORACLE_HOME
  ORACLE_SID=prosersb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/11204/proser; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

proplaza() {
  unset ORACLE_HOME
  ORACLE_SID=proplazb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/1900/proplaza; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

prolab() {
  unset ORACLE_HOME
  ORACLE_SID=prolabsb1; export ORACLE_SID
  ORACLE_HOME=/u01/app/oracle/product/1900/prolab; export ORACLE_HOME
  ORACLE_GG=Sync_nodo_2
  LD_LIBRARY_PATH=$ORACLE_HOME/lib; export LD_LIBRARY_PATH
  NLS_LANG=american_america.al32utf8; export NLS_LANG
  PATH=~/scripts:/usr/bin:/usr/sbin:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch; export PATH
}

# Función para configurar el entorno de Oracle
set_oracle_env() {
  local sid=$1

  # Llamar a la función específica según la instancia
  case $sid in
    proscosb1) proscore ;;
    proemxsb1) proemex ;;
    proemrsb1) proemer ;;
    procoresb1) procore ;;
    probdusb1) probdu ;;
    prorhapsb1) prorhap ;;
    prorecsb1) prorec ;;
    prosilsb1) prosil ;;
    prosersb1) proser ;;
    proplazb1) proplaza ;;
    prolabsb1) prolab ;;
    *) log_error "No hay configuración definida para la instancia '$sid'. Omitiendo..." ;;
  esac
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

  log "Conectando a la instancia '$ORACLE_SID' con ORACLE_HOME='$ORACLE_HOME'..."

  # Conectar y ejecutar los comandos SQL
  sqlplus_output=$($ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
  connect / as sysdba
  WHENEVER SQLERROR EXIT SQL.SQLCODE
  $unlock_sql
  $change_password_sql
  EXIT;
EOF
)

  # Verificar si los comandos se ejecutaron correctamente
  sqlplus_status=$?
  if [ $sqlplus_status -eq 0 ]; then
    log "Desbloqueo y cambio de contraseña ejecutados correctamente en '$ORACLE_SID'."
  else
    log_error "Error al ejecutar los comandos en '$ORACLE_SID'."
    log_error "Detalles del error: $sqlplus_output"
  fi

done

log "Proceso completado."

#!/bin/bash

# Archivo de log
LOGFILE="/tmp/dbsnmp_unlock.log"

# Comandos SQL para desbloquear y cambiar la contraseña del usuario dbsnmp
unlock_sql="ALTER USER DBSNMP IDENTIFIED BY astsys09;"

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

# Función para ejecutar comandos SQL en una instancia
execute_sql() {
  local sid=$1
  local sql=$2

  # Configurar el entorno para la instancia
  case $sid in
    prescore1) prescore ;;
    omip1001) omip100 ;;
    preraims1) preraims ;;
    dept1001) dept100 ;;
    precore1) precore ;;
    prerhap1) prerhap ;;
    preecon1) preecon ;;
    gace1001) gace100 ;;
    prerec1) prerec ;;
    preemer1) preemer ;;
    presil1) presil ;;
    prebdu1) prebdu ;;
    preplaza1) preplaza ;;
    *)
      log_error "No hay configuración definida para la instancia '$sid'. Omitiendo..."
      return 1
      ;;
  esac

  # Ejecutar el comando SQL para desbloquear al usuario DBSNMP
  log "Ejecutando el desbloqueo del usuario DBSNMP en la instancia '$sid'..."
  sqlplus -s / as sysdba <<EOF
  SET ECHO OFF
  WHENEVER SQLERROR EXIT SQL.SQLCODE;
  $sql
  EXIT;
EOF

  # Verificar el resultado de la operación
  if [ $? -eq 0 ]; then
    log "Usuario DBSNMP desbloqueado exitosamente en la instancia '$sid'."
  else
    log_error "Error al desbloquear el usuario DBSNMP en la instancia '$sid'."
  fi
}

# Limpiar archivo de log anterior
> $LOGFILE

# Leer las instancias desde el archivo .bash_profile
source /export/home/oracle/.bash_profile

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

  # Ejecutar el comando SQL para desbloquear al usuario DBSNMP
  execute_sql $instance "$unlock_sql"
done

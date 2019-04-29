####################################################
##Shell: alert_tablespace.sh                      ##
##Descripcion: Monitorea el espacio de TABLESPACE ##
##DBA: E. Yair Purisaca Rivera                    ##
##Email: eddiepurisaca@gmail.com                  ##
##Version: 4.0			                              ##
####################################################

#!/bin/bash
set -x

####### Inicio de Configuración

######## Variables de entorno Oracle ##########

. /home/oracle/.bash_profile
datevar=$(date)
datevar2=$(date "+%Y-%m-%d-%H-%M")

####### Fin de Configuración
path=/home/oracle/scripts/alertasbd
html=/home/oracle/scripts/alertasbd/tablespace.html

cd $path
## el query solo es el primer del dba
sqlplus / as sysdba @$path/metric_tbs.sql

egrep -q "MB" $html
if (( $?=="0" )); then
echo "SE ENVIA"
 mutt -e "set content_type=text/html" eddiepurisaca@gmail.com, otheremail@oracle.com -s "Alerta Tablespace mas del 80% de uso" < $html
else
echo "No hay TBS" >> /tmp/rep.html
#####cat /tmp/rep.html | mail -s "PRODUCCIÓN - % Tablespace en uso para ${ORACLE_SID} - $datevar" $DBALIST
fi

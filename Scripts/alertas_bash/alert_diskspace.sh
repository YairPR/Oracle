#!/bin/sh
set -x
##########################################################################
#@Author: E. Yair Purisaca Rivera
#@Email: eddiepurisaca@gmail.com
#@Version: 2.0
#@Descripcion: Proceso para revisar el espacio de los FileSystem 
##########################################################################
. /home/oracle/.bdutec

#Variables
autenticacion='/ as sysdba'

path=/home/oracle/scripts/monitor
alert=/home/oracle/scripts/monitor/alert.lst

truncate $alert --size 0

df -Ph | grep -vE '^Filesystem|tmpfs|cdrom|proc|boot' | awk '{ print $6 " " $5 " " $4}' | while read output;
do
  usep=$(echo $output | awk '{ print $2}' | cut -d '%' -f 1  )
  partition=$(echo $output | awk '{ print $1 }' ) 
  freespace=$(echo $output | awk '{ print $3 }' )

  if [ $usep -ge 90 ]; then
	 echo $output >> $alert
	###echo -e "El Filesystem esta llegando al maximo de expacio permitido "$(hostname)"\n$output" | mail -s "Espacio Filesystem $partition" $DBALIST	
	
  fi
done

cd $path
sh ./generate_diskspace.sh

####mailx -s "UTEC - Alerta Espacio Filesystem" $DBALIST < $alert

if [ `cat $alert|wc -l` -gt 0 ]
then
	mutt -e "set content_type=text/html" eddiepurisaca@gmail.com -s "Alerta Espacio Filesystem" < $path/diskspace_alert.html
fi


#rm -f $alert
exit

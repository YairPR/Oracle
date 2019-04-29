#!/bin/sh
set -x
#######################################################################
#Autor: E. Yair Purisaca R.
#Version: 1.0
#Advisor de sistema operativo
#######################################################################
ini_proc=`date +%H:%M:%S`
fin_proc=`date +%H:%M:%S`
mkdir -p /home/oracle/scripts/monitor/diario/logs/linux/"`date +%Y%m%d`" 
file_log=/home/oracle/scripts/monitor/diario/logs/linux/"`date +%Y%m%d`"/monso_`date +%Y%m%d`_`date +%H%M%S`.log

echo "#########################################" > $file_log
echo "Monitoreo Oracle Linux 6.6 v0.1" >> $file_log
echo "#########################################" >> $file_log
echo " ">> $file_log
echo "=====================================" >> $file_log
echo "ServerName, Date, UPtime" >> $file_log
echo "=====================================" >> $file_log
echo "Fecha : `date`" >> $file_log
echo "Nombre de Host : `hostname`" >> $file_log
echo "Version OS: `cat /etc/*release | sed -n 2p`" >> $file_log
architecture=$(uname -m)
echo "Arquitectura :" $architecture  >> $file_log
kernelrelease=$(uname -r)
echo "Kernel Release :" $kernelrelease  >> $file_log
tecuptime=$(uptime | awk '{print $3,$4}' | cut -f1 -d,)
echo "Tiempo en Linea del Servidor:" $tecuptime  >> $file_log
echo " " >> $file_log
echo "=====================================" >> $file_log
echo "Usuarios conectados" >> $file_log
echo "=====================================" >> $file_log
echo "`who`" >> $file_log
echo " " >> $file_log
echo "=====================================" >> $file_log
echo "Informacion de CPU." >> $file_log
echo "=====================================" >> $file_log
echo "CPU : ` cat  /proc/cpuinfo | grep "core id" | wc -l`" >> $file_log
echo  "CPU Used : ` mpstat 1 1 | awk '/^Average/ {print 100-$NF,"%"}'`" >> $file_log
loadaverage=$(top -n 1 -b | grep "load average:" | awk '{print $14}')
echo "Carga Media del CPU en los ultimos 15 minutos :" $loadaverage >> $file_log
echo " " >> $file_log
echo "=====================================" >> $file_log
echo "Informacion del uso de Memoria" >> $file_log
echo "=====================================" >> $file_log
vmstat -s | grep memory > /tmp/meminfo
im=/tmp/meminfo
tm=$(cat $im | grep "total" | awk '{printf($1/1024/1024)}')
mu=$(cat $im | sed -n 2p | awk '{printf($1/1024/1024)}')
ml=$(cat $im | grep "free" | awk '{printf($1/1024/1024)}')
echo "Memoria `printf 'Total : %.2f ' $(echo "$tm")`" $(echo "Gb") >> $file_log
echo "Memoria `printf 'Usada : %.2f ' $(echo "$mu/$tm*100.00"  | bc -l)`" $(echo "%") >> $file_log
echo "Memoria `printf 'libre : %.2f ' $(echo "$ml/$tm*100.00"  | bc -l)`" $(echo "%")>> $file_log
echo "--------------------------------------">> $file_log
echo " " >> $file_log
echo "=====================================" >> $file_log
echo "Nro. de procesos sobre el SERVER" >> $file_log
echo "=====================================" >> $file_log
echo "Total procesos sobre el server : `ps -ef | wc -l`" >> $file_log
echo "Total de procesos Oracle: ` ps -ef | grep -Ev '^grep|egrep' | egrep "ora_|oraclebdutec01" | wc -l ` " >> $file_log
echo " " >> $file_log
echo "=====================================" >> $file_log
echo "Top CPU, Memory, IO pro." >> $file_log
echo "=====================================" >> $file_log
echo " " >> $file_log
echo "-Top 10 procesos CPU" >> $file_log
echo "----------------------------------------" >> $file_log
ps -eo pid,comm,%cpu | sort -rnk 3 | head -11 > /tmp/cputop
cat /tmp/cputop | awk '{printf $1 "\t"} {printf $2 "\t"} {print $3}'>> $file_log
echo "----------------------------------------" >> $file_log
echo " " >> $file_log
echo "-Top 10 procesos de memoria" >> $file_log
echo "-----------------------------------------" >> $file_log
ps axo user,%mem,rss,comm | sort -k2r  | head -n 11 > /tmp/memtop
cat /tmp/memtop | awk '{printf $1 "\t"} {printf $2 "\t"} {printf $3 "\t"} {print $4}'  >> $file_log
echo "-----------------------------------------" >> $file_log
echo " " >> $file_log
echo "**Total de Memoria Usada por proceso" >> $file_log
echo "-----------------------------------------" >> $file_log
ps axo rss,comm | head -1  > /tmp/memtoptot
 ps axo rss,comm,pid | awk '{ proc_list[$2] += $1; } END { for (proc in proc_list) { printf("%d\t%s\n", proc_list[proc],proc); }}' | sort -n | tail -n 10 | sort -rn | awk '{$1/=1024;printf "%.2f \t\t",$1}{print $2}' >> /tmp/memtoptot
cat /tmp/memtoptot | awk '{printf  $1 "Mb\t\t"} {print $2}' >> $file_log
echo "-----------------------------------------" >> $file_log 
echo " " >> $file_log
echo "-Top 10 I/O" >> $file_log
echo "-----------------------------------------" >> $file_log
echo " " >> $file_log
iostat -m -d  | sed "1d;2d" | head -1 >> $file_log 
iostat -m -d  | sed "1d;2d" | sort -k2rn  | head -10 >> $file_log
echo "-----------------------------------------" >> $file_log
echo " " >> $file_log
echo "==========================================" >> $file_log
echo "Informacion de puntos de montaje" >> $file_log
echo "==========================================" >> $file_log
echo " " >> $file_log
df -Ph | head -1 | awk '{ print $6 "\t " $5 "\t " $4}' >> $file_log 
df -Ph | grep -vE '^Filesystem|tmpfs|cdrom|proc|boot' | awk '{ print $6 "\t " $5 "\t " $4}' >> $file_log
echo " " >> $file_log
echo "==========================================" >> $file_log
echo "Estadisticas de red" >> $file_log
echo "==========================================" >> $file_log
###netstat -antp | sed "1d" | head -1 >> $file_log 
echo " " >> $file_log
echo "-Conexiones por el puerto 1521 Oracle: ` netstat -antp 2>/dev/null | grep 1521 | wc -l `" >> $file_log
echo " ">> $file_log
echo "------------------------------------------" >> $file_log
echo "-Puertos abiertos en el servidor:" >>  $file_log
echo " " >> $file_log
echo "Nro Puerto:" >> $file_log
netstat -lnt | awk 'NR>2{print "\t" $4}' | grep -E '(0.0.0.0:|:::)' | sed 's/.*://' | sort -n | uniq > /tmp/portnumber
cat /tmp/portnumber | awk '{printf "\n\t" $1}'>> $file_log
echo -e "\n------------------------------------------" >> $file_log
echo " " >> $file_log
echo "-IPs conectadas al servidor y total de conexiones:"  >>  $file_log
echo " " >> $file_log
echo -e "Total Conexiones \tIP" >>  $file_log
echo "------------------------------------------" >>  $file_log
netstat -ntu   | awk ' $5 ~ /^(::ffff:|[0-9|])/ { gsub("::ffff:","",$5); print "\t" $5}' | cut -d: -f1 | sort | uniq -c | sort -nr >> $file_log
echo "------------------------------------------" >> $file_log
echo " " >> $file_log
echo "===============================================" >> $file_log
echo "DSTAT: Muestra Estadisticas de CPU - RAM - RED " >> $file_log
echo "       en tiempo real de un lapso de 10 segundos" >> $file_log
echo "================================================\n" >> $file_log
echo "` dstat -tcmsn -N eth0 1 10`" >> $file_log
echo " " >> $file_log
echo "**********************************************" >> $file_log
echo "*~> Desarrollado por: E. Yair Purisaca Rivera*" >> $file_log
echo "**********************************************" >> $file_log

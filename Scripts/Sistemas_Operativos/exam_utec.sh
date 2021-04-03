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

echo "=====================================" >> $file_log
echo "Informacion del uso de Memoria" >> $file_log
echo "=====================================" >> $file_log
vmstat -s | grep memory > /tmp/meminfo
im=/tmp/meminfo
tm=$(cat $im | grep "total" | awk '{printf($1/1024/1024)}')
mu=$(cat $im | sed -n 2p | awk '{printf($1/1024/1024)}')
ml=$(cat $im | grep "free" | awk '{printf($1/1024/1024)}')


#Variables
autenticacion='/ as sysdba'


tsesion=$(sqlplus -s $autenticacion  << EOF
set pagesize 0 feedback off verify off heading off echo off;
show user;
SELECT 'Date: '||to_char(sysdate,'DD-MM-YYYY HH24:MI')||' The test is passed' from dual;
exit;
EOF
)

tactive=$(sqlplus -s $autenticacion  << EOF
set pagesize 0 feedback off verify off heading off echo off;
show user;
SELECT 'Date: '||to_char(sysdate,'DD-MM-YYYY HH24:MI')||' The test is passed' from dual;
exit;
EOF
)

echo $tm $mu $tsesion $tactive
echo "**********************************************" >> $file_log
echo "*~> Desarrollado por: E. Yair Purisaca Rivera*" >> $file_log
echo "**********************************************" >> $file_log

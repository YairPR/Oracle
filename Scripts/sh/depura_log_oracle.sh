#!/bin/ksh

ORACLE_BASE=/oracle/app/oracle
ORACLE_HOME=/oracle/app/oracle/product/11.2.0/db_1

#lst_dbs="bdrucp calcarpu bo42pro maxwdp gwportap rdigsmsp mxrpfp esxdbp oraoldp DBCOPRD maxrpp IASAPP esxdbtx caaxadb"
lst_dbs="PROD"

w_nodo=
FECHA=`date '+%Y%m%d'`

for w_name in `echo $lst_dbs`
do
   w_db=`echo $w_name | dd conv=lcase 2> /dev/null`
   w_inst="${w_name}${w_nodo}"
   echo "DB=[$w_db] Instancia[$w_inst]"

   if [ -d  ${ORACLE_BASE}/diag/rdbms/${w_db}/${w_inst}/alert ] ; then
      cd ${ORACLE_BASE}/diag/rdbms/${w_db}/${w_inst}/alert
      pwd
      rm -f log_*xml
   fi

   if [ -d ${ORACLE_BASE}/diag/rdbms/${w_db}/${w_inst}/trace ] ; then
      cd ${ORACLE_BASE}/diag/rdbms/${w_db}/${w_inst}/trace
      pwd
      find . -name '*trc' -mtime +5 -exec rm -f {} \;
      find . -name '*trm' -mtime +5 -exec rm -f {} \;
      mv alert_${w_inst}.log alert_${w_inst}_${FECHA}.log 
      >  alert_${w_inst}.log
      gzip alert_${w_inst}_${FECHA}.log &
   fi
   if [ -d  $ORACLE_BASE/admin/$w_name/adump ] ; then
      cd $ORACLE_BASE/admin/$w_name/adump
      pwd
      find . -mtime +5 -exec rm -f {} \;
   fi
done
wait

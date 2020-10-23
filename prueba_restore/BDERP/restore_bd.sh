oracle@:/oracle/scripts/restore/BDERP>cat restore_bd.sh
export FECHA=`date +%Y.%m.%d`
rman catalog RCATBDERP/catalogo@bdrman target / cmdfile "restore_bd.sql" msglog "restore_bd_$FECHA.log"

export FECHA=`date +%Y.%m.%d`
rman catalog RCATBDAPP/catalogo@bdrman target / cmdfile "restore_bd.sql" msglog "restore_bd_$FECHA.log"

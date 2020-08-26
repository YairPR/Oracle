export FECHA=`date +%Y.%m.%d`
rman catalog RCATBDCONTAP9/catalogo@bdrman target / cmdfile "restore_bd.sql" msglog "restore_bd_$FECHA.log"

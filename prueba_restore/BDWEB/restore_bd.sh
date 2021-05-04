export FECHA=`date +%Y.%m.%d`
rman catalog RCATBDWEBP9/catalogo@bdrman target / cmdfile "restore_bd.sql" msglog "restore_bd_$FECHA.log"

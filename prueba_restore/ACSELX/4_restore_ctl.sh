sqlplus "/ as sysdba" @sube_nomount.sql
rman catalog rcatalprod/catalogo@bdrman target / cmdfile "restore_ctl.sql"

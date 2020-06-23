[oracle@DWHPRO scripts]$ cat move_datafile.sh
#!/bin/sh
##set -x
cd /home/oracle/scripts
cat /dev/null > size_datafile_PRIDWH.log
LOGDIR=/home/oracle/scripts/logs
#---FECHA_MES_ANT=`TZ=CST+2160 date +%m%y`
FECHA=`date +'%Y%m%d'`
LOGFILE=$LOGDIR/move_datafile_$FECHA.log
location_fs=$1
echo Proceso para mover datafile  >> $LOGFILE
${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
ALTER SESSION SET CONTAINER=PDB1;
prompt
prompt TOP 15 DATAFILES
prompt
@listdf.sql $location_fs
prompt
prompt DATAFILES A MIGRAR:
prompt
@lista_dbf.sql $location_fs
exit
EOF
echo >> $LOGFILE
echo Lista top15 de datafiles a mover: >> $LOFILE
       cat size_datafile_PRIDWH.log >> $LOGFILE

echo >> $LOGFILE
echo Datafiles a migrar: >> $LOGFILE
       cat exe_mv_df.sql >>  $LOGFILE
echo >> $LOGFILE
echo Iniciando comando move datafile.. >> $LOGFILE.

${ORACLE_HOME}/bin/sqlplus "/ as sysdba" <<EOF
ALTER SESSION SET CONTAINER=PDB1;
@exe_mv_df.sql
exit
EOF

*QAS* oraqas@devdb:/home/oraqas> cat baja_bd_wsnt_nolog.sh
##
# Oracle environment variables
#
export AIXTHREAD_SCOPE=S
export ORACLE_BASE=/QAS/u01/app/oracle
export ORACLE_HOME=$ORACLE_BASE/product/10.2.0/db_1
export LIBPATH=$ORACLE_HOME/lib:$ORACLE_HOME/lib32
export PATH=$PATH:$ORACLE_HOME/bin:$ORACLE_HOME/OPatch
export TMP=/QAS/u01/tmp
export TMPDIR=/QAS/u01/tmp
export ORACLE_SID=qaswsnt


#LOGDIR=/tmp
#FECHA=`date +'%Y%m%d-%H%M' `
#LOGFILE=$LOGDIR/baja_bd_qaswsnt_$FECHA.log

############################
#  Baja la base de datos
#
############################

#cd $LOGDIR
#echo "=== Bajando  BD QASWSNT :  `date` ===" > $LOGFILE
baja ()
{
$ORACLE_HOME/bin/sqlplus /nolog  << EOF
connect / as sysdba
alter system switch logfile;
alter system switch logfile;
alter system switch logfile;
shutdown immediate;
quit
EOF
}
baja

#echo "=== Fin del script Bajar BD $ORACLE_SID  : `date` ===" >> $LOGFILE
#echo "=== Fin del script Bajar BD $ORACLE_SID  : `date` ===" >> $LOGFILE

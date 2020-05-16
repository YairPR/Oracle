Step 1:
=================================================
check parameters: pfile primario
set lines 900 pages 300
col name for a29;
col value for a132;
select name, value
from v$parameter
where name in
('log_archive_dest_1','log_archive_dest_2','log_archive_config','log_archive_dest_state_1', 'log_archive_dest_state_2', 'standby_archive_dest',
'fal_client', 'fal_server', 'standby_file_management', 'remote_login_passwordfile','instance_name',
'log_file_name_convert','db_file_name_convert','sec_case_sensitive_logon','service_names','local_listener', 'remote_listener', 'db_name', 'db_unique_name');

NAME                          VALUE
----------------------------- ------------------------------------------------------------------------------------------------------------------------------------
db_file_name_convert
log_file_name_convert
log_archive_dest_1            LOCATION=USE_DB_RECOVERY_FILE_DEST REOPEN=60
log_archive_dest_2            SERVICE=P2KPROD_C NOAFFIRM ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=P2KCTG
log_archive_dest_state_1      enable
log_archive_dest_state_2      DEFER
standby_archive_dest          ?/dbs/arch
fal_client                    P2KPROD_P
fal_server                    P2KPROD_C
log_archive_config            dg_config=(P2KPROD,P2KCTG)
standby_file_management       AUTO
sec_case_sensitive_logon      FALSE
remote_login_passwordfile     EXCLUSIVE
instance_name                 P2KPROD
service_names                 P2KPROD.500030657.pe2.internal
local_listener                P2KPROD
remote_listener
db_name                       P2KPROD
db_unique_name                P2KPROD



EJEMPLOS:
PDT: TOMADO DEL DOC: EXACTUS
alter system set log_archive_dest_1 = 'LOCATION=USE_DB_RECOVERY_FILE_DEST REOPEN=60 VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=EXACTUS' scope = both;
alter system set log_archive_dest_2 = 'SERVICE=EXACTUS_C NOAFFIRM ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=EXACTUS_C' scope = both;
alter system set log_archive_dest_state_1 = 'enable' scope = both;
alter system set log_archive_dest_state_2 = 'enable' scope = both;
alter system set fal_server = 'EXACTUS_C' scope = both;
alter system set log_archive_config = 'DG_CONFIG=(EXACTUS,EXACTUS_C)' scope = both;
alter system set standby_file_management = 'AUTO' scope = both;
alter system set sec_case_sensitive_logon = 'FALSE' scope = both;
alter system set remote_login_passwordfile = 'EXCLUSIVE' scope = both;
alter system set db_file_name_convert = '/u02/app/oracle/oradata/EXACTUS_C','/u02/app/oracle/oradata/EXACTUS' scope = spfile;

Con excepción del parámetro de inicio “ db_file_name_convert ” se podrán verificar los valores, ya que
requiere reinicio de la instancia, para poder ver el nuevo valor de dicho parámetro.

---------------------------------------------------------------------------------------------------------------------------------------------
Step 2:
=========================================================================================
TNSNAMES PRIMARIO: P2KPROD

P2KPROD =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = P2KPRO.compute-500030657.pe2.internal)(PORT = 1567))
    (CONNECT_DATA = (SERVER = DEDICATED) (SERVICE_NAME = P2KPROD.500030657.pe2.internal) ) )


# Configuracion DG
P2KPROD_P =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.75.38.117)(PORT = 1567))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = P2KPROD.500030657.pe2.internal)
      (UR=A)
    )
  )

P2KPROD_C =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.75.40.106)(PORT = 1567))
      (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = P2KPROD.500029642.pe1.internal)
      (UR=A)
    )
  )

------------------------------------------------------------------------------------------------------------------------------------------------------------
Step 3:
===================================================================
-- RETENCION ARCHIVES PRIMARIO
rmam:
Configure archivelog deletion policy to shipped to all standby;
-------------------------------------------------------------------------------------------------------------------------------------------------------------
Step 4:
========================================================================
-- CREAR PFILE DEL PRIMARIO Y COPIARLO A CONTINGENCIA
create pfile=’/tmp/initEXACTUS_stby.ora’ from spfile;

-- PASSWORD FILE
ls -ltr $ORACLE_HOME/dbs/orapw*
orapwd file=orapwP2KPROD password=Afp2020prim4 ignorecase=y entries=25
------------------------------------------------------------------------------------------------------------------------------------------------------------
Step 5:
===========================================================================
--- TNSNAMES CONTINGENCIA:

[oracle@P2KCONT dbs]$ cat /u01/app/oracle/product/11.2.0/dbhome_1/network/admin/tnsnames.ora

P2KPROD =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.75.38.117)(PORT = 1567))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = P2KPROD.500030657.pe2.internal)
    )
  )

# Configuracion DG
P2KPROD_P =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.75.38.117)(PORT = 1567))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = P2KPROD.500030657.pe2.internal)
      (UR=A)
    )
  )

P2KPROD_C =
  (DESCRIPTION =
    (SDU=65535)
    (RECV_BUF_SIZE=10485760)
    (SEND_BUF_SIZE=10485760)
    (ADDRESS = (PROTOCOL = TCP)(HOST = 10.75.40.106)(PORT = 1567))
      (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = P2KPROD)
      (UR=A)
    )
  )

-----------------------------------------------------------------------------------------------------------------------------------------------------------------
Step 6:
====================================================================0
--LISTENER CONTINGENCIA

[oracle@P2KCONT dbs]$ cat /u01/app/oracle/product/11.2.0/dbhome_1/network/admin/listener.ora
# listener.ora Network Configuration File: /u01/app/oracle/product/11.2.0/dbhome_1/network/admin/listener.ora
# Generated by Oracle configuration tools.

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1567))
      (ADDRESS = (PROTOCOL = TCP)(HOST = P2KCONT.compute-500029642.pe1.internal)(PORT = 1567))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (SDU=65535)
      (GLOBAL_DBNAME = P2KPROD)
      (ORACLE_HOME = /u01/app/oracle/product/11.2.0/dbhome_1)
      (SID_NAME = P2KPROD)
    )
  )

ADR_BASE_LISTENER = /u01/app/oracle
VALID_NODE_CHECKING_REGISTRATION_LISTENER=ON
SSL_VERSION = 1.2
[oracle@P2KCONT dbs]$
***************************************
---> lsnrctl reload
***************************************
---------------------------------------------------------------------------------------------------------------------------------------
Step 7:
=========================================================================================
CREAR INIT CONTINGENCIA
init actual USADO PARA EL DUPLICATE

[oracle@P2KCONT dbs]$ cat initP2KPROD.ora
P2KPROD.__db_cache_size=40265318400
P2KPROD.__java_pool_size=268435456
P2KPROD.__large_pool_size=268435456
P2KPROD.__oracle_base='/u01/app/oracle'#ORACLE_BASE set from environment
P2KPROD.__pga_aggregate_target=14898167808
P2KPROD.__sga_target=42949672960
P2KPROD.__shared_io_pool_size=0
P2KPROD.__shared_pool_size=1879048192
P2KPROD.__streams_pool_size=0
*._gby_hash_aggregation_enabled=FALSE
*.aq_tm_processes=1
*.audit_file_dest='/u01/app/oracle/admin/P2KPROD/adump'
*.audit_sys_operations=TRUE
*.audit_trail='DB'
*.compatible='11.2.0.4.0'
*.control_file_record_keep_time=7
*.control_files='/u02/app/oracle/oradata/P2KPROD/control01.ctl','/u03/app/oracle/fast_recovery_area/P2KPROD/control02.ctl'
*.control_management_pack_access='DIAGNOSTIC+TUNING'
*.cursor_sharing='SIMILAR'
*.db_block_size=8192
*.db_cache_size=6G
*.db_create_file_dest='/u02/app/oracle/oradata'
*.db_domain='500029642.pe1.internal'
*.db_file_name_convert='/u02/app/oracle/oradata/P2KPROD','/u02/app/oracle/oradata/P2KCTG'
*.db_files=2500
*.db_name='P2KPROD'
*.db_recovery_file_dest='/u03/app/oracle/fast_recovery_area'
*.db_recovery_file_dest_size=987842478080
*.db_unique_name='P2KCTG'
*.db_writer_processes=4
*.diagnostic_dest='/u01/app/oracle'
*.dml_locks=8000
*.enable_ddl_logging=FALSE
*.encrypt_new_tablespaces='CLOUD_ONLY'
*.fal_client='P2KPROD_C'
*.fal_server='P2KPROD_P'
*.fast_start_mttr_target=1800
*.filesystemio_options='setall'
*.instance_name='P2KPROD'
*.java_pool_size=256M
*.job_queue_processes=200
*.large_pool_size=128M
*.local_listener='(ADDRESS=(PROTOCOL=tcp)(HOST=P2KCONT.compute-500029642.pe1.internal)(PORT=1567))'
*.lock_sga=TRUE
*.log_archive_config='dg_config=(P2KPROD,P2KCTG)'
*.log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST REOPEN=60'
*.log_archive_dest_2='SERVICE=P2KPROD_P NOAFFIRM ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=P2KPROD'
*.log_archive_format='arch_%r_%t_%s.arc'
*.log_buffer=67108864
*.max_dump_file_size='134217728'
*.open_cursors=600
*.optimizer_index_cost_adj=40
*.optimizer_mode='CHOOSE'
*.pga_aggregate_target=14843260800
*.processes=2000
*.remote_dependencies_mode='SIGNATURE'
*.remote_login_passwordfile='EXCLUSIVE'
*.resumable_timeout=36000
*.sec_case_sensitive_logon=FALSE
*.sec_protocol_error_further_action='DROP','3'
*.sec_protocol_error_trace_action='LOG'
*.service_names='P2KPROD.500029642.pe1.internal'
*.session_cached_cursors=300
*.sessions=3040
*.sga_max_size=40G
*.sga_target=40G
*.shared_pool_size=1408M
*.sql92_security=TRUE
*.standby_file_management='AUTO'
*.timed_os_statistics=10
*.transactions=2000
*.undo_retention=86400
*.undo_tablespace='UNDOTBS1'


--------------------------------------------------------------------------------------------------
PARAMETROS ANTIGUOS
COMPARACION: ANTIGUO NO FUNCIONA

[oracle@P2KCONT dbs]$ cat initP2KPROD.ora_ori_12052020
P2KPROD.__db_cache_size=40265318400
P2KPROD.__java_pool_size=268435456
P2KPROD.__large_pool_size=268435456
P2KPROD.__oracle_base='/u01/app/oracle'#ORACLE_BASE set from environment
P2KPROD.__pga_aggregate_target=14898167808
P2KPROD.__sga_target=42949672960
P2KPROD.__shared_io_pool_size=0
P2KPROD.__shared_pool_size=1879048192
P2KPROD.__streams_pool_size=0
*._gby_hash_aggregation_enabled=FALSE
*.aq_tm_processes=1
*.audit_file_dest='/u01/app/oracle/admin/P2KPROD/adump'
*.audit_sys_operations=TRUE
*.audit_trail='DB'
*.compatible='11.2.0.4.0'
*.control_file_record_keep_time=7
*.control_files='/u02/app/oracle/oradata/P2KPROD/control01.ctl','/u03/app/oracle/fast_recovery_area/P2KPROD/control02.ctl'
*.control_management_pack_access='DIAGNOSTIC+TUNING'
*.cursor_sharing='SIMILAR'
*.db_block_size=8192
*.db_cache_size=6G
*.db_create_file_dest='/u02/app/oracle/oradata'
*.db_domain='500029642.pe1.internal'
*.db_files=2500
*.db_name='P2KPROD'
*.db_recovery_file_dest='/u03/app/oracle/fast_recovery_area'
*.db_recovery_file_dest_size=987842478080
*.db_unique_name='P2KCTG'
*.db_writer_processes=4
*.dg_broker_config_file1='/u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr1P2KCTG.dat'
*.dg_broker_config_file2='/u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr2P2KCTG.dat'
*.dg_broker_start=TRUE
*.diagnostic_dest='/u01/app/oracle'
*.dml_locks=8000
*.enable_ddl_logging=FALSE
*.encrypt_new_tablespaces='CLOUD_ONLY'
*.fal_client='P2KPROD_C'
*.fal_server='P2KPROD_P'
*.fast_start_mttr_target=1800
*.filesystemio_options='setall'
*.java_pool_size=256M
*.job_queue_processes=200
*.large_pool_size=128M
*.local_listener='(ADDRESS=(PROTOCOL=tcp)(HOST=P2KCONT.compute-500029642.pe1.internal)(PORT=1567))'
*.lock_sga=TRUE
*.log_archive_config='dg_config=(P2KPROD,P2KCTG)'
*.log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST REOPEN=60'
*.log_archive_dest_2='SERVICE=P2KPROD_P NOAFFIRM ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=P2KPROD'
*.log_archive_format='arch_%r_%t_%s.arc'
*.log_buffer=67108864
*.max_dump_file_size='134217728'
*.open_cursors=600
*.optimizer_index_cost_adj=40
*.optimizer_mode='CHOOSE'
*.pga_aggregate_target=14843260800
*.processes=2000
*.remote_dependencies_mode='SIGNATURE'
*.remote_login_passwordfile='EXCLUSIVE'
*.resumable_timeout=36000
*.sec_case_sensitive_logon=FALSE
*.sec_protocol_error_further_action='DROP','3'
*.sec_protocol_error_trace_action='LOG'
*.service_names='P2KPROD.500029642.pe1.internal'
*.session_cached_cursors=300
*.sessions=3040
*.sga_max_size=40G
*.sga_target=40G
*.shared_pool_size=1408M
*.sql92_security=TRUE
*.standby_file_management='AUTO'
*.timed_os_statistics=10
*.transactions=2000
*.undo_retention=86400
*.undo_tablespace='UNDOTBS1'

-----------------------------------------------------------------------------------------------------------------------------
Step 8:
====================================================================
STARTUP NOMOUMT
startup nomount pfile=’/tmp/initP2KPROD.ora’

** Validación de conexión
Desde el servidor de CONTINGENCIA hacia el PRIMARY;
sqlplus sys/Welcome##123@P2KPROD_P as sysdba
Desde el servidor PRIMARIO hacia el STANDBY;
sqlplus sys/Welcome##123@P2KPROD_C as sysdba

-----------------------------------------------------------------------------------------------------------
Step 9:
====================================================================
DESDE CONTINGENCIA
ARCHIVO DUPLICATE_BD.SH
oracle@P2KCONT scripts]$ cat duplicate_db.sh
export FECHA=`date +%Y.%m.%d`
rman target sys/Pr1m4P2kpr0@P2KPROD_P auxiliary sys/Pr1m4P2kpr0@P2KPROD_C cmdfile "duplicate_bd.sql" msglog "duplicate_bd_$FECHA.log"
-------------------------------------------------------------
ARCHIVO: DUPLICATE_BD.SQL
[oracle@P2KCONT scripts]$ cat duplicate_bd.sql
run{
  allocate channel prmy1 type disk;
  allocate channel prmy2 type disk;
  allocate channel prmy3 type disk;
  allocate channel prmy4 type disk;
  allocate auxiliary channel stby1 type disk;
  allocate auxiliary channel stby2 type disk;
  allocate auxiliary channel stby3 type disk;
  allocate auxiliary channel stby4 type disk;
  allocate auxiliary channel stby5 type disk;
  allocate auxiliary channel stby6 type disk;
  allocate auxiliary channel stby7 type disk;
  allocate auxiliary channel stby8 type disk;
  duplicate target database for standby from active database NOFILENAMECHECK;
}

------------------------------------

Step 10:
==================================================================================
CREATE SPFILE:
create spfile from pfile='/u01/app/oracle/product/11.2.0/dbhome_1/dbs/initP2KPROD.ora';

Una vez creado el spfile, procederemos a reiniciar la instancia para que inicie utilizando spfile
shutdown immediate
startup nomount
---------------------------------------------------------

Step 11:
=================================================================================
Montemos la base de datos standby, ejecutando la siguiente instrucción;
alter database mount standby database;

Ahora procedemos a reiniciar la replicación, ejecutando la siguiente instrucción;
alter database recover managed standby database disconnect from session;

Step 12:
=============================================================================
Una vez iniciada la replicación procedemos a verificar que esta sincronizando:

select sequence#,
first_time,
next_time,
archived,
applied
from v$archived_log
order by sequence#;

Step 13:
========================================================================================
Adicionalmente a la configuración del standby, se realizo la configuración del catalogo de rman
para que solo depure los archivelogs que ya han sido aplicados en la base de datos STANDBY
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
----
Step 14:
=========================================================================================
Por ultimo se agrego un Shell script que se ejecuta a diario, a las 18:30 depurando solo los
archivelogs aplicados en la base de datos STANDBY;
***********************************************************************************
[oracle@EXACONT bin]$ pwd
/u01/app/oracle/admin/EXACTUS/scripts/bin
delete_archivelog_stby.sh
[oracle@EXACONT bin]$
[oracle@EXACONT bin]$
[oracle@EXACONT bin]$ crontab -l
30 18 * * * /u01/app/oracle/admin/EXACTUS/scripts/bin/delete_archivelog_stby.sh > /tmp/delete_archivelog_stby.log 2>&1
[oracle@EXACONT bin]$
[oracle@EXACONT bin]$
[oracle@EXACONT bin]$ cat delete_archivelog_stby.sh
#!/bin/bash
export ORACLE_SID=EXACTUS_C
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/dbhome_1
export
PATH=/sbin:/bin:/usr/sbin:/usr/bin:$ORACLE_HOME/bin:$ORACLE_HOME/OPat
ch:/home/oracle/bin
CMDFILE1=/tmp/purge_standby_arc_${ORACLE_SID}.rman
timefile=/tmp/purge_standby_arc_${ORACLE_SID}.time.txt
lastapplied_seq_=/tmp/purge_standby_arc_${ORACLE_SID}.tmp
$ORACLE_HOME/bin/sqlplus -s /"as sysdba" << EOF > ${lastapplied_seq_}
set pagesize 0
set feedback off
select ' delete noprompt archivelog until sequence '|| max(sequence#)
||' thread '|| thread# ||';' from v\$archived_log where applied =
'YES' and registrar = 'RFS' group by thread#;
exit;
EOF
echo " " > $CMDFILE1
echo " run { " >> $CMDFILE1
echo " allocate channel c1 device type disk; " >> $CMDFILE1
cat ${lastapplied_seq_} >> $CMDFILE1
echo " " >> $CMDFILE1
echo "}" >> $CMDFILE1
$ORACLE_HOME/bin/rman target / nocatalog cmdfile ${CMDFILE1}
exit
[oracle@EXACONT bin]$

***************************************************************************************
Como detener el Dataguard:
Servidor PRIMARIO
Ejecutar la siguiente instrucción a nivel del utilitario sqlplus:
alter system checkpoint;
alter system switch lgofile;
alter system set log_archive_dest_state_2 = ‘defer’ scope =both;
---------------------------------------------------------------------------------------
Servidor STANDBY
Ejecutar la siguiente instrucción desde el utilitario sqlplus, ejecute la siguiente instrucción
alter database recover managed standby database cancel;
=======================================================================================
Como Iniciar el Dataguard
Servidor PRIMARIO
alter system set log_archive_dest_state_2 = ‘enable’ scope = both;

Servidor STANDBY
alter database recover managed standby database cancel;

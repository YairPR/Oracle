--Step By Step How to Recreate Dataguard Broker Configuration (Doc ID 808783.1)

steps recreate broker p2kprod

PRIMARY AND SECONDARY

SQL> show parameter dg_broker_config_file

NAME                                 TYPE                             VALUE
------------------------------------ -------------------------------- ------------------------------
dg_broker_config_file1               string                           /u01/app/oracle/product/11.2.0
                                                                      /dbhome_1/dbs/dr1P2KPROD.dat
dg_broker_config_file2               string                           /u01/app/oracle/product/11.2.0
                                                                      /dbhome_1/dbs/dr2P2KPROD.dat


SQL> ALTER SYSTEM SET DG_BROKER_START=FALSE;

SQL> 
ls -lrt /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr1P2KPROD.dat
-rw-r----- 1 oracle oinstall 8192 Feb 20 21:58 /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr1P2KPROD.dat
[oracle@P2KPRO ~]$ ls -lrt /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr2P2KPROD.dat
-rw-r----- 1 oracle oinstall 8192 Feb 20 21:58 /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr2P2KPROD.dat
[oracle@P2KPRO ~]$
[oracle@P2KPRO ~]$ mv /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr1P2KPROD.dat /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr1P2KPROD.old
[oracle@P2KPRO ~]$ mv /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr2P2KPROD.dat /u01/app/oracle/product/11.2.0/dbhome_1/dbs/dr2P2KPROD.old


SQL> ALTER SYSTEM SET DG_BROKER_START=TRUE;

System altered.

SQL> exit
Disconnected from Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Partitioning and Real Application Testing options
[oracle@P2KPRO ~]$
[oracle@P2KPRO ~]$
[oracle@P2KPRO ~]$ dgmgrl
DGMGRL for Linux: Version 11.2.0.4.0 - 64bit Production

Copyright (c) 2000, 2009, Oracle. All rights reserved.

Welcome to DGMGRL, type "help" for information.
DGMGRL> connect sys
Password:
ORA-01005: null password given; logon denied

DGMGRL> connect sys
Password:
Connected.
DGMGRL>
DGMGRL>  CREATE CONFIGURATION 'p2kprod_active_dg' AS PRIMARY DATABASE IS 'P2KPROD' CONNECT IDENTIFIER IS 'P2KCTG';
Configuration "p2kprod_active_dg" created with primary database "P2KPROD"
DGMGRL> ADD DATABASE P2KCTG AS CONNECT IDENTIFIER IS P2KPROD_C MAINTAINED AS PHYSICAL;
Database "p2kctg" added
DGMGRL> ENABLE CONFIGURATION;
Enabled.
DGMGRL> show configuration

Configuration - p2kprod_active_dg

  Protection Mode: MaxPerformance
  Databases:
    P2KPROD - Primary database
    p2kctg  - Physical standby database

Fast-Start Failover: DISABLED

Configuration Status:
SUCCESS

DGMGRL> show database p2kctg

Database - p2kctg

  Role:            PHYSICAL STANDBY
  Intended State:  APPLY-ON
  Transport Lag:   0 seconds (computed 1 second ago)
  Apply Lag:       0 seconds (computed 1 second ago)
  Apply Rate:      7.37 MByte/s
  Real Time Query: OFF
  Instance(s):
    P2KPROD

Database Status:
SUCCESS

DGMGRL>

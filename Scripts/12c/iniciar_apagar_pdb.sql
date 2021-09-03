How to Stop and Start a Pluggable Database
Oracle Database » How To Guides » Multitenant Mini Guides » How to Stop and Start a Pluggable Database
Introduction
The following explains how to stop and start a the container database and the containers (pluggable databases).

Step-By-Step
1. Shutdown a container database (CDB) and all pluggable databases (PDBs)

sqlplus '/ as sysdba'
SQL> show connection
NB Make sure you are on the root CDB$ROOT
SQL> shutdown immediate
2. Startup the CDB

sqlplus '/ as sysdba'
SQL> startup
Note: When you start a CDB it does not automatically start the PDBs

3. Check the status of the PDBs

sqlplus '/ as sysdba'
SQL> select name, open_mode from v$pdbs;
Note: Any PDBs are in mounted status.

4. Start a PDB

sqlplus '/ as sysbda'
SQL> alter pluggable database myplugdb3 open;
NB This will open pluggable database myplugdb3.
SQL> alter pluggable database all open;
NB This will open all pluggable databases.
5. Stop a PDB

sqlplus '/ as sysdba'
SQL> alter pluggable database myplugdb3 close immediate;
NB This will close pluggable database myplugdb3
SQL> alter pluggable database all close immediate;
NB This will close all pluggable databases
6. Using a trigger to open all pluggable databases.

sqlplus '/ as sysdba'
SQL> CREATE OR REPLACE TRIGGER pdb_startup AFTER STARTUP ON DATABASE
SQL> BEGIN
SQL> EXECUTE IMMEDIATE 'alter pluggable database all open';
SQL> END pdb_startup;
SQL> /

Adding new disk to ASM diskgroup on AIX 7.1
It is recommended that all your disks in ASM diskgroup be the same capacity. Do not mix speed drives in a disk group, namely all drives must have the same speed. In this particular case, we used IBM Storwize V7000, and disk speed of 15K.

Environment :
AIX 7.1
Oracle Grid infrastructure 11.2.0.4.0
Oracle RDBMS software 11.2.0.4.0
Two node RAC
Our new drive is rhdisk18, with capacity of 100GB. You need to check the rights granted to disk, on both nodes of RAC:

root@prim11g [~] # ls -la /dev/rhdisk*
crw-------   2 root     system       18, 0 Feb 07 2014 /dev/rhdisk0
crw-rw----   1 grid     asmadmin     18, 1 Dec 24 08:50 /dev/rhdisk1
. . . . . . . . . .
crw-rw----   1 grid     asmadmin     18, 16 Jan 18 23:18 /dev/rhdisk16
crw-rw----   1 grid     asmadmin     18, 17 Jan 18 23:18 /dev/rhdisk17
crw-------   1 root     system       18, 18 Jan 18 22:10 /dev/rhdisk18 -- Disk which we want to add to ASM
Here you can change the name of new disk, using AIX command rendev. If you do this, you must be sure, that you leave prefix rhdisk, in order to avoid compatibility issue with other apps running on AIX. Syntax for this, is something like:

rendev -l hdisk5 -n hdiskASM1 
Now we need to grant certain rights to our new disk. Owner of the disk, must be GI software owner. In our case grid user. You must do this, on both node of your cluster ( if you have cluster, of course 😉 )


root@prim11g [~] # chown grid:asmadmin /dev/rhdisk18 -- changing owner
root@prim11g [~] # chmod 660 /dev/rhdisk18
root@prim11g [~] # ls -la /dev/rhdisk*
crw-------   2 root     system       18, 0 Feb 07 2014 /dev/rhdisk0
crw-rw----   1 grid     asmadmin     18, 1 Dec 24 08:50 /dev/rhdisk1
crw-rw----   1 grid     asmadmin     18, 5 Jan 18 23:15 /dev/rhdisk10
crw-rw----   1 grid     asmadmin     18, 13 Jan 18 23:15 /dev/rhdisk11
crw-rw----   1 grid     asmadmin     18, 10 Jan 18 23:15 /dev/rhdisk12
crw-rw----   1 grid     asmadmin     18, 6 Jan 18 23:16 /dev/rhdisk13
crw-rw----   1 grid     asmadmin     18, 7 Jan 18 23:20 /dev/rhdisk14
crw-rw----   1 grid     asmadmin     18, 15 Jan 18 23:20 /dev/rhdisk15
crw-rw----   1 grid     asmadmin     18, 16 Jan 18 23:20 /dev/rhdisk16
crw-rw----   1 grid     asmadmin     18, 17 Jan 18 23:20 /dev/rhdisk17
crw-rw----   1 grid     asmadmin     18, 18 Jan 18 22:10 /dev/rhdisk18 -- user/group rights changed
You need to change the reserve option on every rhdiskX you will be using in ASM, on every node in RAC. You need to change this option to reserve_policy=no_reserve if you have AIX storage. If you have EMC, or some other storage than reserve_lock=no.


root@prim11g [~] # chdev -l hdisk18 -a reserve_policy=no_reserve
hdisk18 changed
Changing of PVID for the disk, must be done BEFORE you put disk into ASM diskgroup. Running this command after you put disk in ASM, at any node, will cause ASM corruption. You can look at My Oracle Support
ExtNote:750016.1 : ‘Corrective Action for Diskgroup with Disks Having PVIDs’ for more details.

So, also on every nod in cluster, do this:


root@prim11g [~] # chdev -l hdisk18 -a pv=clear
hdisk18 changed
root@bg01003r3n1 [~] # lspv | grep -i none
hdisk1         none                               None
hdisk2         none                               None
 . . . . . . . . . . . . . . . . . . 
hdisk16         none                               None
hdisk17         none                               None
hdisk18         none                               None
 

So much about AIX, lets see what we must do on ASM instance, to add disk rhdisk18 into one of our diskgroup. First we have to login with GI Software owner:


root@prim11g [~] # su - grid
grid@prim11g [~] $ sqlplus '/ as sysasm'

SQL*Plus: Release 11.2.0.4.0 Production on Sun Jan 18 23:23:40 2015

Copyright (c) 1982, 2013, Oracle. All rights reserved.

Connected to:
Oracle Database 11g Enterprise Edition Release 11.2.0.4.0 - 64bit Production
With the Real Application Clusters and Automatic Storage Management options

SQL>
SQL>
set line 500
set linesize 300
col path for a40
select name, path from v$asm_disk;

NAME                           PATH
------------------------------ ----------------------------------------
                               /dev/rhdisk18
CRS_0000                       /dev/rhdisk1
BACKUP_0000                    /dev/rhdisk10
BACKUP_0001                    /dev/rhdisk11
BACKUP_0002                    /dev/rhdisk12
 . . . . . . . . . . .  .
DATA_MEDIUM_0002               /dev/rhdisk8
DATA_MEDIUM_0003               /dev/rhdisk9
Now we need to check status of the disk we want to add to ASM diskgroup. If we already used that disk in ASM, HEADER_STATUS will have value FORMER. On new disk HEADER_STATUS will be CANDIDATE.


SELECT group_number, disk_number, mount_status,
header_status, state, path
FROM   v$asm_disk
where HEADER_STATUS in ('CANDIDATE','FORMER');
 

GROUP_NUMBER DISK_NUMBER MOUNT_S HEADER_STATU STATE    PATH
------------ ----------- ------- ------------ -------- ----------------------------------------
           0           0 CLOSED  CANDIDATE    NORMAL   /dev/rhdisk18
Now we need to check the names of diskgroups that we want to expand. (


SQL> SELECT GROUP_NUMBER, NAME FROM V$ASM_DISKGROUP;
And finally main action for today, adding disk into diskgroup:


SQL> alter diskgroup data_fast add disk '/dev/rhdisk18';  
Diskgroup altered.
SQL>
ASM will use default rebalance power for this action. If you want higher rebalance power, your command should look like this:


SQL> alter diskgroup data_fast add disk '/dev/rhdisk18' rebalance power 5; 
Now you can watch the progress of rebalancing disks:


SQL> select * from v$asm_operation;
SQL> select * from v$asm_operation;
GROUP_NUMBER OPERA STAT      POWER     ACTUAL      SOFAR   EST_WORK   EST_RATE EST_MINUTES ERROR_CODE
------------ ----- ---- ---------- ---------- ---------- ---------- ---------- ----------- -----------
           4 REBAL RUN           1          1       2960      77911       4698          15

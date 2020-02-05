Configure RMAN Archive log setting for Dataguard Environment
Configure:
Archive log is not deleted before applied or shipped to all standby Server

Cause:
In Oracle Dataguard environment, Archive is going to ship on standby database for applied on it. But some primary also configured on Flash Recovery Area (FRA) as archivelog file destination which may lead to space crunch in the location of archive destination. When you use the RMAN command “backup archivelog all delete all input”. It will delete backupset files in FRA location according to retention policy or archivelog files that have been backed according to redundancy policy.

Problem:
Oracle clean the archive log as we issued RMAN command, it may or may not applied on standby.

Solution:

Note: Configure _log_deletion_policy=’ALL’ and “configure deletion policy to applied on standby” in instance where we configure the RMAN backup.

1. Configure _log_deletion_policy=’ALL’ init parameter and restart the instance for take effect.

ALTER SYSTEM SET "_log_deletion_policy"='ALL' SCOPE=SPFILE;

2. Configure RMAN deletion policy using RMAN command

-- Set for current standby or primary
RMAN> CONFIGURE DELETION POLICY TO APPLIED ON STANDBY;

-- Set for all Standby
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

3. You can also configure this command on Primary Server.
RMAN donot delete the archive log until it shipped to all standby databases.

RMAN> CONFIGURE ARCHIVE DELETION POLICY TO SHIPPED TO ALL STANDBY;

Delete archive log Script:
Following script delete the archive log after 5 days.

RUN {
ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
DELETE ARCHIVELOG UNTIL TIME 'SYSDATE -5';
}

Note:
RMAN “backup … archivelog all delete all input” will not delete archivelog files that are still needed for Data Guard if
(a) they are not in FRA.
(b) they are in FRA but no FRA space crunch situation.

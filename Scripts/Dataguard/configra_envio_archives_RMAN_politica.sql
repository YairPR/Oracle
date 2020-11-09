Configure RMAN Archive log setting for Dataguard Environment
Configure:
Archive log is not deleted before applied or shipped to all standby Server

Cause:
En el entorno de Oracle Dataguard, Archive se enviará en una base de datos en espera para su aplicación. Pero algunos primarios 
también están configurados en el Área de recuperación de Flash (FRA) como destino del archivo de registro de archivo, lo que puede 
provocar una reducción del espacio en la ubicación del destino del archivo. Cuando utiliza el comando RMAN “backup archivelog all delete all input”. 
Eliminará los archivos del conjunto de copias de seguridad (backupset) en la ubicación de FRA de acuerdo con la política de retención o los archivos de registro de 
archivo que se hayan respaldado de acuerdo con la política de redundancia.

Problem:
Oracle limpia el registro de archivo a medida que emitimos el comando RMAN, puede o no aplicarse en modo de espera

Solution:

Note: Configure _log_deletion_policy=’ALL’ and “configure deletion policy to applied on standby” in instance where we configure the RMAN backup.

1. Configure _log_deletion_policy=’ALL’ init parameter and restart the instance for take effect.

ALTER SYSTEM SET "_log_deletion_policy"='ALL' SCOPE=SPFILE;

2. Configurar la política de eliminación de RMAN mediante el comando RMAN

-- Set for current standby or primary
RMAN> CONFIGURE DELETION POLICY TO APPLIED ON STANDBY;

-- Set for all Standby
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

3. También puede configurar este comando en el servidor primario.
RMAN donot delete the archive log until it shipped to all standby databases.

RMAN> CONFIGURE ARCHIVE DELETION POLICY TO SHIPPED TO ALL STANDBY;

Delete archive log Script:
Following script delete the archive log after 5 days.

RUN {
ALLOCATE CHANNEL FOR MAINTENANCE DEVICE TYPE DISK;
DELETE ARCHIVELOG UNTIL TIME 'SYSDATE -5';
}

Nota:
RMAN "backup ... archivelog all delete all input" no eliminará los archivos de archivelog que aún son necesarios para Data Guard Si:
(a) no están en FRA.
(b) están en FRA pero no en una situación de escasez de espacio de FRA.

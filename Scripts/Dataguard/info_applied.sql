--Los registros archivados se atascan "en la memoria" al crear un modo de espera

La documentación de la columna APPLIED establece lo siguiente :-

Indica si se ha aplicado un archivo de registro de rehacer archivado a la base de datos física en espera correspondiente. El valor es
siempre NO para destinos locales.

Esta columna es significativa en una base de datos física en espera para filas donde REGISTRAR = RFS:

Sí REGISTRAR = RFS and APPLIED = NO, entonces el archivo de registro se ha recibido pero aún no se ha aplicado.
Sí REGISTRAR = RFS and APPLIED = IN-MEMORY, entonces el archivo de registro se ha aplicado en la memoria, pero los archivos de datos aún no
sido actualizado.
Sí REGISTRAR = RFS and APPLIED = YES,luego se aplicó el archivo de registro y se actualizaron los archivos de datos.
Entonces, los registros se habían aplicado pero los archivos de datos no se habían actualizado. Esperamos mucho tiempo y vinieron más troncos del

Caso:
Sí el sistema primario y la columna APPLIED mostraron YES pero los más antiguos no cambiaron. 
Entoces cancele la recuperación administrada, reinicie la instancia y luego reinicie la recuperación administrada. Entonces todo
los registros, de ambos subprocesos mostraban YES en la barra de columnas APPLIED los últimos registros.

-- REPORTE DE ARCHIVE, ESTADO APPLIED= NO, YES, IN MEMORY

column "First Time" format A40
column applied format A10
column "Next Time" format A40
set linesize 120
set pagesize 1000
 
select   thread#, sequence#,       applied,
to_char(first_time,'DD-MON-YY:HH24:MI:SS') "First Time",
to_char(next_time,'DD-MON-YY:HH24:MI:SS') "Next Time"
from      v$archived_log
--where rownum < 10
UNION
select   NULL,NULL,' ',NULL,null FROM DUAL
UNION
select   null,null,
db_unique_name,
database_role,
open_mode
from      v$database
/


   THREAD#  SEQUENCE# APPLIED    First Time                               Next Time
---------- ---------- ---------- ---------------------------------------- ----------------------------------------
         1      61222 YES        28-AUG-20:19:00:19                       28-AUG-20:19:30:18
         1      61223 YES        28-AUG-20:19:30:18                       28-AUG-20:20:00:18
         1      61224 YES        28-AUG-20:20:00:18                       28-AUG-20:20:30:17
         1      61225 YES        28-AUG-20:20:30:17                       28-AUG-20:20:50:33
         1      61226 YES        28-AUG-20:20:50:33                       28-AUG-20:21:00:18
         1      61227 YES        28-AUG-20:21:00:18                       28-AUG-20:21:30:17
         1      61228 YES        28-AUG-20:21:30:17                       28-AUG-20:22:00:20
         1      61229 YES        28-AUG-20:22:00:20                       28-AUG-20:22:30:18
         1      61230 YES        28-AUG-20:22:30:18                       28-AUG-20:23:00:18

                      P2KCTG     PHYSICAL STANDBY                         READ ONLY WITH APPLY




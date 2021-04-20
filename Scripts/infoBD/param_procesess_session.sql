/*V$RESOURCE_LIMIT
muestra información sobre el uso de recursos globales para algunos de los recursos del sistema. Utilice esta vista para monitorear el consumo de recursos para 
que pueda tomar acciones correctivas, si es necesario. Muchos de los recursos corresponden a los parámetros de inicialización enumerados en la Tabla 8-5 .


PROCESSES especifica el número máximo de procesos de usuario del sistema operativo que pueden conectarse simultáneamente a Oracle. Su valor debe permitir todos 
los procesos en segundo plano, como bloqueos, procesos de cola de trabajos y procesos de ejecución paralela.

Los valores predeterminados de los parámetros SESSIONSy TRANSACTIONSse derivan de este parámetro. Por lo tanto, si cambia el valor de PROCESSES, debe evaluar si 
ajustar los valores de esos parámetros derivados.

SESSIONS
Property	Description
Parameter type	Integer
Default value	Derived: (1.1 * PROCESSES) + 5
Modifiable	No
Range of values	1 to 2 elevado a 31
Basic	Yes

processes=x
session=(1.5 * PROCESSES) + 22
transactions=sessions*1.1 

*/

-- Query 1:
-- 9i,10g,11g,12c
-- Cantidad de sesiones basandose en el parametro sessions
SELECT
  'Currently, ' 
  || (SELECT COUNT(*) FROM V$SESSION)
  || ' out of ' 
  || VP.VALUE 
  || ' connections are used.' AS USAGE_MESSAGE
FROM 
  V$PARAMETER VP
WHERE VP.NAME = 'sessions';


Result:
--------
USAGE_MESSAGE
--------------------------------------------------------------------------------
Currently, 1034 out of 4185 connections are used.


-- Query 2:
-- 9I, 10G, 11G ,12C
-- Cantidad de sesiones usadas en resource_limit
select resource_name, current_utilization, max_utilization, limit_value 
from v$resource_limit 
where resource_name in ('sessions', 'processes', 'transactions');

RESOURCE_NAME                  CURRENT_UTILIZATION MAX_UTILIZATION LIMIT_VALU
------------------------------ ------------------- --------------- ----------
processes                                     1036            3729       3800
sessions                                      1031            4008       4185

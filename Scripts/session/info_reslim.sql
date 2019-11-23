-- 9I, 10G, 11G ,12C
-- Cantidad de sesiones usadas en resource_limit
select resource_name, current_utilization, max_utilization, limit_value 
from v$resource_limit 
where resource_name in ('sessions', 'processes');

RESOURCE_NAME                  CURRENT_UTILIZATION MAX_UTILIZATION LIMIT_VALU
------------------------------ ------------------- --------------- ----------
processes                                     1036            3729       3800
sessions                                      1031            4008       4185


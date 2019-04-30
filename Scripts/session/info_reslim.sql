-- Cantidad de sesiones usadas en resource_limit
select resource_name, current_utilization, max_utilization, limit_value 
from v$resource_limit 
where resource_name in ('sessions', 'processes');

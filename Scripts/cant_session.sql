/*
@Author: E. Yair Purisaca R.
@Email: eddiepurisaca@gmail.com
*/

-- Cantidad total de sessiones
select count(*) from v4session;

-- Cantidad de sesiones basandose en el parametro sessions
SELECT
  'Currently, ' 
  || (SELECT COUNT(*) FROM V$SESSION)
  || ' out of ' 
  || VP.VALUE 
  || ' connections are used.' AS USAGE_MESSAGE
FROM 
  V$PARAMETER VP
WHERE VP.NAME = 'sessions'

-- Cantidad de sesiones usadas en resource_limit
select resource_name, current_utilization, max_utilization, limit_value 
from v$resource_limit 
where resource_name in ('sessions', 'processes');

-- Cantidad de sesiones por usuario de base de datos.
SELECT 
   s.status, 
   count(1) nro_sesiones, 
   s.username 
FROM 
   v$process p, 
   v$session s
WHERE  paddr(+)=addr
GROUP BY  s.status, s.username
ORDER BY 2 desc;

-- Catindad de seiones por equipo conectado a travéz de un usuario especifico.

SELECT 
   s.schemaname AS USER,
   -- Dentro del case estan los nombres de los servidores o maquinas que se conectan a la bd.
   -- Pueden quitar el Case 
   (CASE s.machine
   when '3b8ce10687aa' THEN 'bonita-api'
   when '4fcab3e0c760' THEN 'reporte-api'
   when '474c1551e613' THEN 'bonita-api'
   when '46263d29d447' THEN 'ceditec-web'
   when 'c943fbbc93f7' THEN 'reserva-api'
   when 'bff6bb50d054' THEN 'curricula-api'
   when '8191f030cb12' THEN 'solicitud-api'
   when '4eee123ded5d' THEN 'google-drive-api'
   when '309cffaafcc7' THEN 'edu-web'
   when 'mule-prod.c.utec-qa-prod.internal' THEN 'mule-prod'
   when 'core-pro-1' THEN 'core-pro-1'
   when 'edu-prod' THEN 'edu-prod'
    when 'pentaho-prod.c.utec-qa-prod.internal' THEN 'pentaho-prod'
   ELSE 'other-user' 
   END) as Aplicaciones_Server, 
   count(1) as cant_sesiones
FROM 
   v$process p, 
   v$session s
WHERE 
   paddr(+)=addr
   and s.schemaname = 'SCHEMA'
GROUP BY 
   s.schemaname, 
   s.machine
ORDER BY 3 DESC;

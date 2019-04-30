-- Catindad de sesiones por api
SELECT 
   s.schemaname AS "USER",
   -- Dentro del case estan los nombres de los servidores o maquinas que se conectan a la bd.
   -- Pueden quitar el Case 
 /*  (CASE s.machine
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
   END) */ s.machine  as Aplicaciones_Server, 
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

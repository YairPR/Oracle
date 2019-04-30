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

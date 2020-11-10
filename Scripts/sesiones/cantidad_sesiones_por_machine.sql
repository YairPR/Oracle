-- Catindad de sesiones de un usuario por aplicación
SET LINE 1000
SELECT 
   s.schemaname AS "USER",
   s.machine  as Aplicaciones_Server, 
   count(1) as cant_sesiones
FROM 
   v$process p, 
   v$session s
WHERE 
   paddr(+)=addr
   --and s.schemaname = upper('&Usuario')
   and s.status = 'ACTIVE'
GROUP BY 
   s.schemaname, 
   s.machine
ORDER BY 3 DESC;

RESULT:
--------

USER                           APLICACIONES_SERVER                                              CANT_SESIONES
------------------------------ ---------------------------------------------------------------- -------------
ACSELX                         minerva                                                                      8
ACSELX                         XXXXXX\01-040292                                                              1
ACSELX                         XXXXXX\RSDCPVDI119                                                            1


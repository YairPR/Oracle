-- Cantidad de sesiones por usuario de base de datos.
SELECT 
   s.status, 
   count(1) nro_sesiones, 
   s.username 
FROM 
   v$process p, 
   v$session s
WHERE  paddr(+)=addr
and s.username <> ' '
AND s.username = '&username'
GROUP BY  s.status, s.username
ORDER BY 2 desc;


RESULT
-------
STATUS   NRO_SESIONES USERNAME
-------- ------------ ------------------------------
INACTIVE          133 DBL_BDRSA_01
INACTIVE          113 DS_PCANAL_AX
INACTIVE           60 WKFEMI

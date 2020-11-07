-- 9i,10g,11g,12c
/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2018
*@Descripcion:             Busqueda ejecuciones por hash
*@Versión                  v1.0
*******************************************************************************************************************/

set line 100
col username format a30
select username, sql_hash_value, count(1) 
from v$session 
where type !='BACKGROUND' 
--and status = 'ACTIVE'
group by username, sql_hash_value 
order by 1, 2;


RESULT:
-------
USERNAME                       SQL_HASH_VALUE   COUNT(1)
------------------------------ -------------- ----------
ACSELX                               92039565          1
ACSELX                              131469396          1


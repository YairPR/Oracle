
/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2018
*@Descripcion:             Busqueda ejecuciones por hash
*@Versión                  v1.0
*******************************************************************************************************************/

set line 100
col username format a30
select username, sql_hash_value, count(1) 
from v$session where status = 'ACTIVE' and type !='BACKGROUND' 
group by username, sql_hash_value 
order by 1, 2;

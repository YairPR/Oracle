/*****************************************************************************************************************
*@Autor:                   E. Yair Purisaca Rivera
*@Fecha Creacion:          Nov 2017
*@Descripcion:             Información de Usuario
*@Versión:                 1.0
*******************************************************************************************************************/

set time on
set line 1000
set pagesize 10000
set arraysize 10
set maxdata 10000
COL usuario_profile FORMAT A40
COL CREACION FORMAT A20
COL PROFILE FORMAT A20
COL TABSPCs  FORMAT A55
COL ACCOUNT_STATUS format a20
SELECT substr(ACCOUNT_STATUS,1,20) ACCOUNT_STATUS , expiry_date,
       USERNAME||'.'||profile USUARIO_profile, CREATED CREACION,
       DEFAULT_TABLESPACE ||' / '|| TEMPORARY_TABLESPACE TABSPCs --, 'alter user '||username||' temporary tablespace temp ;' xx
  FROM DBA_USERS
 WHERE USERNAME LIKE  UPPER(trim('&UNAME')||'%')
--and expiry_date = trunc(sysdate)
--and account_status like '%LOCK%'
 ORDER BY 3,1, 2
/


RESULT:
---------
ACCOUNT_STATUS	     EXPIRY_DATE	 USUARIO_PROFILE			  CREACION	       TABSPCS
-------------------- ------------------- ---------------------------------------- -------------------- -------------------------------------------------------
OPEN					 MANTENIMIENTO.PRF_OTROS		  18/01/2015 08:10:56  USERS / TEMP


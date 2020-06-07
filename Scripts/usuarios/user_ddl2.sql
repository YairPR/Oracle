aca el DDL de un objeto

set pagesize 0
set verify off
set autoprint off
set feedback off
set timing off
set linesize 4000
set long 900000
set trims on
set line 4000
--Importante, para que no haga salto de linea, line y linesize no pesan pero configurarlos igual
col txt for a4000 

--Esto saca el ddl en un sql, pedira poner nombre del archivo para el valor 1
--Paquetes Body y cabecera = PACKAGE

PROMPT

PROMPT --IMPORTANTE!!!!!!!!!!!!!!!!! SETEAR LAS SGTES VARIABLES PARA QUE LA BD ACEPTE TILDES (Á) Y EÑES, SELECT * from NLS_SESSION_PARAMETERS;

PROMPT --export LANG=en_US.ISO-8859_1  -->ESTO SIRVE PARA QUE EL EDITOR VI VEA LAS TILDES Y LAS EÑES

PROMPT --export NLS_LANG=SPANISH_SPAIN.WE8MSWIN1252   -->ESTO SIRVE PARA QUE LA BD (QUE ACTUALMENTE TIENE  NLS_LANG=AMERICAN) ACEPTE LAS TILDES Y EÑES

PROMPT --DATABASE LINK -> Poner DB_LINK

PROMPT


spool &NOMBRE_SQL..sql  

EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',TRUE);
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'STORAGE',TRUE);
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SEGMENT_ATTRIBUTES',TRUE);
--Pone el "/" al final, obligatorio para q corran los ddl
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',TRUE); 
select dbms_metadata.get_ddl(UPPER('&TIPO_OBJETO'),UPPER('&NOMBRE_OBJETO'),UPPER('&OWNER')) txt
from dual
/

spool off;

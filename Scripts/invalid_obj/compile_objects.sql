set echo off
set pagesize 0
set linesize 100
set feedback off
set heading off

spool c:\obj_to_compile.sql

select 'PROM ALTER ' || decode(owner,'PUBLIC','PUBLIC ','') || object_type || decode(owner,'PUBLIC',' "',' "' || OWNER || '"."') || OBJECT_NAME || '" ... ' || CHR(10) || 'ALTER ' || decode(owner,'PUBLIC','PUBLIC ','') || decode(object_type,'PACKAGE BODY','PACKAGE',object_type) || decode(owner,'PUBLIC',' "',' "' || OWNER || '"."') || OBJECT_NAME || '" COMPILE' || decode(object_type,'PACKAGE BODY',' BODY','') || ';' || decode(object_type, 'SYNONYM', '', CHR(10) || 'SHOW ERRORS ' || OBJECT_TYPE || ' ' || OWNER || '.' || OBJECT_NAME || ';' || CHR(10) )
from all_objects
where status != 'VALID'
and owner not in ('APP_REAACEP')
and object_type in ('VIEW','TRIGGER','PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','JAVA SOURCE')
order by object_type, owner, object_name
/

spool off

/*Inicio de compilacion de sinonimos*/
DECLARE
   CURSOR c_syn_compile
   IS
      SELECT    'DROP '
             || DECODE (s.owner, 'PUBLIC', 'PUBLIC ', '')
             || DECODE (o.object_type, 'PACKAGE BODY', 'PACKAGE', o.object_type)
             || DECODE (s.owner, 'PUBLIC', ' "', ' "' || s.OWNER || '"."')
             || o.OBJECT_NAME
             || '"' sqldrop,
                'CREATE '
             || DECODE (s.owner, 'PUBLIC', 'PUBLIC ', '')
             || DECODE (o.object_type, 'PACKAGE BODY', 'PACKAGE', o.object_type)
             || DECODE (s.owner, 'PUBLIC', ' "', ' "' || s.OWNER || '"."')
             || o.OBJECT_NAME
             || '" FOR "'
             || s.table_owner
             || '"."'
             || s.table_name
             || '"' sqlcreate
        FROM dba_synonyms s, dba_objects o
       WHERE s.owner = o.owner
         AND s.synonym_name = o.object_name
         AND s.owner = 'PUBLIC'
         AND o.status != 'VALID';
BEGIN
   FOR x IN c_syn_compile
   LOOP
      EXECUTE IMMEDIATE x.sqldrop;
      EXECUTE IMMEDIATE x.sqlcreate;
   END LOOP;
END;
/
/*Fin de compilacion de sinonimos*/

spool c:\stat_obj_compile.txt

select count(1) "Nro Invalid Objects"
from all_objects
where status != 'VALID'
and owner not in ('APP_REAACEP')
and object_type in ('VIEW','TRIGGER','PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','SYNONYM','JAVA SOURCE')
order by object_type, owner, object_name
/

@ c:\obj_to_compile.sql

select count(1) "Nro Invalid Objects"
from all_objects
where status != 'VALID'
and owner not in ('APP_REAACEP')
and object_type in ('VIEW','TRIGGER','PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY','SYNONYM','JAVA SOURCE')--
order by object_type, owner, object_name
/

spool off

set pagesize 100
set feedback on
set heading on
set echo off

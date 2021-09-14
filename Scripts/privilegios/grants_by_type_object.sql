_-- SELECT

SET LONG 10000
SET LINE 1000
SET PAGESIZE 20000
select 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user' || ';'
from dba_objects 
where OWNER in ('&schema1', '&SCHEMA2', '&SCHEMA3', '&SCHEMA4') 
AND OBJECT_TYPE IN ('TABLE', 'VIEW');


-- WITH GRANT OPTION
select 'GRANT SELECT ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user WITH GRANT OPTION;' 
from dba_objects 
where owner in ('username')   
AND OBJECT_TYPE IN ('TABLE')

-- EXECUTE
SET LONG 10000
SET LINE 1000
SET PAGESIZE 20000
select 'GRANT EXECUTE, DEBUG ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user_or_rol' || ';'
from dba_objects 
where OWNER in ('&schema1', '&SCHEMA2', '&SCHEMA3', '&SCHEMA4') 
AND OBJECT_TYPE IN ('FUNCTION', 'PACKAGE');

-- DEBUG
select 'GRANT DEBUG ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user_or_rol' || ';'
from dba_objects 
where owner in ('username') 
AND OBJECT_TYPE IN ('PACKAGE')

-- SYNONYMS
select 'CREATE OR REPLACE SYNONYM ' || '&user' || '.' || OBJECT_NAME || ' FOR ' || OWNER || '.' || OBJECT_NAME || ';'
from dba_objects 
where owner in ('username')  
--AND OBJECT_TYPE IN ('TABLE','FUNCTION')
AND OBJECT_TYPE IN ('TABLE', 'PROCEDURE', 'SEQUENCE', 'PACKAGE', 'FUNCTION', 'TRIGGER', 'VIEW')

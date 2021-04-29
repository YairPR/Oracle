_-- SELECT
select 'GRANT SELECT ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user' || ';'
from dba_objects 
where OWNER in ('&schema') 
AND OBJECT_TYPE IN ('TABLE', 'VIEW');

-- WITH GRANT OPTION
select 'GRANT SELECT ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user WITH GRANT OPTION;' 
from dba_objects 
where owner in ('username')   
AND OBJECT_TYPE IN ('TABLE')

-- EXECUTE
select 'GRANT EXECUTE ON ' || OWNER || '.' || OBJECT_NAME || ' TO ' || '&user_or_rol' || ';'
from dba_objects 
where owner in ('username')   
AND OBJECT_TYPE IN ('FUNCTION', 'PACKAGE')

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

--REVOKE SELECT
select 'REVOKE &privs on ' || OWNER || '.' || OBJECT_NAME || ' FROM ' || '&usrole' || ';'
from dba_objects 
where owner in ('username')  
AND OBJECT_TYPE IN ('TABLE', 'VIEW', 'SEQUENCE')


--REVOKE EXECUTE
select 'REVOKE &privs on ' || OWNER || '.' || OBJECT_NAME || ' FROM ' || '&usrole' || ';'
from dba_objects 
where owner in ('username')  
AND OBJECT_TYPE IN ('FUNCTION')

-- REVOKE DEBUG
select 'REVOKE &privs on ' || OWNER || '.' || OBJECT_NAME || ' FROM ' || '&usrole' || ';'
from dba_objects 
where owner in ('username')  
AND OBJECT_TYPE IN ('PACKAGE')

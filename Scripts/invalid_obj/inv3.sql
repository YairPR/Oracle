select 'alter '||object_type||' '||owner||'."'||object_name||'" compile;'
from dba_objects where owner = 'OWNER' and object_type = 'MATERIALIZED VIEW' and status <> 'VALID'

OR

SET SERVEROUTPUT ON 
BEGIN
  FOR i IN (SELECT owner,object_name, object_type FROM   dba_objects
                  WHERE  object_type IN ('MATERIALIZED VIEW')
                  AND    status <> 'VALID'
                  AND OWNER='SCHEMA NAME'
                  ORDER BY 2)
  LOOP
    BEGIN
      IF i.object_type = 'MATERIALIZED VIEW' THEN
        EXECUTE IMMEDIATE 'ALTER ' || i.object_type ||' "' || i.owner || '"."' || i.object_name || '" COMPILE';
    
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.put_line(i.object_type || ' : ' || i.owner ||' : ' || i.object_name);
    END;
  END LOOP;
END;

You can use the following in SQLPLUS if need to compile all objects in schema

exec dbms_utility.compile_schema('SCHEMA NAME')

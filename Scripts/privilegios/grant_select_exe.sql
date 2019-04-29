-- -----------------------------------------------------------------------------------
-- File Name    : grant_select.sql
-- Description  : Grants select on current schemas tables, views & sequences to the specified user/role.
-- Call Syntax  : @grant_select (schema-name)
-- -----------------------------------------------------------------------------------
SET PAGESIZE 0
SET FEEDBACK OFF
SET VERIFY OFF

SPOOL temp.sql

SELECT 'GRANT SELECT ON "' || u.object_name || '" TO &1;'
FROM   user_objects u
WHERE  u.object_type IN ('TABLE','VIEW','SEQUENCE')
AND    NOT EXISTS (SELECT '1'
                   FROM   all_tab_privs a
                   WHERE  a.grantee    = UPPER('&1')
                   AND    a.privilege  = 'SELECT'
                   AND    a.table_name = u.object_name);

SPOOL OFF

-- Comment out following line to prevent immediate run
@temp.sql

SET PAGESIZE 14
SET FEEDBACK ON
SET VERIFY ON

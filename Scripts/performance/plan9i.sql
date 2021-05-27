col objeto for a44
undefine sql_id
select operation, options, OBJECT_OWNER || '.' || OBJECT_NAME objeto, substr(filter_predicates, 1, 20) filter_predicates
from V$SQL_PLAN
where SQL_ID = '&sql_id'
order by child_number, id;

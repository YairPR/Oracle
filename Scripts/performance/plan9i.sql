col objeto for a44
undefine w_hash
select operation, options, OBJECT_OWNER || '.' || OBJECT_NAME objeto, substr(filter_predicates, 1, 20) filter_predicates
from V$SQL_PLAN
where 
  HASH_VALUE = &&w_hash
order by child_number, id;

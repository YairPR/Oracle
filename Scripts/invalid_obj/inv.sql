set line 1000
SELECT owner, object_type, object_name
FROM all_objects
WHERE status = 'INVALID'
/

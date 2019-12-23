-- https://www.databasejournal.com/features/oracle/article.php/3681531/Oracle-RAC-Checking-RAC-status-with-SQLOS-level-statements.htm

select instance_name, host_name, archiver, thread#, status
from gv$instance
 /

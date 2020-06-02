select
'alter user ' || su.name || ' identified by values'
   || ' ''' || spare4 || ';'    || su.password || ''';'
from sys.user$ su 
join dba_users du on ACCOUNT_STATUS like 'EXPIRED%' and su.name = du.username;


set long 9999999
set lin 400
select DBMS_METADATA.GET_DDL('USER','YOUR_USER_NAME') from dual;

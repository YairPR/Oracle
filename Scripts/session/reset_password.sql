select
'alter user ' || su.name || ' identified by values'
   || ' ''' || spare4 || ';'    || su.password || ''';'
from sys.user$ su 
join dba_users du on ACCOUNT_STATUS like 'OPEN%' and su.name = du.username and du.username = '&USER';


set long 9999999
set lin 400
select DBMS_METADATA.GET_DDL('USER','DPORTOCAR') from dual;

alter user NAME_OF_THE_USER identified by OLD_PASSWORD;

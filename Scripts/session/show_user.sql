select username, default_tablespace, temporary_tablespace, profile
from   dba_users
where  username = upper('&Usuario');

-- Script muestra el comando ALTER KILL SESSION
-- Parametro: USERNAME
select 'alter system kill session '''||u.sid||','||u.serial#||''';' from v$session u
where u.type='USER'
--and u.module like '%modulo%'
and u.username='&usuario';

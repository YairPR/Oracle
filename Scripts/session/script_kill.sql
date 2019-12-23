--Dynamically generate SQL when required to kill ton of sessions:
select 'alter system kill session '''||u.sid||','||u.serial#||''';' from v$session u
where u.type='USER'
and u.module like '%<module>%;

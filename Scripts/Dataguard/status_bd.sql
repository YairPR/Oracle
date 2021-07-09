
alter session set nls_date_format = 'yyyy-mm-dd hh24:mi:ss';
col host_name for a16
select sysdate fecha, b.host_name, status,instance_name,database_role,protection_mode, open_mode from gv$database a, gv$instance b
where a.inst_id = b.inst_id;

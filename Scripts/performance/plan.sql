set feedback off

set verify off

set pagesize 10000

set linesize 160

accept v_sql_id prompt "[SQL_ID] "
select * from table(dbms_xplan.display_cursor('&v_sql_id',NULL,'+peeked_binds'));
select * from table(dbms_xplan.display_awr('&v_sql_id'));

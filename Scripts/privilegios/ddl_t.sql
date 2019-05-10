-- -----------------------------------------------------------------------------------
-- File Name    : ddl_t.sql
-- Description  : Muestra el sql para crear una tabla
-- Call Syntax  : @ddl_u.sql (user-name & table-name)
-- -----------------------------------------------------------------------------------

set feedback off verify off
set long 2000000
set pagesize 0
set serveroutput on
set linesize 1000
set trim on
set trimspool on
set head off
set echo off
set feedback off 
accept esquema prompt 'Enter User Name : '
accept tabla prompt 'Enter Table : '
col txt for a4000 word_wrapped
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
SELECT DBMS_METADATA.GET_DDL('TABLE','&tabla','&esquema') txt from dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL ('OBJECT_GRANT','&tabla','&esquema') txt from dual;

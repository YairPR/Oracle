-- -----------------------------------------------------------------------------------
-- File Name    : ddl_u.sql
-- Description  : Muestra la sentencia sql para crear el archivo asi como sus priveligios.
-- Call Syntax  : @ddl_u.sql (user-name)
-- -----------------------------------------------------------------------------------

set long 2000000
set pagesize 0
set serveroutput on
set linesize 1000
set trim on
set trimspool on
set head off
set echo off
set feedback off verify off
accept uname prompt 'Enter User Name : '
col txt for a4000 word_wrapped
execute DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
SELECT DBMS_METADATA.GET_DDL('USER', USERNAME) txt FROM DBA_USERS WHERE USERNAME='&&uname';
SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT', USERNAME) txt FROM DBA_USERS WHERE USERNAME='&&uname';
SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT', USERNAME) txt FROM DBA_USERS WHERE USERNAME='&&uname';
SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT', USERNAME) txt FROM DBA_USERS WHERE USERNAME='&&uname';
